//
//  PostDetailParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup

// MARK: - 帖子详情模型
struct PostDetail: Identifiable {
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

struct Author: Identifiable {
    let id = UUID()
    let name: String
    let nameUrl:String
    let avatar: String
    let node: String
    let nodeUrl: String
    let joinDate: String?
}

struct ReplyAuthor: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let avatar: String
    let replyTime: String?
    let floor: String?
    let replyTo: String?
    //let like: String?
}


struct PostImage: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let alt: String
    let width: Int
    let height: Int
}

struct PostLink: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let text: String
    let isExternal: Bool
}

struct Reply: Identifiable, Equatable {
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
}

/// 相关主题
struct RelatedTopics: Identifiable {
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
    
    func loadMore() {
        if !self.hasMore {
            return
        }
        loadPostDetail(id: postId ?? "0")
    }
    
    func loadNews(postId: String) {
        currentPage = 1
        loadPostDetail(id: postId)
    }
    private func containsReplys(_ id: String) -> String {
        var url = id
        if url.contains("#reply") {
            if let result = url.components(separatedBy: "#").first {
                url  = result
            }
        }
        return url
    }
    private func loadPostDetail(id: String) {
        postId = containsReplys(id)
        
        guard !isLoading || postId == "0"  else { return }
        isLoading = true
        let footerUrl = "?p=\(currentPage)"
        let urlString = (postId?.postDetailUrl ?? "") + footerUrl
        log("详情开始刷新 \(postId ?? "1111") \(urlString)")

        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                defer { self.isLoading = false }
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let data = data,
                      let html = String(data: data, encoding: .utf8) else {
                    self.error = "无法解析数据"
                    return
                }
                
                do {
                    
                    let doc = try SwiftSoup.parse(html)
                    if self.currentPage == 1 || !self.hasMore {
                        self.postDetail = nil
                        self.replies.removeAll()
                    }
                    self.relatedTopics.removeAll()
                    // 检查登录状态
                    let _ = try LoginStateChecker.shared.htmlCheckUserState(doc: doc)
                    
                    try self.parsePagination(doc: doc)
                    self.currentPage += 1
                    self.postDetail = try self.parsePostDetail(doc: doc)
                    self.hasMore = self.currentPage <= self.totalPages
                    log("currentPage \(self.currentPage) totalPages \(self.totalPages) \(self.hasMore)")
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }.resume()
    }
    
    private func parsePostDetail(doc: Document) throws -> PostDetail {
        // 1. 解析帖子基本信息
        let topicDetail = try doc.select("div.topic-detail").first()
        guard let topicDetail = topicDetail else { throw ParseError.noContent }
        
        // 2. 解析标题
        let title = try topicDetail.select("h3.title").text()
        
        // 3. 解析作者信息
        let authorBox = try topicDetail.select("div.ui-header").first()
        let node = try authorBox?.select("span.node").text() ?? ""
        let nodeUrl = try authorBox?.select("span.node a").attr(ghref) ?? ""
        let author = Author(
            name: try authorBox?.select("span.username").text() ?? "",
            nameUrl: try authorBox?.select("span.username a").attr(ghref) ?? "",
            avatar: try authorBox?.select("img.avatar").attr(gsrc) ?? "",
            node: node,
            nodeUrl: nodeUrl,
            joinDate: try authorBox?.select("span.created-time").text() ?? ""
        )
        
        // 4. 解析帖子元数据
        let metaBox = try topicDetail.select("div.topic-meta").first()
        let category = try metaBox?.select("a.node").text() ?? ""
        let publishTime = try metaBox?.select("span.created-time").text() ?? ""
        
        // 5. 解析帖子内容 纯文字
        let contentBox = try topicDetail.select("div.ui-content").first()
        let contentHtml   = try contentBox?.html() ?? ""
        let topicContent  = try contentBox?.select("div").text() ?? ""
//        let result = TextChecker.checkText(content)
//        if result.hasEmail || result.hasTag || result.hasMention || result.hasLink {
//            topicContent = try contentBox?.html() ?? ""
//        } else {
//            topicContent = content
//        }
        log("[content] \(contentHtml)")
        
        // 6. 解析帖子中的图片
        let images = try contentBox?.select("img").compactMap { img -> PostImage? in
            let src = try img.attr("src")
            // 过滤表情图片
            if src.contains("static/images/emoji") {
                return nil
            }
            return PostImage(
                url: src,
                alt: try img.attr("alt"),
                width: 0,//try? Int(img.attr("width")) ?? 0,
                height: 0//try? Int(img.attr("height")) ?? 0
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
        
        
        let cells = try doc.select("div.cell")
        for cell in cells {
            let username = try cell.select("td:nth-child(1) a").text()
            let avatarUrl  = try cell.select("img.avatar").attr("src")
            let userLink = try cell.select("td:nth-child(1) a").attr("href")
            let topicLink  = try cell.select("span.hot_topic_title a").attr("href")
            let topicTitle = try cell.select("span.hot_topic_title a").text()
            let relatedTopic = RelatedTopics(username: username, avatar: avatarUrl, userLink: userLink, topicTitle: topicTitle, topicLink: topicLink)
            relatedTopics.append(relatedTopic)
        }
        
        // 8. 解析统计信息
        let hits = try topicDetail.select("span.hits").text()
        let zan = try topicDetail.select("span.up_vote").text()
        let collections = try topicDetail.select("span.favorited").text()
        let zanLinke = try topicDetail.select("a.J_topicVote").attr(ghref)
        let collectionsLink = try topicDetail.select("a.J_topicFavorite").attr(ghref)
        var zanString = try topicDetail.select("a.J_topicVote").text()
        let collectionString = try topicDetail.select("a.J_topicFavorite").text()
        //let shareLink = try topicDetail.select("a.J_topicFavorite").attr(ghref)
        if collectionString != "加入收藏" {
            isCollection = true
        }
        if zanString == "感谢已表示" {
            isZan = true
        } else {
            zanString = "感谢"
        }
        let zanNumber = Int(zan.split(separator: " ").first ?? "0") ?? 0
        let colNumber = Int(collections.split(separator: " ").first ?? "0") ?? 0
        // 9. 解析回复列表
        let replies = try parseReplies(doc: doc, node: node)
        //log("replies \(replies)")
        self.replies.append(contentsOf: replies)
        return PostDetail(
            id: postId ?? "",
            title: title,
            detailId: postId,
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
    }
    
    private func parseReplies(doc: Document, node: String) throws -> [Reply] {
        let replyItems = try doc.select("div.reply-item")
        return try replyItems.map { item -> Reply in
            // 1. 解析回复作者
            let replyAuthor = ReplyAuthor(
                name: try item.select(spanUsername).text(),
                avatar: try item.select(imgAvatar).attr(gsrc),
                replyTime: try item.select(spanTime).text(),
                floor: try item.select("span.floor").first()?.text(),
                replyTo: try item.select(spanTime).text()
            )
            
            // 2. 解析回复内容
            let contentBox = try item.select("span.content").first()
            //let content = try contentBox?.html() ?? ""
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
                    width: 0,//try? Int(img.attr("width")) ?? 0,
                    height: 0//try? Int(img.attr("height")) ?? 0
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
                //return Int(text.replacingOccurrences(of: "#", with: "")) ?? 0
            }()
            
            let time = try item.select("span.time").text()
            let location = try item.select("span.location").text()
            
            let likeCount = try {
                let text = try item.select(".floor").last()?.text() ?? "0"
                return text
            }()
            let zanNumber  = likeCount.replacingOccurrences(of: "赞 ", with: "")
            let replyZanNumber = Int(zanNumber) ?? 0
            let likeLink = try item.select("a.J_replyVote").first()?.attr("href")
            return Reply(
                floor: floor,
                author: replyAuthor,
                content: content,
                images: images,
                links: links,
                time: time,
                location: location,
                like: replyZanNumber,
                isLiked: false,
                likeLink: likeLink ?? ""
            )
        }
    }
    
    // 解析分页信息
    func parsePagination(doc: Document) throws {
        
        // 获取当前页码
        let activePageElement = try doc.select("ul.pagination li.active a").first()
        let currentPage = Int(try activePageElement?.text() ?? "1") ?? 1
        
        // 获取上一页链接
        let previousPageElement = try doc.select("ul.pagination li:has(a):contains(上一页)").first()
        let previousPageUrl = try previousPageElement?.select("a").attr("href")
        
        // 获取下一页链接
        let nextPageElement = try doc.select("ul.pagination li:has(a):contains(下一页)").first()
        let nextPageUrl = try nextPageElement?.select("a").attr("href")
        
        // 获取总页数
        let pageNumbers = try doc.select("ul.pagination li a").compactMap { element -> Int? in
            return Int(try element.text())
        }.max() ?? currentPage
        self.totalPages = pageNumbers
        log("[html]currentPage \(currentPage) previousPageUrl \(previousPageUrl ?? "1") nextPageUrl\(nextPageUrl ?? "") pageNumbers\(pageNumbers)")
//        if totalPages == 1 {
//            let mobilePaginationText = try doc.select("div.pagination-wap div").text()
//            if let range = mobilePaginationText.range(of: "/") {
//                let totalPageText = mobilePaginationText[range.upperBound...].trimmingCharacters(in: .whitespaces)
//                totalPages = Int(totalPageText) ?? currentPage
//            }
//        }
    }
    
    
    func fetchCollectionAction(link: String?) async -> BaseResponse? {
        guard let link else {
            return nil
        }
        
        do {
            let response = try await NetworkManager.shared.get(link)
            if let jsonData = response.data(using: .utf8) {
                do {
                    let model = try JSONDecoder().decode(BaseResponse.self, from: jsonData)
                    log("jsonData \(jsonData) \(model)")
                    let message = model.message
                    if message == "user_not_login" {
                        runInMain {
                            LoginStateChecker.clearUserInfo()
                        }
                    }
                    runInMain {
                        var url = self.postDetail?.collectionsLink
                        let unfav = "/unfavorite"
                        let fav = "/favorite"
                        
                        if model.success == 1 {
                            if link.contains("favorite") {
                                self.isCollection.toggle()
                                log("isCollection \(self.isCollection)")
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
                                self.isZan.toggle()
                                log("isZan \(self.isZan)")
                                if self.isZan {
                                    self.postDetail?.zans += 1
                                    self.postDetail?.zanString = "感谢已表示"
                                } else {
                                    self.postDetail?.zanString = "感谢"
                                }
                            } else if link.contains("replyVote") {
                                
                            }
                            
                            
                        } else {
                            if message == "already_voted" {
                                self.postDetail?.zanString = "感谢已表示"
                            } else if message == "can_not_vote_your_topic" {
                                ToastView.warningToast("不能感谢自己啊啊啊，o(╯□╰)o")
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
                                ToastView.warningToast("不能收藏自己的主题，我也不知道为何")
                            } else {
                                ToastView.warningToast(message ?? "")
                            }
                        }
                    }
                    return model
                } catch {
                    log("JSON 解析错误: \(error.localizedDescription)")
                }
            }
        } catch {
            log("请求失败: \(error.localizedDescription)")
            //response = "请求失败: \(error.localizedDescription)"
        }
        return nil
    }
}
