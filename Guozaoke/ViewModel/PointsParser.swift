//
//  PointsParser.swift
//  Guozaoke
//
//  Created by scy on 2026/11/14.
//

import Foundation
import SwiftSoup
import SwiftUI

// MARK: - 明细标签分类
enum LedgerTab: Int, CaseIterable, Identifiable {
    case all = 0
    case rewards = 1
    case credit = 2
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .all: return "全部明细"
        case .rewards: return "奖励记录"
        case .credit: return "信用明细"
        }
    }
    
    var queryPath: String {
        switch self {
        case .all: return APIService.pointsLedger
        case .rewards: return "\(APIService.pointsLedger)?type=rewards"
        case .credit: return "\(APIService.pointsLedger)?type=credit"
        }
    }
}

// MARK: - 积分收支明细模型
struct PointsLedgerItem: Identifiable, Equatable {
    let id = UUID()
    let action: String         // 如 "发布有效主题", "有效主题奖励", "回复被采纳", "主题获赞"
    let pointsChange: String   // 如 "+5", "+1"
    let date: String           // 如 "2026-11-12 14:30"
    let balance: String        // 结余，如 "6"
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
    @Published var recentRewards: [PointsLedgerItem] = []
    @Published var currentLedgerTab: LedgerTab = .all
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

    /// 从 HTML 中多策略提取早点数值（精准匹配，严防误读分页或规则中的数字）
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
           let num = extractDigits(from: text), !num.isEmpty {
            logger("[PointsParser] 命中卡片选择器 .gzk-points-card-value: \(num)")
            return num
        }

        // 3. 积分卡片 a.gzk-points-card
        if let card = try? doc.select("a.gzk-points-card").first(),
           let text = try? card.text(),
           let num = extractDigits(from: text), !num.isEmpty {
            logger("[PointsParser] 命中 a.gzk-points-card: \(num)")
            return num
        }

        // 4. 列表形式 dl:has(dt:contains(早点)) dd
        if let dd = try? doc.select("dl:has(dt:contains(早点)) dd").first(),
           let text = try? dd.text(),
           let num = extractDigits(from: text), !num.isEmpty {
            logger("[PointsParser] 命中 dl 早点: \(num)")
            return num
        }

        // 5. 个人主页/侧边栏 points 容器: .usercard .status-points
        let pointsSpecificSelectors = [
            ".usercard .status-points strong",
            ".usercard .status-points a",
            ".status-points strong a",
            ".status-points strong",
            ".points-balance",
            ".gzk-points-balance",
            ".gzk-profile-points strong",
            ".gzk-points .ui-content strong"
        ]
        for sel in pointsSpecificSelectors {
            if let elem = try? doc.select(sel).first(),
               let text = try? elem.text(),
               let num = extractDigits(from: text),
               !num.isEmpty {
                logger("[PointsParser] 命中特定选择器 \(sel): \(num)")
                return num
            }
        }

        // 6. 正则表达式高精度扫描（严格限定前后文包含“早点”或“余额”，绝不匹配裸链接或分页标签）
        let patterns = [
            #"data-gzk-point-balance[^\d]*(\d+)"#,
            #"(?:当前早点|我的早点|早点余额|可用早点|拥有早点)\s*[：:]?\s*(\d+)"#,
            #"[>\"'\s](\d+)\s*(?:个|点)?早点"#,
            #"[>\"'\s]早点\s*[：:]?\s*(\d+)\s*(?:点)?"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               match.numberOfRanges > 1 {
                if let range = Range(match.range(at: 1), in: html) {
                    let text = String(html[range])
                    if let num = extractDigits(from: text), !num.isEmpty {
                        logger("[PointsParser] 命中高精度正则模式 \(pattern): \(num)")
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

    /// 从页面中解析奖励记录与明细列表（严格要求必须带真实时间戳，排除静态规则说明表）
    nonisolated static func parseLedgerItems(from html: String) -> [PointsLedgerItem] {
        guard let doc = try? SwiftSoup.parse(html) else { return [] }
        var results: [PointsLedgerItem] = []

        // 1. 查找所有流水表格行（严格排除静态规则表 .gzk-points-rules）
        if let tables = try? doc.select("table:not(.gzk-points-rules)") {
            for table in tables {
                // 如果表格头部或内容包含“规则说明”或“等级划分”，跳过该静态表
                let tableHeader = (try? table.select("th, thead").text()) ?? ""
                if tableHeader.contains("说明") && tableHeader.contains("区间") {
                    continue
                }

                guard let rows = try? table.select("tbody tr, tr") else { continue }
                for row in rows {
                    guard let cols = try? row.select("td"), cols.count >= 2 else { continue }

                    var date = ""
                    var action = ""
                    var change = ""
                    var balance = ""

                    let colTexts = cols.array().map { (try? $0.text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? "" }

                    for text in colTexts {
                        // 识别变动数额：如 "+5", "-2", "+5 点", "+1"
                        if text.hasPrefix("+") || text.hasPrefix("-") || (text.contains("点") && (text.contains("+") || text.contains("-"))) {
                            change = text
                        } else if (text.contains("-") || text.contains(":") || text.contains("前") || text.contains("月") || text.contains("年")) && text.count >= 4 && text.count <= 25 && text.contains(where: { $0.isNumber }) {
                            // 识别时间：如 "2026-11-14 12:30", "11-14 12:30", "2026-11-14", "2小时前"
                            date = text
                        } else if text.contains("奖励") || text.contains("主题") || text.contains("回复") || text.contains("点赞") || text.contains("收藏") || text.contains("置精") || text.contains("采纳") || text.contains("签到") || text.contains("登录") || text.contains("扣除") {
                            action = text
                        } else if balance.isEmpty && !text.isEmpty && text.allSatisfy({ $0.isNumber }) {
                            balance = text
                        }
                    }

                    // 必须具备有效时间戳，防止将静态规则当成流水记录误读
                    guard !date.isEmpty else { continue }

                    // 如果未直接识别出 action，按位置兜底
                    if action.isEmpty && cols.count >= 2 {
                        action = colTexts[0] == date ? colTexts[1] : colTexts[0]
                    }

                    // 如果变动未被带符号识别，但有数字且行为属于奖励/获得
                    if change.isEmpty {
                        for text in colTexts where text != date && text != action && text != balance {
                            if let digits = extractDigits(from: text), !digits.isEmpty {
                                change = action.contains("扣除") ? "-\(digits)" : "+\(digits)"
                                break
                            }
                        }
                    }

                    // 如果仍然没有有效数额变动，跳过
                    guard !change.isEmpty, change.contains(where: { $0.isNumber }) else { continue }

                    if !change.hasPrefix("+") && !change.hasPrefix("-") {
                        change = "+" + change
                    }

                    results.append(PointsLedgerItem(
                        action: action.isEmpty ? "社区有效奖励" : action,
                        pointsChange: change,
                        date: date,
                        balance: balance,
                        desc: ""
                    ))
                }
            }
        }

        // 2. 查找卡片/列表形式的奖励项（严格要求带时间戳）
        if results.isEmpty {
            if let items = try? doc.select(".ledger-item, .gzk-points-item, .cell:has(.time), .cell:has(.date), .item:has(.time), .item:has(.date)") {
                for item in items {
                    let text = (try? item.text()) ?? ""
                    let time = (try? item.select(".time, .date, .created, .ago").first()?.text()) ?? ""
                    // 无时间戳则跳过，杜绝把静态规则卡片误读为流水
                    guard !time.isEmpty else { continue }

                    let title = (try? item.select(".title, .action, strong, b").first()?.text()) ?? ""
                    let amount = (try? item.select(".amount, .points, .badge, .label").first()?.text()) ?? ""

                    var finalAction = title.isEmpty ? text : title
                    var finalChange = amount

                    // 从文本中正则匹配 "+X" 或 "早点 +X"
                    if finalChange.isEmpty {
                        if let regex = try? NSRegularExpression(pattern: #"([+-]\s*\d+)"#),
                           let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)),
                           let r = Range(m.range(at: 1), in: text) {
                            finalChange = String(text[r])
                        }
                    }

                    guard !finalChange.isEmpty, finalChange.contains(where: { $0.isNumber }) else { continue }

                    if !finalChange.hasPrefix("+") && !finalChange.hasPrefix("-") {
                        finalChange = "+" + finalChange
                    }

                    results.append(PointsLedgerItem(
                        action: finalAction,
                        pointsChange: finalChange,
                        date: time,
                        balance: "",
                        desc: ""
                    ))
                }
            }
        }

        return results
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
            // 策略 1: 请求 /points 页面（包含余额与近期有效奖励展示）
            let pointsHtml = try await NetworkManager.shared.get(APIService.baseUrlString + APIService.points)
            logger("[PointsParser] 请求 /points 得到长度: \(pointsHtml.count)")
            if pointsHtml.contains("action=\"/login\"") {
                logger("[PointsParser] 提示：/points 返回了登录页面，需确保登录Cookie有效")
            }
            
            // 同时从 /points 页面解析有效奖励流水（如“有效主题奖励 +5”）
            let rewards = Self.parseLedgerItems(from: pointsHtml)
            if !rewards.isEmpty {
                logger("[PointsParser] 从 /points 成功解析到 \(rewards.count) 条奖励记录")
                self.recentRewards = rewards
                if self.ledgerItems.isEmpty {
                    self.ledgerItems = rewards
                }
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

            // 策略 3: 尝试个人主页 /u/{username}
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

    /// 抓取早点收支/奖励流水明细（支持分 Tab 获取：全部、奖励、信用）
    func fetchLedger(tab: LedgerTab = .all) async {
        guard AccountState.isLogin() else {
            self.ledgerItems.removeAll()
            return
        }

        self.currentLedgerTab = tab
        self.isLedgerLoading = true
        self.ledgerErrorMessage = nil

        do {
            let targetUrl = APIService.baseUrlString + tab.queryPath
            logger("[PointsParser] 抓取流水明细 [\(tab.title)]: \(targetUrl)")
            let html = try await NetworkManager.shared.get(targetUrl)

            var parsedItems = Self.parseLedgerItems(from: html)

            // 如果请求的是奖励记录但返回为空，使用 /points 提取到的近期奖励兜底
            if tab == .rewards && parsedItems.isEmpty && !self.recentRewards.isEmpty {
                logger("[PointsParser] 奖励记录使用 /points 兜底数据")
                parsedItems = self.recentRewards
            }

            self.ledgerItems = parsedItems
            self.isLedgerLoading = false
        } catch {
            logger("[PointsParser] 抓取明细失败: \(error.localizedDescription)")
            // 如果分 Tab 失败且是奖励记录，尝试使用 /points 近期奖励兜底展示
            if tab == .rewards && !self.recentRewards.isEmpty {
                self.ledgerItems = self.recentRewards
                self.isLedgerLoading = false
            } else {
                self.ledgerErrorMessage = error.localizedDescription
                self.isLedgerLoading = false
            }
        }
    }

    /// 用户登出时清空状态
    func clear() {
        self.pointsBalance = "0"
        self.creditLevel = ""
        self.ledgerItems.removeAll()
        self.recentRewards.removeAll()
        Persist.remove(key: Self.pointsCacheKey)
        Persist.remove(key: Self.levelCacheKey)
    }
}
