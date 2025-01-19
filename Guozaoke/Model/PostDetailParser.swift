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
    let id = UUID()
    let title: String
    let node: String
    let nodeUrl: String
    let author: Author
    let content: String
    let images: [PostImage]
    let links: [PostLink]
    let publishTime: String
    /// 点击数量
    let hits: String
    /// 点赞
    let zans: String
    /// 收藏数量
    let collections: String
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
    //let floor: String?
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
    let like: String
}

enum ParseError: Error {
    case noContent
    case invalidData
}


// MARK: - 帖子详情解析器
class PostDetailParser: ObservableObject {
    @Published var postDetail: PostDetail?
    @Published var isLoading = false
    @Published var error: String?
    @Published var needLogin = false
    @Published var hasMore = true
    @Published var currentPage = 1
    @Published var totalPages  = 1
    @Published var postId: String?
    
    @Published var isCollection = false
    @Published var isZan  = false
    
    var favUrl: String {
        var url = postDetail?.collectionsLink
        let unfav = "/unfavorite"
        let fav = "/favorite"
        if isCollection {
            url = url?.replacingOccurrences(of: fav, with: unfav)
        } else {
            url = url?.replacingOccurrences(of: unfav, with: fav)
        }
        return url ?? postDetail?.collectionsLink ?? ""
    }
    
    var colText: String {
        let ttt = isCollection ? "取消收藏": "加入收藏"
        log("colText \(ttt)")
        return ttt
    }
    
    var zanText: String {
        return isZan ? "已感谢":"感谢"
    }
    
    func loadMore() {
        if !self.hasMore {
            return
        }
        currentPage += 1
        loadPostDetail(id: postId ?? "0")
    }

    func loadPostDetail(id: String) {
        guard !isLoading || id == "0"  else { return }
        isLoading = true
        log("详情开始刷新 \(id)")
        postId = id
        let urlString = id.postDetailUrl() + "?p=\(currentPage)"
        
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
                    if self.currentPage == 1 {
                        self.postDetail = nil
                    }
                    
                    let doc = try SwiftSoup.parse(html)
                    // 检查登录状态
                    let _ = try LoginStateChecker.shared.htmlCheckUserState(doc: doc)
                    
                    try self.parsePagination(doc: doc)

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
        
        // 5. 解析帖子内容
        let contentBox = try topicDetail.select("div.ui-content").first()
        var content = try contentBox?.select("div").text() ?? ""
        if content.isEmpty {
            content = title
        }
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
        
        // 8. 解析统计信息
        let hits = try topicDetail.select("span.hits").text()
        let zan = try topicDetail.select("span.up_vote").text()
        let collections = try topicDetail.select("span.favorited").text()
        let zanLinke = try topicDetail.select("a.J_topicVote").attr(ghref)
        let collectionsLink = try topicDetail.select("a.J_topicFavorite").attr(ghref)
        let zanString = try topicDetail.select("a.J_topicVote").text()
        let collectionString = try topicDetail.select("a.J_topicFavorite").text()
        //let shareLink = try topicDetail.select("a.J_topicFavorite").attr(ghref)
        if collectionString != "加入收藏" {
            isCollection = true
        }
        if zanString == "感谢已表示" {
            isZan = true
        }
        // 9. 解析回复列表
        let replies = try parseReplies(doc: doc, node: node)
        
        return PostDetail(
            title: title,
            node: category,
            nodeUrl: nodeUrl,
            author: author,
            content: content,
            images: images,
            links: links,
            publishTime: publishTime,
            hits: hits,
            zans: zan,
            collections: collections,
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
                replyTo: try item.select(spanTime).text()
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
            
            return Reply(
                floor: floor,
                author: replyAuthor,
                content: content,
                images: images,
                links: links,
                time: time,
                location: location,
                like: likeCount
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
        log("[html]currentPage \(currentPage) previousPageUrl \(previousPageUrl) nextPageUrl\(nextPageUrl) pageNumbers\(pageNumbers)")
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
                    if model.message == "user_not_login" {
                        runInMain {
                            LoginStateChecker.unLoginState()
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
