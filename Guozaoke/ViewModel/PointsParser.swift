//
//  PointsParser.swift
//  Guozaoke
//
//  Created by scy on 2026/11/14.
//

import Foundation
import SwiftSoup
import SwiftUI

// MARK: - 积分收支明细模型
struct PointsLedgerItem: Identifiable, Equatable {
    let id = UUID()
    let action: String         // 如 "发布优质主题", "回复被采纳", "主题获赞"
    let pointsChange: String   // 如 "+5", "+1"
    let date: String           // 如 "2026-11-12 14:30"
    let balance: String        // 结余，如 "128"
    let desc: String           // 附加说明
}

// MARK: - 信用等级对照模型
struct CreditLevelInfo: Identifiable, Equatable {
    let id = UUID()
    let level: String          // 如 "Lv.1"
    let range: String          // 如 "低于 100"
    let desc: String           // 描述说明
}

// MARK: - 积分获取规则模型
struct PointsRuleItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let reward: String
    let iconName: String
}

@MainActor
class PointsParser: ObservableObject {
    static let shared = PointsParser()

    @Published var pointsBalance: String = "0"
    @Published var creditLevel: String = ""
    @Published var creditScore: String = ""
    @Published var ledgerItems: [PointsLedgerItem] = []
    @Published var isLoading: Bool = false
    @Published var isLedgerLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var ledgerErrorMessage: String? = nil

    static let pointsCacheKey = "com.guozaoke.ios.cached.points"
    static let levelCacheKey = "com.guozaoke.ios.cached.credit.level"

    // 社区官方信用等级标准（对标 /points/levels 官方公示数据）
    let creditLevels: [CreditLevelInfo] = [
        CreditLevelInfo(level: "Lv.1", range: "低于 100", desc: "新手起步，积极互动"),
        CreditLevelInfo(level: "Lv.2", range: "100 – 599", desc: "活跃社友，常来过早"),
        CreditLevelInfo(level: "Lv.3", range: "600 – 1799", desc: "资深成员，持续贡献"),
        CreditLevelInfo(level: "Lv.4", range: "1800 – 2999", desc: "核心常青，社区中坚"),
        CreditLevelInfo(level: "Lv.5", range: "3000 及以上", desc: "荣誉元老，殿堂贡献")
    ]

    // 社区早点获取规则说明（对标 /points/earn 官方最新明细）
    let rules: [PointsRuleItem] = [
        PointsRuleItem(
            title: "发布有效主题",
            subtitle: "满72小时获1赞、1收藏或3条回复，每周最多3篇",
            reward: "早点 +5",
            iconName: "square.and.pencil"
        ),
        PointsRuleItem(
            title: "主题获有效点赞",
            subtitle: "每2人点赞增1信用，每帖最多获20早点、3信用",
            reward: "早点 +2",
            iconName: "hand.thumbsup"
        ),
        PointsRuleItem(
            title: "主题被有效收藏",
            subtitle: "社友收藏主帖，每帖最多6早点、每日最多4早点",
            reward: "早点 +2",
            iconName: "bookmark"
        ),
        PointsRuleItem(
            title: "回复获有效点赞",
            subtitle: "发表优质见解获赞，每作者每日最多5早点",
            reward: "早点 +1",
            iconName: "bubble.left.and.bubble.right"
        ),
        PointsRuleItem(
            title: "主题被置精华",
            subtitle: "同帖一次，置精后自动结算发放",
            reward: "早点 +10",
            iconName: "star.fill"
        ),
        PointsRuleItem(
            title: "每日登录与信用成长",
            subtitle: "每个自然日首次登录访问，稳定提升信用分与等级",
            reward: "信用 +1",
            iconName: "shield.checkerboard"
        )
    ]

    init() {
        // 读取本地缓存的早点数值，未获取到或为空时默认展示 0
        let cached = Persist.read(key: Self.pointsCacheKey, default: "0")
        if !cached.isEmpty && cached != "--" {
            self.pointsBalance = cached
        } else {
            self.pointsBalance = "0"
        }
        let cachedLevel = Persist.read(key: Self.levelCacheKey, default: "")
        if !cachedLevel.isEmpty {
            self.creditLevel = cachedLevel
        }
    }

    /// 提取字符串中的连续数字
    nonisolated private static func extractDigits(from text: String) -> String? {
        let cleaned = text.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined()
        return cleaned.isEmpty ? nil : cleaned
    }

    /// 从 HTML 中多策略提取早点数值
    nonisolated static func extractPoints(from html: String) -> String? {
        guard let doc = try? SwiftSoup.parse(html) else { return nil }

        // 1. 标准属性 [data-gzk-point-balance] (支持属性值或文本内容)
        if let elem = try? doc.select("[data-gzk-point-balance]").first() {
            let attrVal = (try? elem.attr("data-gzk-point-balance"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let num = extractDigits(from: attrVal), !num.isEmpty {
                logger("[PointsParser] 命中属性 data-gzk-point-balance: \(num)")
                return num
            }
            let textVal = (try? elem.text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
            if let num = extractDigits(from: textVal), !num.isEmpty {
                logger("[PointsParser] 命中元素 [data-gzk-point-balance]: \(num)")
                return num
            }
        }

        // 2. 积分卡片值 .gzk-points-card-value
        if let cardVal = try? doc.select(".gzk-points-card-value").first(),
           let text = try? cardVal.text(),
           let num = extractDigits(from: text) {
            logger("[PointsParser] 命中卡片选择器 .gzk-points-card-value: \(num)")
            return num
        }

        // 3. 积分卡片 a.gzk-points-card
        if let card = try? doc.select("a.gzk-points-card").first(),
           let text = try? card.text(),
           let num = extractDigits(from: text) {
            logger("[PointsParser] 命中 a.gzk-points-card: \(num)")
            return num
        }

        // 4. 列表形式 dl:has(dt:contains(早点)) dd
        if let dd = try? doc.select("dl:has(dt:contains(早点)) dd").first(),
           let text = try? dd.text(),
           let num = extractDigits(from: text) {
            logger("[PointsParser] 命中 dl 早点: \(num)")
            return num
        }

        // 5. 详情页/通用容器：.points-balance, .gzk-points .ui-content strong 等
        let candidateSelectors = [
            ".points-balance",
            ".gzk-points-balance",
            ".usercard .status-points strong",
            ".gzk-points .ui-content strong",
            ".gzk-points .ui-content b",
            ".gzk-points header strong"
        ]
        for sel in candidateSelectors {
            if let elem = try? doc.select(sel).first(),
               let text = try? elem.text(),
               let num = extractDigits(from: text) {
                logger("[PointsParser] 命中候选选择器 \(sel): \(num)")
                return num
            }
        }

        // 6. 从流水表格首行尝试提取结余
        if let firstRow = try? doc.select("table.gzk-points-rules tbody tr, table tbody tr").first() {
            let cols = (try? firstRow.select("td")) ?? Elements()
            if cols.count >= 4 {
                if let balanceCol = cols.last(),
                   let text = try? balanceCol.text(),
                   let num = extractDigits(from: text) {
                    logger("[PointsParser] 命中流水首行结余: \(num)")
                    return num
                }
            }
        }

        // 7. 正则表达式深度扫描
        let patterns = [
            #"data-gzk-point-balance[^\d]*(\d+)"#,
            #"(?:当前早点|我的早点|早点余额|可用早点|拥有早点|早点)[^\d]{0,8}(\d+)"#,
            #"(\d+)\s*点早点"#,
            #"(\d+)\s*个早点"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               match.numberOfRanges > 1 {
                if let range = Range(match.range(at: 1), in: html) {
                    let num = String(html[range])
                    if !num.isEmpty {
                        logger("[PointsParser] 命中正则模式 \(pattern): \(num)")
                        return num
                    }
                }
            }
        }

        return nil
    }

    nonisolated func extractPoints(from html: String) -> String? {
        return Self.extractPoints(from: html)
    }

    /// 提取并应用信用等级
    private func extractAndApplyLevel(from html: String) {
        guard let doc = try? SwiftSoup.parse(html) else { return }
        if let levelElem = try? doc.select(".gzk-credit-level").first(),
           let lvl = try? levelElem.text().trimmingCharacters(in: .whitespacesAndNewlines),
           !lvl.isEmpty {
            self.creditLevel = lvl
            Persist.save(value: lvl, forkey: Self.levelCacheKey)
        }
    }

    /// 保存并应用早点数值
    private func applyPoints(_ value: String) {
        self.pointsBalance = value
        Persist.save(value: value, forkey: Self.pointsCacheKey)
        logger("[PointsParser] 成功同步最新早点余额: \(value)")
    }

    /// 刷新当前登录用户的早点余额与信用等级（多策略兜底）
    func fetchPointsSummary() async {
        guard AccountState.isLogin() else {
            self.pointsBalance = "0"
            self.creditLevel = ""
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        do {
            // 策略 1: 请求 /points 页面
            let pointsHtml = try await NetworkManager.shared.get(APIService.baseUrlString + APIService.points)
            logger("[PointsParser] 请求 /points 得到长度: \(pointsHtml.count)")
            if pointsHtml.contains("action=\"/login\"") {
                logger("[PointsParser] 提示：/points 返回了登录页面，需确保登录Cookie有效")
            }
            if let found = extractPoints(from: pointsHtml) {
                applyPoints(found)
                extractAndApplyLevel(from: pointsHtml)
                self.isLoading = false
                return
            }

            // 策略 2: 若 /points 未直接解析到，请求首页 /（首页侧边栏 .usercard 稳定输出当前用户早点卡片）
            logger("[PointsParser] 尝试从首页 / 提取早点卡片...")
            let homeHtml = try await NetworkManager.shared.get(APIService.baseUrlString + "/")
            logger("[PointsParser] 请求首页 / 得到长度: \(homeHtml.count)")
            if let found = extractPoints(from: homeHtml) {
                applyPoints(found)
                extractAndApplyLevel(from: homeHtml)
                self.isLoading = false
                return
            }

            // 策略 3: 请求 /points/ledger（收支明细页面）
            logger("[PointsParser] 尝试从收支明细 /points/ledger 提取...")
            let ledgerHtml = try await NetworkManager.shared.get(APIService.baseUrlString + APIService.pointsLedger)
            if let found = extractPoints(from: ledgerHtml) {
                applyPoints(found)
                extractAndApplyLevel(from: ledgerHtml)
                self.isLoading = false
                return
            }

            // 策略 4: 尝试个人主页 /u/{username}
            let userProfileUrl = AccountState.userName.userProfileUrl
            if !userProfileUrl.isEmpty && userProfileUrl != APIService.baseUrlString + "/u/" {
                logger("[PointsParser] 尝试从个人主页提取: \(userProfileUrl)...")
                let userHtml = try await NetworkManager.shared.get(userProfileUrl)
                if let found = extractPoints(from: userHtml) {
                    applyPoints(found)
                    extractAndApplyLevel(from: userHtml)
                    self.isLoading = false
                    return
                }
                extractAndApplyLevel(from: userHtml)
            }

            self.isLoading = false
        } catch {
            logger("[PointsParser] 抓取早点失败: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    /// 抓取早点收支/奖励流水明细
    func fetchLedger() async {
        guard AccountState.isLogin() else {
            self.ledgerItems.removeAll()
            return
        }

        self.isLedgerLoading = true
        self.ledgerErrorMessage = nil

        do {
            let html = try await NetworkManager.shared.get(APIService.baseUrlString + APIService.pointsLedger)
            let doc = try SwiftSoup.parse(html)

            var parsedItems: [PointsLedgerItem] = []

            // 解析表格形式的流水记录
            let rows = try doc.select("table.gzk-points-rules tbody tr, table tbody tr, .ui-content table tr")
            for row in rows {
                let cols = try row.select("td")
                if cols.count >= 3 {
                    let col0 = try cols[0].text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let col1 = try cols[1].text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let col2 = try cols[2].text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let col3 = cols.count > 3 ? (try cols[3].text().trimmingCharacters(in: .whitespacesAndNewlines)) : ""

                    parsedItems.append(
                        PointsLedgerItem(
                            action: col1.isEmpty ? "社区互动成长" : col1,
                            pointsChange: col2,
                            date: col0,
                            balance: col3,
                            desc: ""
                        )
                    )
                }
            }

            // 如果表格未解析到，尝试列表元素解析
            if parsedItems.isEmpty {
                let listItems = try doc.select(".ledger-item, .gzk-points-item, .ui-content .item")
                for item in listItems {
                    let title = (try? item.select(".title, .action").text()) ?? "社区互动成长"
                    let amount = (try? item.select(".amount, .points").text()) ?? ""
                    let time = (try? item.select(".time, .date").text()) ?? ""
                    if !title.isEmpty || !amount.isEmpty {
                        parsedItems.append(
                            PointsLedgerItem(
                                action: title,
                                pointsChange: amount,
                                date: time,
                                balance: "",
                                desc: ""
                            )
                        )
                    }
                }
            }

            self.ledgerItems = parsedItems
            self.isLedgerLoading = false
        } catch {
            logger("[PointsParser] 抓取明细失败: \(error.localizedDescription)")
            self.ledgerErrorMessage = error.localizedDescription
            self.isLedgerLoading = false
        }
    }

    /// 用户登出时清空状态
    func clear() {
        self.pointsBalance = "0"
        self.creditLevel = ""
        self.ledgerItems.removeAll()
        Persist.remove(key: Self.pointsCacheKey)
        Persist.remove(key: Self.levelCacheKey)
    }
}
