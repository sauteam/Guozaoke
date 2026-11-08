//
//  UserInfoParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/17.
//

import SwiftSoup
import SwiftUI

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
    
    let topicLink: String
    let replyLink: String
    let favoritesLink: String
    let topicCount: Int
    let replyCount: Int
    let favoritesCount: Int
    /// 信用值
    let reputationNumber: String

    let topics: [PostItem]
    let replies: [MyReply]
    var blockUser: Bool = false
    
    var level: String? = nil
    var levelTitle: String? = nil
    var isOnline: Bool = false
    var gender: String? = nil
    var generation: String? = nil
    var signature: String? = nil
    var displayName: String? = nil
    
    var followTextChange: String {
        if followText.isEmpty == true {
            return "+关注"
        }
        return followText.contains("取消") ? "取消关注" : "+关注"
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

/// 社区成员
struct Member: Identifiable {
    let id = UUID()
    let username: String
    let avatar: String
    let userLink: String
}

struct MemberInfo: Identifiable {
    let id = UUID()
    let title: String
    let member: [Member]
}

class UserInfoParser: ObservableObject {
    @Published var userInfo: UserInfo?
    @Published var topics: [PostItem] = []
    @Published var replies: [MyReply] = []
    @Published var memberInfo: [MemberInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    //@Published var blockUser: Bool = false

    private var currentPage = 1
    private var totalPages  = 1
    var hasMoreData   = true
    private var baseUrl: String = ""
    private var isUserInfoUrl = false
    private var rowEnum: PostItemEnum = .profileRow

    @Published var faqContent = ""
    @Published var faqContentBottom = ""
    
    func loadOtherTopic(topicUrl: String, reset: Bool) async {
        rowEnum = .homeRow
        await fetchUserInfoAndData(topicUrl, reset: false)
    }

    func loadMyTopic(linkUrl: String, reset: Bool) async {
        rowEnum = .collectionRow
        await fetchUserInfoAndData(linkUrl, reset: false)
    }
    
    var hadData: Bool {
        guard let _ = userInfo else {
            return false
        }
        return true
    }
    
    var noMoreTopics: Bool {
        return topics.count == userInfo?.topicCount
    }
    
    var noMoreReplies: Bool {
        return replies.count == userInfo?.replyCount
    }
    
    private func showToast() {
        runInMain {
            ToastView.warningToast(needLoginTextCanDo)
        }
    }
    
    func faqContentValid() -> Bool {
        return self.faqContent.count > 0
    }
    
    func loadMyBlockList() async {
        await memberList(url: APIService.blockedUser)
    }
    
    func fetchMemberList() async {
        await memberList(url: APIService.members)
    }

    func memberList(url: String) async {
        do {
            guard !isLoading  else { return }
            await MainActor.run {
                self.isLoading = true
                errorMessage = nil
            }
            let html = try await NetworkManager.shared.get(url)
            let document = try SwiftSoup.parse(html)
            let memberLists = try document.select(".member-lists")
            
            var memberInfo: [MemberInfo] = []
            for (_, memberList) in memberLists.enumerated() {
                var memberModel: [Member] = []
                let members = try memberList.select(".member")
                let title   = try memberList.select("span.title").text()
                for member in members {
                    let avatarURL = try member.select("img.avatar").attr("src")
                    let username = try member.select("span.username a").text()
                    let userLink = try member.select("a").attr("href")
                    memberModel.append(Member(username: username, avatar: avatarURL, userLink: userLink))
                }
                memberInfo.append(MemberInfo(title: title, member: memberModel))
            }
            logger("[member] \(memberInfo)")
            runInMain {
                self.isLoading  = false
                self.memberInfo = memberInfo
            }
            
        } catch {
            runInMain {
                self.isLoading  = false
            }
            logger("请求失败: \(error.localizedDescription)")
        }
    }
    
    func faqInfo() async -> (Bool, String)? {
        do {
            let html = try await NetworkManager.shared.get(APIService.faq)
            let document = try SwiftSoup.parse(html)
            
            var success = false

            let containerText = try document.select("div.container.mt15").html()
            let footerText = try document.select("div.footer.mt15").html()
            runInMain {
                self.faqContent = containerText 
                self.faqContentBottom = footerText
            }
            
            logger("Footer content \(containerText) \n \(footerText)")

            if self.faqContentValid() {
                success = true
            }
//            if let containerDiv = try document.select("div.container.mt15").first() {
//                let containerText = try containerDiv.text()
//                logger("Container content: \(containerText)")
//                runInMain {
//                    self.faqContent = containerText
//                }
//                success = true
//            } else {
//                logger("No div with class 'container mt15' found.")
//            }
                
//            if let footerDiv = try document.select("div.footer.mt15").first() {
//                let footerText = try footerDiv.text()
//                runInMain {
//                    self.faqContentBottom = footerText
//                }
//                logger("Footer content: \(footerText)")
//            } else {
//                logger("No div with class 'footer mt15' found.")
//            }
            return (success, html)
        } catch {
            logger("请求失败: \(error.localizedDescription)")
        }
        return (false, "")
    }

    
    func blockUserAction(_ userId: String?) async -> String {
        if !LoginStateChecker.isLogin {
            self.showToast()
            LoginStateChecker.LoginStateHandle()
            return ""
        }
        
        guard let userId else {
            return ""
        }
        
        do {
            let html = try await NetworkManager.shared.get(userId)
            runInMain {
                self.userInfo?.blockUser.toggle()
                let isBlocked = self.userInfo?.blockUser
                if isBlocked  == false {
                    self.userInfo?.blockText = "屏蔽此账号"
                    self.userInfo?.blockLink = self.userInfo?.blockLink?.replacingOccurrences(of: "block", with: "unblock")
                } else {
                    self.userInfo?.blockText = "取消屏蔽"
                    self.userInfo?.blockLink = self.userInfo?.blockLink?.replacingOccurrences(of: "unblock", with: "block")
                }
                ToastView.successToast(isBlocked == true ? "屏蔽成功": "取消屏蔽成功")
            }
            return html
        } catch {
            logger("请求失败: \(error.localizedDescription)")
        }
        return ""
    }
            
    func followUserAction(_ targetUrl: String?) async -> (Bool, String)? {
        if !LoginStateChecker.isLogin {
            runInMain {
                LoginStateChecker.LoginStateHandle()
                self.showToast()
            }
            return (false, "")
        }
        
        guard let targetUrl = targetUrl, !targetUrl.isEmpty else {
            return (false, "")
        }
        
        do {
            let html = try await NetworkManager.shared.get(targetUrl)
            let doc = try SwiftSoup.parse(html)
            
            // 提取更新后的关注按钮元素
            let followElement = try doc.select(".gzk-profile-follow a, .label.label-success a, a[href^='/f/user/'], a[href^='/f/']").first()
            let newFollowLink = try followElement?.attr("href") ?? ""
            var newFollowText = try followElement?.text() ?? ""
            if newFollowText.isEmpty {
                newFollowText = try doc.select(".gzk-profile-follow, .label.label-success").text()
            }
            
            let _ = try LoginStateChecker.shared.htmlCheckUserState(doc: doc)

            logger("followUserAction result: text=\(newFollowText) link=\(newFollowLink)")
            
            await MainActor.run {
                if !newFollowText.isEmpty {
                    self.userInfo?.followText = newFollowText
                } else if let curText = self.userInfo?.followText {
                    self.userInfo?.followText = curText.contains("取消") ? "+关注" : "取消关注"
                }
                if !newFollowLink.isEmpty {
                    self.userInfo?.followLink = newFollowLink
                }
            }
            return (true, html)
        } catch {
            logger("关注请求失败: \(error.localizedDescription)")
        }
        return nil
    }

    func fetchUserInfoAndData(_ userId: String, reset: Bool = false) async {
        let trimmedId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty &&
              trimmedId != APIService.baseUrlString + "/u/" &&
              trimmedId != "/u/" &&
              trimmedId != APIService.baseUrlString &&
              trimmedId != APIService.baseUrlString + "/u" else {
            logger("[UserInfo] 用户名或主页路径无效，跳过加载: \(userId)")
            return
        }
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
                url = "\(baseUrl)?p=\(currentPage)"
            }
            let html = try await NetworkManager.shared.get(url)
            let doc = try SwiftSoup.parse(html)
            
            

            let newTopics  = try parseTopics(doc: doc, isTopic: true)
            let newReplies = try parseReply(doc: doc)
            try self.parsePagination(doc: doc)
            logger("currentPage \(currentPage) totalPages \(totalPages) newTopics \(newTopics.count) newReplies \(newReplies)")
            

            let _ =  try LoginStateChecker.shared.htmlCheckUserState(doc: doc)

            if reset || userInfo == nil || currentPage <= 1 {
                let parsedUserInfo = try parseUserInfo(doc: doc)
                await MainActor.run {
                    self.topics.removeAll()
                    self.replies.removeAll()
                    self.userInfo = parsedUserInfo
                    
                    // 如果拉取的是当前登录用户的个人主页，同步头像到 AccountState
                    if AccountState.isSelf(userName: parsedUserInfo.username) || parsedUserInfo.username == AccountState.userName {
                        if let account = AccountState.getAccount() {
                            var updated = account
                            if !parsedUserInfo.avatar.isEmpty && updated.avatar != parsedUserInfo.avatar {
                                updated.avatar = parsedUserInfo.avatar
                                AccountState.saveAccount(updated)
                                logger("[UserInfoParser] 同步头像至本地账户: \(parsedUserInfo.avatar)")
                            }
                        }
                    }
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

    private func parseUserInfo(doc: SwiftSoup.Document) throws -> UserInfo {
        // Avatar
        let avatarElement = try doc.select(".ui-header a img").first()
        let avatar = try avatarElement?.attr("src") ?? ""
        var username = try doc.select(".ui-header .username").first()?.text() ?? ""
        if username.isEmpty {
            if let href = try doc.select(".ui-header a[href^='/u/']").first()?.attr("href") {
                username = href.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let range = username.range(of: "Lv.", options: .caseInsensitive) {
            username = String(username[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Level & Online & Demographics
        let level = try doc.select(".gzk-credit-level").first()?.text()
        let levelTitle = try doc.select(".gzk-credit-level").first()?.attr("title")
        let isOnline = try !(doc.select(".gzk-online").isEmpty)
        let gender = try doc.select(".gzk-profile-gender").first()?.attr("title")
        let generation = try doc.select(".gzk-profile-generation").first()?.text()
        let signature = try doc.select(".gzk-card-signature").first()?.text()
        let displayName = try doc.select(".gzk-card-display a.gzk-display-name bdi").first()?.text()
        
        // Number
        let numberElement = try doc.select(".user-number .number").first()
        let number = try numberElement?.text() ?? ""
        // Since
        let sinceElement = try doc.select(".user-number .since").first()
        let since = try sinceElement?.text() ?? ""

        // Follow Link - 支持新旧版各种选择器
        let followElement = try doc.select(".gzk-profile-follow a, .label.label-success a, a[href^='/f/user/'], a[href^='/f/']").first()
        var followLink = try followElement?.attr("href") ?? ""
        var followText = try followElement?.text() ?? ""
        if followText.isEmpty {
            followText = try doc.select(".gzk-profile-follow, .label.label-success").text()
        }
        if followLink.isEmpty && !username.isEmpty {
            followLink = "/f/user/\(username)"
        }
        if followText.isEmpty {
            followText = "+关注"
        }
        logger("followText \(followText) followLink \(followLink)")
        let idElement = try doc.select("dl:has(dt:contains(ID)) dd").first()
        let id = try idElement?.text() ?? ""
        // Nickname
        var nicknameElement = try doc.select("dl:has(dt:contains(昵称)) dd").text()
        if nicknameElement.isEmpty, let dName = displayName, !dName.isEmpty {
            nicknameElement = dName
        }
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
        let hasLevel = (level != nil && !level!.isEmpty)
        // 打印解析结果
        for (key, value) in parsedData {
            // 如果已展示等级（等级中已包含信用等级和具体信用分），避免重复展示独立的“信用”
            if hasLevel && (key == "信用" || key.contains("信用")) {
                continue
            }
            logger("[userInfo]\(key): \(value)")
            profile.append("\(key): \(value)")
        }
        
        // 把等级、在线状态等加入资料中
        if let lvl = level, !lvl.isEmpty {
            let desc = (levelTitle != nil && levelTitle?.isEmpty == false) ? "\(lvl)（\(levelTitle!)）" : lvl
            profile.insert("等级: \(desc)", at: 0)
        }
        if isOnline {
            profile.insert("状态: 在线 🟢", at: 0)
        }
        if let gen = generation, !gen.isEmpty {
            profile.append("年代: \(gen)")
        }
        if let g = gender, !g.isEmpty {
            profile.append("性别: \(g)")
        }
        if let sig = signature, !sig.isEmpty {
            profile.append("签名: \(sig)")
        }
        
        let topicsCount = try doc.select(".status-topic strong a").text()
        let topicsLink = try doc.select(".status-topic strong a").attr("href")
        let repliesCount = try doc.select(".status-reply strong a").text()
        let repliesLink = try doc.select(".status-reply strong a").attr("href")
        let favoritesCount = try doc.select(".status-favorite strong a").text()
        let favoritesLink = try doc.select(".status-favorite strong a").attr("href")
        let reputation = try doc.select(".status-reputation strong").text()

        // 仅在未成功解析出等级时兜底展示独立的信用行，避免重复
        if !hasLevel && !reputation.isEmpty {
            profile.insert("信用: \(reputation)", at: 0)
        }

        var blockText: String = "屏蔽此账号"
        var blockLink: String = ""
        var blockUser = false
        if let linkElement = try doc.select("div.self-introduction.container-box.mt10 a").first() {
            let linkText = try linkElement.text()
            let linkHref = try linkElement.attr("href")
            blockText = linkText
            /// 显示这个
            if linkText != "屏蔽此帐号" {
                blockText = "取消屏蔽"
                blockUser = true
            }
            blockLink = linkHref
            logger("文本内容: \(linkText)")
            logger("链接地址: \(linkHref)")
        } 
        
        return UserInfo(
            avatar: avatar,
            username: username,
            usernameLink: id,
            joinDate: since,
            number: number,
            followText: followText,
            followLink: followLink,
            nickname: nicknameElement,
            email: email,
            blockText: blockText,
            blockLink: blockLink,
            profileInfo: profile,
            topicLink: topicsLink,
            replyLink: repliesLink,
            favoritesLink: favoritesLink,
            topicCount: topicsCount.int,
            replyCount: repliesCount.int,
            favoritesCount: favoritesCount.int,
            reputationNumber: reputation,
            topics: topics,
            replies: replies,
            blockUser: blockUser,
            level: level,
            levelTitle: levelTitle,
            isOnline: isOnline,
            gender: gender,
            generation: generation,
            signature: signature,
            displayName: displayName
        )
    }

    private func parseReply(doc: SwiftSoup.Document) throws -> [MyReply] {
        let topics = try doc.select("div.reply-item")
        
        return try topics.map { element in
            let topicLink = try element.select("span.title a[href^='/t/']").attr("href")
            let titleLink = topicLink.isEmpty ? (try element.select("a[href^='/t/']").attr("href")) : topicLink
            let finalLink = titleLink.isEmpty ? (try element.select("a").attr("href")) : titleLink
            return MyReply(
                title: try element.select("span.title").text(),
                titleLink: finalLink,
                content: try element.select("div.content").text(),
                mentionedUser: try element.select("a.user-mention").text(),
                userLink: try element.select("a.user-mention").attr("href")
            )
        }
    }
    
    // 解析帖子列表
    private func parseTopics(doc: SwiftSoup.Document, isTopic: Bool) throws -> [PostItem] {
        let topics = try doc.select("div.topic-item")
        return try topics.map { element in
            var authorName = try element.select("span.username a[href^='/u/'] strong").first()?.text() ?? ""
            if authorName.isEmpty {
                authorName = try element.select("span.username a[href^='/u/']").first()?.text() ?? ""
            }
            if authorName.isEmpty {
                authorName = try element.select("span.username a").first()?.text() ?? ""
            }
            if authorName.isEmpty {
                if let userLink = try element.select("a[href^='/u/']").first()?.attr("href") {
                    authorName = userLink.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if authorName.isEmpty {
                authorName = try element.select("span.username").text()
            }
            if let range = authorName.range(of: "Lv.", options: .caseInsensitive) {
                authorName = String(authorName[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            authorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var lastReply = try element.select("span.last-reply-username a strong").first()?.text() ?? ""
            if lastReply.isEmpty {
                lastReply = try element.select("span.last-reply-username a").first()?.text() ?? ""
            }
            if lastReply.isEmpty {
                if let link = try element.select("span.last-reply-username a").first()?.attr("href") {
                    lastReply = link.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            lastReply = lastReply.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastReplyUser = lastReply.isEmpty ? nil : lastReply
            
            let level = try element.select(".gzk-credit-level").first()?.text()
            let isOnline = try !(element.select(".gzk-online").isEmpty)
            let displayName = try element.select(".gzk-visible-identity bdi, a.gzk-display-name bdi").first()?.text()

            return PostItem(
                title: try element.select("h3.title a").text(),
                link: try element.select("h3.title a").attr("href"),
                author: authorName,
                avatar: try element.select("img.avatar").attr("src"),
                node: try element.select("span.node a").text(),
                nodeUrl: try element.select("span.node a").attr("href"),
                time: try element.select("span.last-touched").text(),
                replyCount: Int(try element.select("div.count a").text()) ?? 0,
                lastReplyUser: lastReplyUser,
                rowEnum: rowEnum,
                bookmark: try element.select("h3.title a i").first()?.attr("title") ?? "",
                isOnline: isOnline,
                level: level,
                displayName: displayName
            )
        }
    }
    
    // 解析分页信息
    private func parsePagination(doc: SwiftSoup.Document) throws {
        if let lastPage = try doc.select("ul.pagination li:nth-last-child(2) a").first() {
            totalPages = Int(try lastPage.text()) ?? 1
        }
    }
}

