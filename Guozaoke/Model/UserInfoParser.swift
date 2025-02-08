//
//  UserInfoParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/17.
//

import SwiftSoup
import SwiftUI
import JDStatusBarNotification

struct UserInfo {
    let avatar: String
    let username: String
    let usernameLink: String
    let joinDate: String
    let number: String
    var followText: String
    var followLink: String
    let nickname: String
    let email: String
    var blockText: String?
    var blockLink: String?
    let profileInfo: [String]
    
    let topics: [PostItem]
    let replies: [MyReply]
    
    var followTextChange: String {
        if followText.isEmpty == true {
            return "+关注"
        }
        return followText == "取消关注" ? "取消关注" : "+关注"
    }
    
    var isBlocked: Bool {
        return blockText == "屏蔽此帐号" ? false : true
    }
}

struct MyReply: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let titleLink: String
    let content: String
    let mentionedUser: String?
    let userLink: String?
}

class UserInfoParser: ObservableObject {
    @Published var userInfo: UserInfo?
    @Published var topics: [PostItem] = []
    @Published var replies: [MyReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentPage = 1
    private var totalPages  = 1
    var hasMoreData   = true
    private var baseUrl: String = ""
    private var isUserInfoUrl = false
    
    func loadMyTopic(type: MyTopicEnum, reset: Bool) async {
        await fetchUserInfoAndData("/u/"+"\(AccountState.userName)/" + type.rawValue, reset: false)
    }
    
    var hadData: Bool {
        guard let _ = userInfo else {
            return false
        }
        return true
    }
    
    private func showToast() {
        runInMain {
            NotificationPresenter.shared.present(needLoginTextCanDo, includedStyle: .dark, duration: toastDuration)
        }
    }
    
    func blockUserAction(_ userId: String?) async -> String {
        if !LoginStateChecker.isLogin() {
            self.showToast()
            return ""
        }
        
        guard let userId else {
            return ""
        }
        
        do {
            let html = try await NetworkManager.shared.get(userId)
            runInMain {
                if self.userInfo?.isBlocked  == true {
                    self.userInfo?.blockText = "屏蔽此账号"
                    self.userInfo?.blockLink = self.userInfo?.blockLink?.replacingOccurrences(of: "block", with: "unblock")
                } else {
                    self.userInfo?.blockText = "取消屏蔽"
                    self.userInfo?.blockLink = self.userInfo?.blockLink?.replacingOccurrences(of: "unblock", with: "block")
                }
            }
            return html
        } catch {
            log("请求失败: \(error.localizedDescription)")
        }
        return ""
    }
            
    func followUserAction(_ userId: String?) async -> (Bool, String)? {
        if !LoginStateChecker.isLogin() {
            runInMain {
                self.showToast()
            }
            return (false, "")
        }
        
        guard let userId else {
            return (false, "")
        }
        
        do {
            let html = try await NetworkManager.shared.get(userId)
            let doc = try SwiftSoup.parse(html)
            // Follow Link
            let followElement = try doc.select(".label.label-success a").first()
            let followLink = try followElement?.attr("href") ?? ""
            
            let _ = try LoginStateChecker.shared.htmlCheckUserState(doc: doc)

            let followText = try doc.select(".label.label-success").text()
            log("followText \(followText) followLink\(followLink)")
            var success = false
            if followText != userInfo?.followText {
                success = true
                await MainActor .run {
                    userInfo?.followText = followText
                    userInfo?.followLink = followLink
                }
            }
            return (success, html)
        } catch {
            log("请求失败: \(error.localizedDescription)")
        }
        return nil
    }

    func fetchUserInfoAndData(_ userId: String, reset: Bool = false) async {
        baseUrl = userId
        guard !isLoading && (hasMoreData || reset) else { return }
        await MainActor.run {
            self.isLoading = true
            errorMessage = nil
        }

        do {
            if reset {
                await MainActor.run {
                    currentPage = 1
                    hasMoreData = true
                    self.topics.removeAll()
                    self.replies.removeAll()
                }
            }
            
            var url = "\(baseUrl)"
            if currentPage > 1 {
                url = "\(baseUrl)?page=\(currentPage)"
            }
            let html = try await NetworkManager.shared.get(url)
            let doc = try SwiftSoup.parse(html)

            let newTopics  = try parseTopics(doc: doc, isTopic: true)
            let newReplies = try parseReply(doc: doc)
            try self.parsePagination(doc: doc)
            
            let _ =  try LoginStateChecker.shared.htmlCheckUserState(doc: doc)

            if reset || userInfo == nil {
                let parsedUserInfo = try parseUserInfo(doc: doc)
                await MainActor.run {
                    self.userInfo = parsedUserInfo
                }
            }

            if newTopics.isEmpty && newReplies.isEmpty {
                await MainActor.run {
                    self.hasMoreData = false
                }
            } else {
                await MainActor.run {
                    self.topics.append(contentsOf: newTopics)
                    self.replies.append(contentsOf: newReplies)
                    self.currentPage += 1
                    self.hasMoreData = self.currentPage <= self.totalPages
                }
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }

    }

    private func parseUserInfo(doc: Document) throws -> UserInfo {
        // Avatar
        let avatarElement = try doc.select(".ui-header a img").first()
        let avatar = try avatarElement?.attr("src") ?? ""
        let username = try doc.select(".ui-header .username").first()?.text() ?? ""
        // Number
        let numberElement = try doc.select(".user-number .number").first()
        let number = try numberElement?.text() ?? ""
        // Since
        let sinceElement = try doc.select(".user-number .since").first()
        let since = try sinceElement?.text() ?? ""

        // Follow Link
        let followElement = try doc.select(".label.label-success a").first()
        let followLink = try followElement?.attr("href") ?? ""
        
        let followText = try doc.select(".label.label-success").text()
        log("followText \(followText) followLink\(followLink)")
        let idElement = try doc.select("dl:has(dt:contains(ID)) dd").first()
        let id = try idElement?.text() ?? ""
        // Nickname
        let nicknameElement = try doc.select("dl:has(dt:contains(昵称)) dd").text()
        // Email
        let emailElement = try doc.select("dl:has(dt:contains(Email)) dd").first()
        let email = try emailElement?.text() ?? ""
        
        let dls = try doc.select("dl")
        var parsedData: [String: String] = [:]
        for dl in dls {
                let key = try dl.select("dt").text()
                let valueElement = try dl.select("dd")
                var value = try valueElement.text()
                // 如果 `dd` 里面包含 `<a>` 链接，则取 `href`
                if let link = try? valueElement.select("a").attr("href"), !link.isEmpty {
                    value = link
                }
                parsedData[key] = value
            }
        
        var profile:[String] = []
        // 打印解析结果
        for (key, value) in parsedData {
            print("[userInfo]\(key): \(value)")
            profile.append("\(key): \(value)")
        }
        
        var blockText: String = "屏蔽此账号", blockLink: String = ""
        if let linkElement = try doc.select("div.self-introduction.container-box.mt10 a").first() {
            let linkText = try linkElement.text()
            let linkHref = try linkElement.attr("href")
            blockText = linkText
            blockLink = linkHref
            print("文本内容: \(linkText)")
            print("链接地址: \(linkHref)")
        } else {
            
        }
        
        return UserInfo(avatar: avatar, username: username, usernameLink: id, joinDate: since, number: number, followText:followText, followLink: followLink, nickname: nicknameElement, email: email, blockText: blockText, blockLink: blockLink, profileInfo: profile, topics: topics, replies: replies)
    }

    private func parseReply(doc: Document) throws -> [MyReply] {
        let topics = try doc.select("div.reply-item")
        return try topics.map { element in
            MyReply(
                title: try element.select("span.title").text(),
                titleLink: try element.select("a").attr("href"),
                content: try element.select("div.content").text(),
                mentionedUser: try element.select("a.user-mention").text(),
                userLink: try element.select("a.user-mention").attr("href")
            )
        }
    }
    
    // 解析帖子列表
    private func parseTopics(doc: Document, isTopic: Bool) throws -> [PostItem] {
        let topics = try doc.select("div.topic-item")
        return try topics.map { element in
            PostItem(
                title: try element.select("h3.title a").text(),
                link: try element.select("h3.title a").attr("href"),
                author: try element.select("span.username a").text(),
                avatar: try element.select("img.avatar").attr("src"),
                node: try element.select("span.node a").text(),
                nodeUrl: try element.select("span.node a").attr("href"),
                time: try element.select("span.last-touched").text(),
                replyCount: Int(try element.select("div.count a").text()) ?? 0,
                lastReplyUser: try element.select("span.last-reply-username a strong").first()?.text(), rowEnum: .profileRow
            )
        }
    }
    
    // 解析分页信息
    private func parsePagination(doc: Document) throws {
        if let lastPage = try doc.select("ul.pagination li:nth-last-child(2) a").first() {
            totalPages = Int(try lastPage.text()) ?? 1
        }
    }
}
