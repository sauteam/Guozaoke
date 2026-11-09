//
//  ForumParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup
import Alamofire
import WidgetKit

enum PostItemEnum {
    case homeRow, detailRow, profileRow, nodeInfo, search, collectionRow
}

enum PostTypeEnum {
    case none, elite
}

// MARK: - 数据模型
struct PostItem: Identifiable,Equatable {
    let id = UUID()
    let title: String
    let link: String
    let author: String
    let avatar: String
    /// 节点 汤逊湖
    let node: String
    /// 节点链接 /node/water
    let nodeUrl: String
    var time: String
    let replyCount: Int
    let lastReplyUser: String?
    var rowEnum: PostItemEnum  = .homeRow
    var postType: PostTypeEnum = .none
    var bookmark: String = ""
    var isOnline: Bool = false
    var level: String? = nil
    var displayName: String? = nil
    
    var isJHTopic: Bool {
        return bookmark == "精华主题"
    }
}

struct NavItem: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    //let isActive: Bool
}

struct NodeItem: Identifiable, Hashable, Equatable {
    let id = UUID()
    let category: String
    let nodes: [Node]
}

struct Node: Hashable, Equatable {
    //let id = UUID()
    /// 文字
    var title: String
    /// 比如 /nodes/job 找工作
    var link: String
}

struct NodeInfo: Hashable, Equatable {
    //let id = UUID()
    var title: String
    /// 比如 /nodes/job 找工作
    var link: String
    var followText: String
    var followLink: String
    var description: String
    var creatLink: String
}

/// 今日最热
struct HotTodayTopic: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let user: String
    let avatar: String
}

/// 运行状态
struct CommunityStatus: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

/// 编辑帖子信息
struct EditPostInfo: Identifiable {
    let id = UUID()
    let title: String?
    let content: String?
}

// MARK: - 数据模型
class PostListParser: ObservableObject {
    @Published var navItems: [NavItem] = []
    @Published var posts: [PostItem] = []
    /// 节点导航 所有节点
    @Published var nodes: [NodeItem] = []
    /// 最热节点
    @Published var hotNodes: [NodeItem] = []
    @Published var onlyHotNodes: [Node] = []
    @Published var communityStatusList: [CommunityStatus] = []
    @Published var onlyNodes: [Node] = []
    @Published var nodeInfo: NodeInfo?
    @Published var hotTodayTopic: [HotTodayTopic] = []
    @Published var currentPage = 1
    @Published var totalPages  = 1
    @Published var isLoading   = false
    @Published var error: String?
    @Published var hasMore = true
    @Published var needLogin = false
    @Published var notificationLinksCount = 0
    @Published var isFollowedNodeInfo = false

    private var currentType: PostListType?
    private var urlHeader: String?
    private var url: String?
    private var rowEnum: PostItemEnum = .homeRow
    
    // MARK: - Widget Data Update
    private func updateWidgetData() {        
        syncVIPStatusToWidget()
        syncPostsToWidget()
        triggerWidgetRefresh()
    }
    
    private func syncVIPStatusToWidget() {
        let isVIP = PurchaseAppState().isPurchased
        // 保存到App Groups
        if let userDefaults = UserDefaults(suiteName: guozaokeGroup) {
            userDefaults.set(isVIP, forKey: "is_vip_user")
            userDefaults.set(AppInfo.appVersion, forKey: "app_version")
            // Sync VIP status to Widget
        }
    }
    
    private func syncPostsToWidget() {
        guard let userDefaults = UserDefaults(suiteName: guozaokeGroup) else { return }
        
        struct WidgetPostExport: Codable {
            let id: String
            let title: String
            let author: String
            let timeAgo: String
            let replyCount: Int
            let node: String
            let url: String?
        }
        
        let exportPosts = self.posts.prefix(20).map { post in
            WidgetPostExport(
                id: post.id.uuidString,
                title: post.title,
                author: post.author,
                timeAgo: post.time,
                replyCount: post.replyCount,
                node: post.node,
                url: post.link
            )
        }
        
        do {
            let data = try JSONEncoder().encode(exportPosts)
            let typeKey = currentType?.rawValue ?? "最新"
            userDefaults.set(data, forKey: "posts_\(typeKey)")
            userDefaults.set(Date(), forKey: "posts_\(typeKey)_timestamp")
            
            if currentType == nil || currentType == .latest || currentType == .hot {
                userDefaults.set(data, forKey: "latest_posts")
                userDefaults.set(Date(), forKey: "last_update")
            }
            userDefaults.synchronize()
            logger("[PostListParser] 成功同步 \(exportPosts.count) 条帖子至 Widget App Groups (分类: \(typeKey))")
        } catch {
            logger("[PostListParser] 同步 Widget 数据失败: \(error)")
        }
    }
    
    private func triggerWidgetRefresh() {
        // 触发Widget刷新
        WidgetCenter.shared.reloadAllTimelines()
        logger("[PostListParser] 触发Widget刷新")
    }
        
    var justNodes: [Node] {
        let allNodes: [Node] = nodes.flatMap { $0.nodes }
        return allNodes
    }
    
    var hadNodeItemData: Bool {
        return self.hotNodes.count > 0 || self.justNodes.count > 0
    }
    
    /// 绑定数据
    func updateSendNode(_ selectedTopic: Node) -> [Node] {
        if onlyHotNodes.count > 0 {
            let isExist = onlyHotNodes.contains(selectedTopic)
            if !isExist {
                onlyHotNodes = justNodes
            }
        } else {
            if justNodes.count > 0 {
                onlyHotNodes = justNodes
            }
        }
        
        return onlyHotNodes
    }
            
    // MARK: - 加载我的数据
    
    func loadMyTopicRefresh(type: MyTopicEnum) {
        currentPage = 1
        hasMore   = true
        isLoading = false
        loadMyTopic(type: type)
    }

    func loadMyTopic(type: MyTopicEnum) {
        hasMore   = true
        isLoading = false
        loadNodeInfo(type.rawValue)
    }
    
    // MARK: - 刷新主题列表
    
    func refreshPostList(type: PostListType) {
        currentPage = 1
        hasMore   = true
        isLoading = false
        loadMorePosts(type: type)
    }
    
    // MARK: - 刷新节点详情
    
    func loadNodeInfoLastst(_ url: String) {
        rowEnum = .nodeInfo
        currentPage = 1
        hasMore   = true
        isLoading = false
        loadNodeInfo(url)
    }
    
    func followNodeInfoAction(_ nodeLink: String?) async -> (Bool, String) {
        if !LoginStateChecker.isLogin {
            LoginStateChecker.LoginStateHandle()
            return (false, "")
        }
        
        guard let nodeLink else {
            return (false, "")
        }
        
        do {
            let html = try await NetworkManager.shared.get(nodeLink)
            runInMain {
                self.isFollowedNodeInfo.toggle()
                if self.isFollowedNodeInfo  == true {
                    self.nodeInfo?.title = "取消关注"
                } else {
                    self.nodeInfo?.title = "关注主题"
                }
                ToastView.successToast(self.isFollowedNodeInfo ? "主题关注成功": "取消关注主题成功")
            }
            return (true, html)
        } catch {
            logger("请求失败: \(error.localizedDescription)")
        }
        return (false, "")
    }

    // MARK: - 加载节点详情 加载更多
    
    func loadNodeInfo(_ url: String) {
        guard !isLoading, hasMore else { return }
        isLoading = true
        let zhong = url
        let page  = currentPage > 1 ? "?p=\(currentPage)" : ""
        let urlString = APIService.baseUrlString + zhong + page
        guard let url = URL(string: urlString) else {
           error = "Invalid URL"
           isLoading = false
           return
        }
        loadWithUrl(url)
    }
        
    // MARK: - 加载主题列表 加载更多

    func loadMorePosts(type: PostListType) {
        currentType = type
        guard !isLoading, hasMore, type == currentType else { return }
        isLoading = true
        let zhong = type.url
        var page  = ""
        if currentPage > 1 {
            if zhong.contains("?") {
                page = "&p=\(currentPage)"
            } else {
                page = "?p=\(currentPage)"
            }
        }
        let urlString = APIService.baseUrlString + zhong + page
        urlHeader = zhong
        url = urlString
        guard let url = URL(string: urlString) else {
           error = "Invalid URL"
           isLoading = false
           return
        }
        loadWithUrl(url)
   }
    
    private func loadWithUrl(_ url: URL) {
        logger("url \(url) \(currentPage)")
        Task {
            do {
                let html = try await NetworkManager.shared.get(url.absoluteString)
                
                await MainActor.run {
                    
                    defer {
                        self.isLoading = false
                    }
                    
                    do {
                        if self.currentPage == 1 {
                            self.posts.removeAll()
                            self.hotTodayTopic.removeAll()
                            self.hotNodes.removeAll()
                            self.nodes.removeAll()
                        }
                        let doc = try SwiftSoup.parse(html)
                        
                        let _ = try LoginStateChecker.shared.htmlCheckUserState(doc: doc)
                        
                        let newPosts  = try self.parseTopics(doc: doc)
                   if self.navItems.count <= 0 {
                       self.navItems = try self.parseNavbar(doc: doc)
                   }
                   
                   let nodeList = try self.parseNodes(doc: doc)
                   self.nodes.append(contentsOf: nodeList)
                   
                   let hots = try self.hotTodayTopic(doc: doc)
                   self.hotTodayTopic.append(contentsOf: hots)
                   
                   try self.parseNotification(doc: doc)
                   try self.parsePagination(doc: doc)
                   //logger("hotTodayTopic \(self.hotTodayTopic)")
                   self.currentPage += 1
                   self.posts.append(contentsOf: newPosts)
                   self.hasMore = self.currentPage <= self.totalPages
                   
                   // 更新Widget数据
                   if self.currentPage == 2 { // 第一页加载完成时更新Widget
                       self.updateWidgetData()
                   }
                   
                   //logger("page \(self.currentPage) totalPage \(self.totalPages) has \(self.hasMore) \(newPosts.count) \(self.posts.count)")
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

private extension PostListParser {
    func parseNotification(doc: SwiftSoup.Document) throws {
        let notificationLinks = try doc.select("a[href*='notifications']")
        if !notificationLinks.isEmpty() {
            let titleText = try notificationLinks.first()?.attr("title") ?? ""
            //logger("完整的提醒文本: \(titleText)")
            let pattern = "\\d+"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let results = regex.matches(in: titleText, options: [], range: NSRange(titleText.startIndex..., in: titleText))
                if let match = results.first {
                    let numberString = (titleText as NSString).substring(with: match.range)
                    self.notificationLinksCount = Int(numberString) ?? 0
                    NotificationManager.shared.unreadCount = self.notificationLinksCount
                    updateAppBadge(NotificationManager.shared.unreadCount)
                    logger("解析出的未读通知数量: \(numberString)")
                } else {
                    //logger("未找到数字")
                }
            }
            // 检查是否包含未读消息
            if try !doc.select(".mail-status.unread").isEmpty() {
                logger("存在未读通知")
            } else {
                self.notificationLinksCount = 0
                NotificationManager.shared.unreadCount = 0
                updateAppBadge(0)
                logger("没有未读通知")
            }
        } else {
            NotificationManager.shared.unreadCount = 0
            updateAppBadge(0)
            logger("未找到通知链接")
        }
    }
        
    // 解析导航栏
    func parseNavbar(doc: SwiftSoup.Document) throws -> [NavItem] {
        let navItems = try doc.select("#navbar5 ul.nav.navbar-nav.navbar-left li")
        return try navItems.map { element in
            let link     = try element.select("a").first()
            //let isActive = try element.hasClass("active")
            //logger("parseNavbar \(link) \(navItems)")
            return NavItem(
                title: try link?.text() ?? "",
                link: try link?.attr("href") ?? ""
                //isActive: isActive
            )
        }
    }
    
    /// 节点信息
    func parseNodes(doc: SwiftSoup.Document) throws -> [NodeItem] {

        var statusList: [CommunityStatus] = []

        let containerStatus = try doc.select("div.sidebox.container-box.mt10.community-status.hidden-xs").first()
            let items = try containerStatus?.select("dl").array()
            for item in items ?? [] {
                let title = try item.select("dt").text()
                let value = try item.select("dd").text()
                let status = CommunityStatus(title: title, value: value)
                statusList.append(status)
         }
        self.communityStatusList = statusList
        
        var nodeItems: [NodeItem] = []
        var allNodes: [Node] = []
        var hotNodes: [NodeItem] = []
        
        let container = try doc.select("div.sidebox.container-box.mt10.hot-nodes").first()
           let links = try container?.select("a").array()
           let category = try container?.select("span.title").text() ?? ""
           var nodes: [Node] = []
           for link in links ?? [] {
               let title = try link.text()
               let url = try link.attr("href")
               let node = Node(title: title, link: url)
               nodes.append(node)
           }
          hotNodes.append(NodeItem(category: category, nodes: nodes))
          self.onlyHotNodes = nodes
          self.hotNodes = hotNodes
         //logger("sendNode onlyHotNodes \(self.onlyHotNodes.count)  hotNodes \(hotNodes.count)" )
          if let nodesCloud = try doc.select("div.nodes-cloud").first() {
            let listItems = try nodesCloud.select("ul > li")
            for item in listItems {
                var nodes: [Node] = []
                let category = try item.select("label").text()
                let links = try item.select("a")
                for link in links {
                    let nodeName = try link.text()
                    let nodeHref = try link.attr("href")
                    let node = Node( title: nodeName, link: nodeHref)
                    nodes.append(node)
                    allNodes.append(node)
                }
                nodeItems.append(NodeItem(category: category, nodes: nodes))
            }
            onlyNodes = allNodes
        } else {
            if !LoginStateChecker.isLogin {
                NotificationCenter.default.post(name: .loginViewAlertNoti, object: nil)
            }
            //logger("未找到节点导航部分")
        }
        return nodeItems
    }
    
    
    
    // 解析帖子列表
    func parseTopics(doc: SwiftSoup.Document) throws -> [PostItem] {
        let topics = try doc.select("div.topic-item")
        
        if self.nodeInfo == nil {
            let createTopicLink = try doc.select("a.btn.btn-default").attr("href")
            _ = try doc.select("a.btn.btn-default").text()
            // 解析板块名称
            let boardName = try doc.select("span.bread-nav").text()
            // 解析关注按钮
            let followElement = try doc.select("span.label-success a, .gzk-profile-follow a, a[href^='/f/']").first()
            let followLink = try followElement?.attr("href") ?? ""
            let followText = try followElement?.text() ?? (try doc.select("span.label-success, .gzk-profile-follow").text())
            // 解析板块简介
            let description = try doc.select("span.f14").text()
            self.nodeInfo = NodeInfo(title: boardName, link: urlHeader ?? "", followText: followText, followLink: followLink, description: description, creatLink: createTopicLink)
            //logger("创建主题按钮: \(createTopicText) (\(createTopicLink))")
            //logger("板块名称: \(boardName) \(urlHeader ?? "")")
            //logger("关注链接: \(followText) (\(followLink))")
            //logger("板块简介: \(description)")
        }
        
        return try topics.map { element in
            // 准确提取纯用户名，多重兜底保证必定能获取到正确的用户ID
            var authorName = try element.select("span.username a[href^='/u/'] strong").first()?.text() ?? ""
            if authorName.isEmpty {
                authorName = try element.select("span.username a[href^='/u/']").first()?.text() ?? ""
            }
            if authorName.isEmpty {
                authorName = try element.select("span.username a").first()?.text() ?? ""
            }
            if authorName.isEmpty {
                // 从头像包装链接 <a href="/u/username"><img class="avatar"></a> 提取真实用户ID
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
                postType: try element.select("i.icon-bookmark-empty").last() == nil ? .none: .elite,
                bookmark: try element.select("h3.title a i").first()?.attr("title") ?? "",
                isOnline: isOnline,
                level: level,
                displayName: displayName
            )
        }
    }
    
    // 今日最热
    func hotTodayTopic(doc: SwiftSoup.Document) throws -> [HotTodayTopic] {
        var topicElements = try doc.select("div.hot-topics div.cell")
        if topicElements.isEmpty {
            topicElements = try doc.select("div.cell:has(span.hot_topic_title)")
        }
        
        var results: [HotTodayTopic] = []
        for element in topicElements {
            guard let titleElem = try element.select("span.hot_topic_title a").first() else {
                continue
            }
            let title = try titleElem.text().trimmingCharacters(in: .whitespacesAndNewlines)
            let link = try titleElem.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !link.isEmpty else { continue }
            
            // 提取用户真实 ID（优先从头像链接提取 /u/ 后面的真实用户名/ID）
            var user = ""
            if let userHref = try element.select("a[href^='/u/'], a[href*='/u/']").first()?.attr("href") {
                let cleanHref = userHref.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                user = cleanHref.components(separatedBy: CharacterSet(charactersIn: "?#/")).first ?? ""
            }
            if user.isEmpty {
                if let textUser = try element.select("a[href^='/u/']").first()?.text() {
                    user = textUser.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            let avatar = try element.select("img.avatar").first()?.attr("src") ?? ""
            
            results.append(HotTodayTopic(
                title: title,
                link: link,
                user: user,
                avatar: avatar
            ))
        }
        return results
    }
    
    // 解析分页信息
    func parsePagination(doc: SwiftSoup.Document) throws {
        if let lastPage = try doc.select("ul.pagination li:nth-last-child(2) a").first() {
            totalPages = Int(try lastPage.text()) ?? 1
        }
    }
}
