//
//  PostDetailParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup
import Alamofire

// MARK: - 帖子详情模型
struct PostDetail: Identifiable, Sendable {
    let id : String
    let title: String
    var detailId: String?
    var node: String
    let nodeUrl: String
    let author: Author
    let content: String
    let contentHtml: String
    let images: [PostImage]
    let links: [PostLink]
    let publishTime: String
    /// 点击数量
    let hits: String
    /// 点赞
    var zans: Int {
        didSet {
            if zans < 0 {
                zans = 0
            }
        }
    }
    /// 收藏数量
    var collections: Int {
        didSet {
            if collections < 0 {
                collections = 0
            }
        }
    }
    let zanLink: String
    var collectionsLink: String
    //let shareWeiboLink: String
    let replies: [Reply]
    /// 感谢已表示 或感谢
    var zanString: String
    /// 取消收藏 加入收藏
    var collectionString: String
}

struct Author: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let nameUrl:String
    let avatar: String
    let node: String
    let nodeUrl: String
    let joinDate: String?
    var level: String? = nil
    var isOnline: Bool = false
    var displayName: String? = nil
}

struct ReplyAuthor: Identifiable, Equatable, Sendable {
    let id = UUID()
    let name: String
    let avatar: String
    let replyTime: String?
    let floor: String?
    let replyTo: String?
    var level: String? = nil
    var isOnline: Bool = false
    var displayName: String? = nil
}


struct PostImage: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: String
    let alt: String
    let width: Int
    let height: Int
}

struct PostLink: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: String
    let text: String
    let isExternal: Bool
}

struct Reply: Identifiable, Equatable, Sendable {
    let id = UUID()
    let floor: String
    let author: ReplyAuthor
    let content: String
    let images: [PostImage]
    let links: [PostLink]
    let time: String
    let location: String
    var like: Int
    var isLiked: Bool = false
    let likeLink: String
    
    var floorNumber: Int {
        let digits = floor.filter { $0.isNumber }
        return Int(digits) ?? 0
    }
}

/// 相关主题
struct RelatedTopics: Identifiable, Sendable {
    let id = UUID()
    let username: String
    let avatar: String
    let userLink: String
    let topicTitle: String
    let topicLink: String
    
    var tid: String? {
        var link = topicLink
        let firstItem = topicLink.split(separator: "#").first ?? ""
        link = String(firstItem)
        //link = String(firstItem.replacing("/t/", with: ""))
        return link
    }
}

// MARK: - 帖子详情内存高速缓存（实现 0 毫秒秒开体验）
final class PostDetailMemoryCache: @unchecked Sendable {
    struct CachedTopic: Sendable {
        let detail: PostDetail
        let replies: [Reply]
        let relatedTopics: [RelatedTopics]
        let totalPages: Int
        let hasMore: Bool
        let isZan: Bool
        let isCollection: Bool
        let resolvedPostId: String?
    }
    
    static let shared = PostDetailMemoryCache()
    private var cache: [String: (data: CachedTopic, timestamp: Date)] = [:]
    private let lock = NSLock()
    private let maxCount = 20
    
    private func normalizeKey(_ key: String) -> String {
        return key.components(separatedBy: "#").first?.replacingOccurrences(of: "/t/", with: "").components(separatedBy: "?").first ?? key
    }
    
    func get(id: String) -> CachedTopic? {
        lock.lock()
        defer { lock.unlock() }
        let key = normalizeKey(id)
        guard let item = cache[key] else { return nil }
        // 缓存 10 分钟有效
        if Date().timeIntervalSince(item.timestamp) > 600 {
            cache.removeValue(forKey: key)
            return nil
        }
        return item.data
    }
    
    func set(id: String, data: CachedTopic) {
        lock.lock()
        defer { lock.unlock() }
        let key = normalizeKey(id)
        guard !key.isEmpty else { return }
        if cache.count >= maxCount {
            cache.removeAll()
        }
        cache[key] = (data, Date())
    }
}

enum ParseError: Error {
    case noContent
    case invalidData
}


// MARK: - 帖子详情解析器
class PostDetailParser: ObservableObject {
    @Published var postDetail: PostDetail?
    @Published var replies: [Reply] = []
    /// 相关主题
    @Published var relatedTopics: [RelatedTopics] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var needLogin = false
    @Published var hasMore = true
    @Published var currentPage = 1
    @Published var totalPages  = 1
    @Published var activeCommentPage = 1
    @Published var isJumpingPage = false
    @Published var postId: String?
    
    @Published var isCollection = false
    @Published var isZan  = false
//    @Published var replyZan  = 0
//    @Published var replyZanNumber  = 0

    var zanText: String {
        return isZan ? "已感谢":"感谢"
    }
    
    
    var zanColHit: String {
        var text = postDetail?.hits ?? "0 点击"
        let zan = postDetail?.zans ?? 0
        text = "\(zan) 人点赞" + dotText + text
        let col = postDetail?.collections ?? 0
        text = "\(col) 人收藏" + dotText + text
        return text
    }
    
//    var colIcon: Image {
//        return isCollection ? SFSymbol.heartSlashFill.body : SFSymbol.heartFill.body
//    }
    
    var estimatedPageSize: Int {
        if let first = replies.first?.floorNumber, let last = replies.last?.floorNumber, last > first {
            let diff = last - first + 1
            if diff >= 20 {
                return diff
            }
        }
        if replies.count >= 20 {
            return replies.count
        }
        return 100 // 官方默认每页 100 条回复
    }
    
    func loadMore() {
        if !self.hasMore {
            return
        }
        loadPostDetail(id: postId ?? "0")
    }
    
    func loadNews(postId: String) {
        currentPage = 1
        activeCommentPage = 1
        loadPostDetail(id: postId)
    }
    
    /// 跳转到指定评论页码并加载该页评论数据
    func jumpToPage(_ page: Int, postId: String, completion: (() -> Void)? = nil) {
        let targetPage = max(1, min(page, totalPages))
        let effectiveId = containsReplys(postId.isEmpty ? (self.postId ?? "") : postId)
        guard !effectiveId.isEmpty else { return }
        self.postId = effectiveId
        let urlString = effectiveId.postDetailUrl + "?p=\(targetPage)"
        guard let url = URL(string: urlString) else { return }
        
        isJumpingPage = true
        activeCommentPage = targetPage
        
        Task.detached(priority: .userInitiated) {
            do {
                let html = try await NetworkManager.shared.get(url.absoluteString)
                let doc = try SwiftSoup.parse(html)
                let _ = try LoginStateChecker.shared.htmlCheckUserState(doc: doc)
                let result = try Self.parseTopicPage(doc: doc, currentPostId: effectiveId)
                
                await MainActor.run {
                    guard self != nil else { return }
                    self.isJumpingPage = false
                    self.replies = result.replies
                    self.activeCommentPage = targetPage
                    self.currentPage = targetPage + 1
                    self.totalPages = result.totalPages
                    self.hasMore = self.currentPage <= self.totalPages
                    self.postDetail = result.detail
                    if let realId = result.resolvedPostId, !realId.isEmpty {
                        self.postId = realId
                    }
                    completion?()
                }
            } catch {
                await MainActor.run {
                    guard self != nil else { return }
                    self.isJumpingPage = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
    private func containsReplys(_ id: String) -> String {
        var url = id
        if url.contains("#") {
            if let result = url.components(separatedBy: "#").first {
                url = result
            }
        }
        if url.contains("?") {
            if let result = url.components(separatedBy: "?").first {
                url = result
            }
        }
        return url
    }
    private func loadPostDetail(id: String) {
        postId = containsReplys(id)
        let targetId = postId ?? id
        
        // 如果是第 1 页，且命中内存高速缓存，优先 0 毫秒即时渲染已有内容
        if currentPage == 1, let cached = PostDetailMemoryCache.shared.get(id: targetId) {
            self.postDetail = cached.detail
            self.replies = cached.replies
            self.relatedTopics = cached.relatedTopics
            self.totalPages = cached.totalPages
            self.hasMore = cached.hasMore
            self.isZan = cached.isZan
            self.isCollection = cached.isCollection
            self.activeCommentPage = 1
            if let realId = cached.resolvedPostId {
                self.postId = realId
            }
            logger("[DetailCache] 命中帖子详情内存缓存，秒开呈现: \(targetId)")
        }
        
        guard !isLoading || postId == "0" else { return }
        isLoading = (postDetail == nil)
        
        let isReplySearch = postId?.contains("/search/reply/") == true
        let footerUrl = isReplySearch ? "" : "?p=\(currentPage)"
        let urlString = (postId?.postDetailUrl ?? "") + footerUrl
        logger("详情开始刷新 \(postId ?? "1111") \(urlString)")

        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        let page = currentPage
        let currentTargetId = targetId
        
        Task.detached(priority: .userInitiated) {
            do {
                let html = try await NetworkManager.shared.get(url.absoluteString)
                let doc = try SwiftSoup.parse(html)
                let _ = try LoginStateChecker.shared.htmlCheckUserState(doc: doc)
                
                let result = try Self.parseTopicPage(doc: doc, currentPostId: currentTargetId)
                
                await MainActor.run {
                    guard self != nil else { return }
                    defer { self.isLoading = false }
                    
                    if let realId = result.resolvedPostId, !realId.isEmpty {
                        self.postId = realId
                    }
                    self.isZan = result.isZan
                    self.isCollection = result.isCollection
                    self.totalPages = result.totalPages
                    self.relatedTopics = result.relatedTopics
                    
                    if page == 1 {
                        self.replies = result.replies
                        self.activeCommentPage = 1
                    } else {
                        self.replies.append(contentsOf: result.replies)
                    }
                    self.currentPage = page + 1
                    self.postDetail = result.detail
                    self.hasMore = self.currentPage <= self.totalPages
                    
                    // 写入内存缓存供下次秒开
                    if page == 1 {
                        let cacheKey = self.postId ?? currentTargetId
                        let cacheItem = PostDetailMemoryCache.CachedTopic(
                            detail: result.detail,
                            replies: self.replies,
                            relatedTopics: self.relatedTopics,
                            totalPages: self.totalPages,
                            hasMore: self.hasMore,
                            isZan: self.isZan,
                            isCollection: self.isCollection,
                            resolvedPostId: self.postId
                        )
                        PostDetailMemoryCache.shared.set(id: cacheKey, data: cacheItem)
                    }
                    logger("currentPage \(self.currentPage) totalPages \(self.totalPages) \(self.hasMore)")
                }
            } catch {
                await MainActor.run {
                    guard self != nil else { return }
                    self.isLoading = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - 静态独立页面解析函数（运行在后台线程，彻底解放主线程）
    struct TopicPageParseResult: Sendable {
        let detail: PostDetail
        let replies: [Reply]
        let relatedTopics: [RelatedTopics]
        let totalPages: Int
        let isZan: Bool
        let isCollection: Bool
        let resolvedPostId: String?
    }
    
    private static func parseTopicPage(doc: SwiftSoup.Document, currentPostId: String?) throws -> TopicPageParseResult {
        // 1. 解析帖子基本信息
        let topicDetail = try doc.select("div.topic-detail").first()
        guard let topicDetail = topicDetail else { throw ParseError.noContent }
        
        // 2. 解析标题
        let title = try topicDetail.select("h3.title").text()
        
        // 3. 解析作者信息
        let authorBox = try topicDetail.select("div.ui-header").first()
        let node = try authorBox?.select("span.node").text() ?? ""
        let nodeUrl = try authorBox?.select("span.node a").attr(ghref) ?? ""
        
        var authorName = try authorBox?.select("span.username a[href^='/u/'] strong").first()?.text() ?? ""
        if authorName.isEmpty {
            if let userLink = try authorBox?.select("a[href^='/u/']").first()?.attr("href") {
                authorName = userLink.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if authorName.isEmpty {
            authorName = try authorBox?.select("span.username").text() ?? ""
        }
        if let range = authorName.range(of: "Lv.", options: .caseInsensitive) {
            authorName = String(authorName[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let level = try authorBox?.select(".gzk-credit-level").first()?.text()
        let isOnline = try !(authorBox?.select(".gzk-online").isEmpty ?? true)
        let displayName = try authorBox?.select(".gzk-visible-identity bdi").first()?.text()
        
        let author = Author(
            name: authorName,
            nameUrl: try authorBox?.select("a[href^='/u/']").first()?.attr(ghref) ?? "/u/\(authorName)",
            avatar: try authorBox?.select("img.avatar").attr(gsrc) ?? "",
            node: node,
            nodeUrl: nodeUrl,
            joinDate: try authorBox?.select("span.created-time").text() ?? "",
            level: level,
            isOnline: isOnline,
            displayName: displayName
        )
        
        // 4. 解析帖子元数据
        let metaBox = try topicDetail.select("div.topic-meta").first()
        let category = try metaBox?.select("a.node").text() ?? ""
        let publishTime = try metaBox?.select("span.created-time").text() ?? ""
        
        // 5. 解析帖子内容 纯文字
        let contentBox = try topicDetail.select("div.ui-content").first()
        let contentHtml = try contentBox?.html() ?? ""
        let topicContent = try contentBox?.select("div").text() ?? ""
        
        // 6. 解析帖子中的图片
        let images = try contentBox?.select("img").compactMap { img -> PostImage? in
            let src = try img.attr("src")
            if src.contains("static/images/emoji") {
                return nil
            }
            return PostImage(
                url: src,
                alt: try img.attr("alt"),
                width: 0,
                height: 0
            )
        } ?? []
        
        // 7. 解析帖子中的链接
        let links = try contentBox?.select("a").compactMap { link -> PostLink? in
            let href = try link.attr("href")
            return PostLink(
                url: href,
                text: try link.text(),
                isExternal: href.hasPrefix("http")
            )
        } ?? []
        
        var relatedTopics: [RelatedTopics] = []
        let cells = try doc.select("div.cell")
        for cell in cells {
            let username = try cell.select("td:nth-child(1) a").text()
            let avatarUrl = try cell.select("img.avatar").attr("src")
            let userLink = try cell.select("td:nth-child(1) a").attr("href")
            let topicLink = try cell.select("span.hot_topic_title a").attr("href")
            let topicTitle = try cell.select("span.hot_topic_title a").text()
            let relatedTopic = RelatedTopics(username: username, avatar: avatarUrl, userLink: userLink, topicTitle: topicTitle, topicLink: topicLink)
            relatedTopics.append(relatedTopic)
        }
        
        // 校准真实数字 postId
        var resolvedPostId: String? = nil
        if let canonical = try? doc.select("link[rel=canonical]").attr("href"),
           let candidate = canonical.components(separatedBy: "/t/").last?.components(separatedBy: "?").first?.components(separatedBy: "#").first,
           !candidate.isEmpty, candidate.allCharactersAreDigits {
            resolvedPostId = candidate
        }
        
        let effectivePostId = resolvedPostId ?? currentPostId
        
        // 8. 解析统计信息
        let hits = try (topicDetail.select("span.hits").first()?.text()) ?? (doc.select("span.hits").first()?.text()) ?? ""
        var zan = try doc.select(".gzk-topic-stats .up_vote, span.up_vote").first()?.text() ?? ""
        if zan.isEmpty {
            zan = try topicDetail.select("span.up_vote").text()
        }
        
        var collections = try doc.select(".gzk-topic-stats .favorited, span.favorited").first()?.text() ?? ""
        if collections.isEmpty {
            collections = try topicDetail.select("span.favorited").text()
        }
        
        var zanLinke = try topicDetail.select("a.J_topicVote").attr(ghref)
        if zanLinke.isEmpty || zanLinke == "javascript:;" || zanLinke == "#" {
            if let topicId = try? topicDetail.select("a.J_topicVote").attr("data-id"), !topicId.isEmpty {
                zanLinke = "/vote?topic_id=\(topicId)"
            } else if let topicId = try? topicDetail.select("a.J_topicVote").attr("data-topic-id"), !topicId.isEmpty {
                zanLinke = "/vote?topic_id=\(topicId)"
            } else if let id = effectivePostId, !id.isEmpty {
                let cleanId = id.components(separatedBy: "#").first?.replacingOccurrences(of: "/t/", with: "").components(separatedBy: "?").first ?? ""
                if !cleanId.isEmpty {
                    zanLinke = "/vote?topic_id=\(cleanId)"
                }
            }
        }
        
        let collectionsLink = try topicDetail.select("a.J_topicFavorite").attr(ghref)
        let topicVoteElem = try topicDetail.select("a.J_topicVote").first()
        var zanString = try topicVoteElem?.text() ?? ""
        let collectionString = try topicDetail.select("a.J_topicFavorite").text()
        let isCollection = (collectionString != "加入收藏" && !collectionString.isEmpty)
        
        let topicVotedAttr = try topicVoteElem?.attr("data-voted") ?? ""
        let ariaPressed = try topicVoteElem?.attr("aria-pressed") ?? ""
        let voteTitle = try topicVoteElem?.attr("title") ?? ""
        let isZan = (topicVotedAttr == "1" || ariaPressed == "true" || voteTitle == "取消点赞" || zanString.contains("已赞") || zanString.contains("感谢已表示"))
        if isZan {
            zanString = "已赞"
        } else {
            zanString = "赞"
        }
        
        var zanNumber = 0
        if let countAttr = try? topicVoteElem?.attr("data-count"), let cnt = Int(countAttr) {
            zanNumber = cnt
        } else {
            let zanDigits = zan.filter { $0.isNumber }
            zanNumber = Int(zanDigits) ?? 0
        }
        if isZan && zanNumber == 0 {
            zanNumber = 1
        }
        
        var colNumber = 0
        if let countAttr = try? topicDetail.select("a.J_topicFavorite").first()?.attr("data-count"), let cnt = Int(countAttr) {
            colNumber = cnt
        } else {
            let colDigits = collections.filter { $0.isNumber }
            colNumber = Int(colDigits) ?? 0
        }
        
        // 9. 解析回复列表与分页
        let replies = try parseReplies(doc: doc, node: category)
        let totalPages = try parsePagination(doc: doc)
        
        let detail = PostDetail(
            id: effectivePostId ?? "",
            title: title,
            detailId: effectivePostId,
            node: category,
            nodeUrl: nodeUrl,
            author: author,
            content: topicContent,
            contentHtml: contentHtml,
            images: images,
            links: links,
            publishTime: publishTime,
            hits: hits,
            zans: zanNumber,
            collections: colNumber,
            zanLink: zanLinke,
            collectionsLink: collectionsLink,
            replies: replies,
            zanString: zanString,
            collectionString: collectionString
        )
        
        return TopicPageParseResult(
            detail: detail,
            replies: replies,
            relatedTopics: relatedTopics,
            totalPages: totalPages,
            isZan: isZan,
            isCollection: isCollection,
            resolvedPostId: resolvedPostId
        )
    }
    
    private static func parseReplies(doc: SwiftSoup.Document, node: String) throws -> [Reply] {
        let replyItems = try doc.select("div.reply-item")
        return try replyItems.map { item -> Reply in
            var replyAuthorName = try item.select("a.reply-username span.username").first()?.text() ?? ""
            if replyAuthorName.isEmpty {
                replyAuthorName = try item.select("a.gzk-display-name").first()?.attr("data-username") ?? ""
            }
            if replyAuthorName.isEmpty {
                if let avatarHref = try item.select("a:has(img.avatar)").first()?.attr("href") {
                    replyAuthorName = avatarHref.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if replyAuthorName.isEmpty {
                replyAuthorName = try item.select(spanUsername).text()
            }
            if replyAuthorName.isEmpty {
                if let link = try item.select("a[href^='/u/']").first()?.attr("href") {
                    replyAuthorName = link.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if let range = replyAuthorName.range(of: "Lv.", options: .caseInsensitive) {
                replyAuthorName = String(replyAuthorName[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            replyAuthorName = replyAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let replyLevel = try item.select(".gzk-credit-level").first()?.text()
            let replyIsOnline = try !(item.select(".gzk-online").isEmpty)
            let replyDisplayName = try item.select("a.gzk-display-name bdi").first()?.text()
            
            let replyAuthor = ReplyAuthor(
                name: replyAuthorName,
                avatar: try item.select(imgAvatar).attr(gsrc),
                replyTime: try item.select(spanTime).text(),
                floor: try item.select("span.floor").first()?.text(),
                replyTo: try item.select(spanTime).text(),
                level: replyLevel,
                isOnline: replyIsOnline,
                displayName: replyDisplayName
            )
            
            // 2. 解析回复内容
            let contentBox = try item.select("span.content").first()
            let content = try contentBox?.text() ?? ""
            // 3. 解析回复中的图片
            let images = try contentBox?.select("img").compactMap { img -> PostImage? in
                let src = try img.attr("src")
                if src.contains("static/images/emoji") {
                    return nil
                }
                return PostImage(
                    url: src,
                    alt: try img.attr("alt"),
                    width: 0,
                    height: 0
                )
            } ?? []
            
            // 4. 解析回复中的链接
            let links = try contentBox?.select("a").compactMap { link -> PostLink? in
                let href = try link.attr("href")
                return PostLink(
                    url: href,
                    text: try link.text(),
                    isExternal: href.hasPrefix("http")
                )
            } ?? []
            
            // 5. 解析回复元数据
            let floor = try {
                let text = try item.select(".floor").first()?.text() ?? "0"
                return text
            }()
            
            let time = try item.select("span.time").text()
            let location = try item.select("span.location").text()
            
            let likeCount = try {
                let text = try item.select(".floor").last()?.text() ?? "0"
                return text
            }()
            let zanNumber = likeCount.replacingOccurrences(of: "赞 ", with: "").replacingOccurrences(of: "已赞 ", with: "")
            let replyZanNumber = Int(zanNumber) ?? 0
            let likeVoteElement = try item.select("a.J_replyVote").first()
            var likeLink = try likeVoteElement?.attr("href") ?? ""
            if likeLink.isEmpty || likeLink == "javascript:;" || likeLink == "#" {
                if let replyId = try? likeVoteElement?.attr("data-id"), !replyId.isEmpty {
                    likeLink = "/replyVote?reply_id=\(replyId)"
                } else if let replyId = try? likeVoteElement?.attr("data-reply-id"), !replyId.isEmpty {
                    likeLink = "/replyVote?reply_id=\(replyId)"
                }
            }
            let isVoted = try likeVoteElement?.attr("data-voted") == "1"
            return Reply(
                floor: floor,
                author: replyAuthor,
                content: content,
                images: images,
                links: links,
                time: time,
                location: location,
                like: replyZanNumber,
                isLiked: isVoted,
                likeLink: likeLink
            )
        }
    }
    
    // 解析分页信息
    private static func parsePagination(doc: SwiftSoup.Document) throws -> Int {
        let activePageElement = try doc.select("ul.pagination li.active a").first()
        let currentPage = Int(try activePageElement?.text() ?? "1") ?? 1
        
        let previousPageElement = try doc.select("ul.pagination li:has(a):contains(上一页)").first()
        let previousPageUrl = try previousPageElement?.select("a").attr("href")
        
        let nextPageElement = try doc.select("ul.pagination li:has(a):contains(下一页)").first()
        let nextPageUrl = try nextPageElement?.select("a").attr("href")
        
        let pageNumbers = try doc.select("ul.pagination li a").compactMap { element -> Int? in
            return Int(try element.text())
        }.max() ?? currentPage
        logger("[html]currentPage \(currentPage) previousPageUrl \(previousPageUrl ?? "1") nextPageUrl\(nextPageUrl ?? "") pageNumbers\(pageNumbers)")
        return pageNumbers
    }
    
    func fetchCollectionAction(link: String?, voted: Bool = true) async -> BaseResponse? {
        guard let link = link, !link.isEmpty else {
            return nil
        }
        
        do {
            let response: String
            let isVoteAction = link.contains("vote?topic_id") || link.contains("replyVote") || link.contains("/vote")
            
            if isVoteAction {
                // 点赞接口遵循官方 topic-votes-20261029.js 规范：必须为 POST，参数带 voted 与 _xsrf
                let token = AccountState.token()
                let parameters: [String: Any] = [
                    "voted": voted ? "1" : "0",
                    "_xsrf": token
                ]
                
                // 构造精准的 Referer（例如 https://www.guozaoke.com/t/134472）
                var referer = APIService.baseUrlString
                if let pid = self.postId ?? self.postDetail?.detailId, !pid.isEmpty {
                    let cleanId = pid.components(separatedBy: "#").first ?? pid
                    let path = cleanId.hasPrefix("/") ? cleanId : "/\(cleanId)"
                    referer = APIService.baseUrlString + path
                }
                
                let headers: HTTPHeaders = [
                    "Accept": "application/json, text/javascript, */*; q=0.01",
                    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                    "X-Requested-With": "XMLHttpRequest",
                    "Origin": APIService.baseUrlString,
                    "Referer": referer,
                    "X-Xsrftoken": token
                ]
                response = try await NetworkManager.shared.post(link, parameters: parameters, headers: headers)
            } else {
                let headers: HTTPHeaders = [
                    "Accept": "application/json",
                    "X-Requested-With": "XMLHttpRequest",
                    "Referer": APIService.baseUrlString
                ]
                response = try await NetworkManager.shared.get(link, headers: headers)
            }
            
            if let jsonData = response.data(using: .utf8) {
                do {
                    let model = try JSONDecoder().decode(BaseResponse.self, from: jsonData)
                    logger("jsonData \(jsonData) \(model)")
                    let message = model.message
                    if message == "user_not_login" {
                        runInMain {
                            LoginStateChecker.clearUserInfo()
                            ToastView.warningToast("请先登录再操作")
                        }
                        return model
                    }
                    runInMain {
                        var url = self.postDetail?.collectionsLink
                        let unfav = "/unfavorite"
                        let fav = "/favorite"
                        
                        if model.success == 1 {
                            if link.contains("favorite") {
                                self.isCollection.toggle()
                                logger("isCollection \(self.isCollection)")
                                if self.isCollection {
                                    self.postDetail?.collections += 1
                                    self.postDetail?.collectionString = "取消收藏"
                                    url = url?.replacingOccurrences(of: fav, with: unfav)
                                } else {
                                    self.postDetail?.collections -= 1
                                    self.postDetail?.collectionString = "加入收藏"
                                    url = url?.replacingOccurrences(of: unfav, with: fav)
                                }
                                self.postDetail?.collectionsLink = url ?? ""
                            } else if link.contains("vote?topic_id") {
                                if let isVoted = model.voted {
                                    self.isZan = isVoted
                                } else {
                                    self.isZan.toggle()
                                }
                                logger("isZan \(self.isZan)")
                                if let count = model.count {
                                    self.postDetail?.zans = count
                                } else if self.isZan {
                                    self.postDetail?.zans += 1
                                } else if !self.isZan && (self.postDetail?.zans ?? 0) > 0 {
                                    self.postDetail?.zans -= 1
                                }
                                self.postDetail?.zanString = self.isZan ? "已赞" : "赞"
                                ToastView.successToast(self.isZan ? "点赞成功" : "已取消点赞")
                            } else if link.contains("replyVote") {
                                // 楼层回复点赞状态在 PostDetailContent 中按楼层模型更新
                            }
                        } else {
                            if message == "already_voted" {
                                self.postDetail?.zanString = "已赞"
                                ToastView.successToast("已点赞")
                            } else if message == "can_not_vote_your_topic" {
                                ToastView.warningToast("不能点赞自己的主题哦")
                            } else if message == "can_not_vote_your_reply" {
                                ToastView.warningToast("不能点赞自己的回复")
                            } else if message == "already_favorited" {
                                ToastView.warningToast("已经收藏啦！")
                                self.postDetail?.collectionString = "取消收藏"
                                url = url?.replacingOccurrences(of: fav, with: unfav)
                                self.postDetail?.collectionsLink = url ?? ""
                            } else if message == "not_been_favorited" {
                                ToastView.warningToast("没有收藏唉！")
                                self.postDetail?.collectionString = "加入收藏"
                                url = url?.replacingOccurrences(of: unfav, with: fav)
                                self.postDetail?.collectionsLink = url ?? ""
                            } else if message == "can_not_favorite_your_topic" {
                                ToastView.warningToast("不能收藏自己的主题")
                            } else if let msg = message, !msg.isEmpty {
                                ToastView.warningToast(msg)
                            }
                        }
                    }
                    return model
                } catch {
                    logger("JSON 解析错误: \(error.localizedDescription)")
                }
            }
        } catch {
            logger("请求失败: \(error.localizedDescription)")
        }
        return nil
    }
}
