//
//  ForumParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup
import Alamofire

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
    let isDetailInfo: Bool?
}

struct NavItem: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    let isActive: Bool
}

struct NodeItem: Identifiable {
    let id = UUID()
    let category: String
    /// 文字
    let title: String
    /// 比如 /nodes/job 找工作
    let link: String
}



// MARK: - 数据模型
class PostListParser: ObservableObject {
    @Published var navItems: [NavItem] = []
    @Published var posts: [PostItem] = []
    @Published var nodes: [NodeItem] = []
    @Published var currentPage = 1
    @Published var totalPages  = 1
    @Published var isLoading   = false
    @Published var error: String?
    @Published var hasMore = true
    @Published var needLogin = false
    private var currentType: PostListType?
    

    func refresh(type: PostListType) {
        currentPage = 1
        hasMore   = true
        isLoading = false
        loadPosts(type: type)
    }
    
    
    func loadPosts(type: PostListType) {
        currentType = type
        guard !isLoading, hasMore, type == currentType else { return }
        isLoading = true
        let zhong = type.url
        let page  = currentPage > 1 ? "/?p=\(currentPage)" : ""
        let urlString = APIService.baseUrlString + zhong + page
        log("[url] \(zhong) \(urlString)")
        guard let url = URL(string: urlString) else {
           error = "Invalid URL"
           isLoading = false
           return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
           DispatchQueue.main.async {
               guard let self = self else { return }
               
               defer {
                   self.isLoading = false
               }
               
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
                       self.posts = []
                   }
                   let doc = try SwiftSoup.parse(html)
                   // 检查登录状态
                   let loginChecker = LoginStateChecker.shared
                   guard try loginChecker.checkLoginState(doc: doc) else {
                       self.needLogin = true
                       self.error = loginChecker.error
                       return
                   }

                   let newPosts  = try self.parseTopics(doc: doc)
                   if self.navItems.count <= 0 {
                       self.navItems = try self.parseNavbar(doc: doc)
                   }
                   if self.nodes.count <= 0 {
                       self.nodes    =  try self.parseNodes(doc: doc)
                   }
                   try self.parsePagination(doc: doc)
                   // 累加数据
                   self.posts.append(contentsOf: newPosts)
                   self.currentPage += 1
                   self.hasMore = self.currentPage <= self.totalPages
                   
               } catch {
                   self.error = error.localizedDescription
               }
           }
        }.resume()
   }
        
    // 解析导航栏
    func parseNavbar(doc: Document) throws -> [NavItem] {
        let navItems = try doc.select("#navbar5 ul.nav.navbar-nav.navbar-left li")
        return try navItems.map { element in
            let link     = try element.select("a").first()
            let isActive = try element.hasClass("active")
            //log("parseNavbar \(link) \(navItems)")
            return NavItem(
                title: try link?.text() ?? "",
                link: try link?.attr("href") ?? "",
                isActive: isActive
            )
        }
    }
    
    func parseNodes(doc: Document) throws -> [NodeItem] {
        var nodeItems: [NodeItem] = []
        if let nodesCloud = try doc.select("div.nodes-cloud").first() {
            let listItems = try nodesCloud.select("ul > li")
            for item in listItems {
                let category = try item.select("label").text()
                let links = try item.select("a")
                for link in links {
                    let nodeName = try link.text()
                    let nodeHref = try link.attr("href")
                    nodeItems.append(NodeItem(category: category, title: nodeName, link: nodeHref))
                }
            }
        } else {
            log("未找到节点导航部分")
        }
        return nodeItems
    }
    
    // 解析帖子列表
    func parseTopics(doc: Document) throws -> [PostItem] {
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
                lastReplyUser: try element.select("span.last-reply-username a strong").first()?.text(), isDetailInfo: false
            )
        }
    }
    
    // 解析分页信息
    func parsePagination(doc: Document) throws {
        if let lastPage = try doc.select("ul.pagination li:nth-last-child(2) a").first() {
            totalPages = Int(try lastPage.text()) ?? 1
        }
    }
}



//    // 加载更多
//    func loadMoreIfNeeded(type: PostListType, post: PostItem) {
//       guard let lastPost = posts.last,
//             lastPost.id == post.id,
//             !isLoading,
//            hasMore else {
//           return
//       }
//        loadPosts(type: type, isRefresh: false)
//   }

/// 加载帖子列表
//    @MainActor
//    func loadPosts(type: PostListType, isRefresh: Bool = true) async {
//
//        currentType = type
//        guard !isLoading && hasMore else { return }
//        isLoading = true
//        let zhong = type.url
//        let page  = currentPage > 1 ? "/?p=\(currentPage)" : ""
//        let urlString = APIService.baseUrlString + zhong + page
//        log("[url] \(zhong) \(urlString)")
//        guard let _ = URL(string: urlString) else {
//           error = "Invalid URL"
//           isLoading = false
//           return
//        }
//
//        if isRefresh {
//            currentPage = 1
//            posts = []
//            hasMore = true
//        }
//
//        isLoading = true
//
//        do {
//        // 构建请求参数
//        var parameters: Parameters = [:]
//        if currentPage > 1 {
//            parameters["p"] = currentPage
//        }
//
//        // 发起请求
//        let html = try await NetworkManager.shared.get(
//            urlString,
//            parameters: parameters,
//            headers: [
//                "User-Agent": "Mozilla/5.0",
//                "Accept": "text/html,application/xhtml+xml,application/xml"
//            ]
//        )
//
//            if self.currentPage == 1 || isRefresh {
//                self.posts = []
//            }
//
//            // 解析HTML
//            let doc = try SwiftSoup.parse(html)
//            let newPosts  = try self.parseTopics(doc: doc)
//            self.navItems = try self.parseNavbar(doc: doc)
//            try self.parsePagination(doc: doc)
//
//            // 累加数据
//            self.posts.append(contentsOf: newPosts)
//            self.currentPage += 1
//            self.hasMore = self.currentPage <= self.totalPages
//            self.isLoading = false
//            self.error = nil
//
//        } catch {
//            await MainActor.run {
//                self.error = error.localizedDescription
//                self.isLoading = false
//            }
//        }
//    }
