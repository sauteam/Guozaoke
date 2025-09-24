import Foundation
import SwiftSoup

// MARK: - Widget Post Parser
class WidgetPostParser {
    
    // MARK: - Debug Configuration
    static let isDebugEnabled = true
    
    // MARK: - Parse Posts from HTML using SwiftSoup
    static func parsePostsFromHTML(_ html: String) -> [PostWidgetItem] {
        do {
            let doc = try SwiftSoup.parse(html)
            return try parseTopics(doc: doc)
        } catch {
            if isDebugEnabled {
                logger("[Widget] SwiftSoup解析失败: \(error)")
            }
            return []
        }
    }
    
    // MARK: - Parse Topics (使用与主应用相同的解析逻辑)
    private static func parseTopics(doc: Document) throws -> [PostWidgetItem] {
        let topics = try doc.select("div.topic-item")
        logger("[Widget] 找到 \(topics.count) 个帖子元素")
        
        var posts: [PostWidgetItem] = []
        
        for (index, element) in topics.enumerated() {
            do {
                let title = try element.select("h3.title a").text()
                let link = try element.select("h3.title a").attr("href")
                let author = try element.select("span.username a").text()
                let node = try element.select("span.node a").text()
                let time = try element.select("span.last-touched").text()
                let replyCount = Int(try element.select("div.count a").text()) ?? 0
                
                if !title.isEmpty && !author.isEmpty {
                    let post = PostWidgetItem(
                        id: "\(index)",
                        title: title,
                        author: author,
                        timeAgo: time,
                        replyCount: replyCount,
                        node: node,
                        url: link
                    )
                    posts.append(post)
                    logger("[Widget] 解析帖子 \(index + 1): \(title) \(link) \(node)")
                }
            } catch {
                logger("[Widget] 解析第 \(index + 1) 个帖子失败: \(error)")
            }
            
            // 限制最多10条帖子
            if posts.count >= 10 {
                break
            }
        }
        
        logger("[Widget] SwiftSoup解析成功，获得 \(posts.count) 条帖子")
        return posts
    }
}

// MARK: - API Service for Widget
class WidgetAPIService {
    static let baseURL = "https://guozaoke.com"
    
    // MARK: - Unified API Request Method
    static func fetchPosts(for type: PostListType) async throws -> [PostWidgetItem] {
        let urlString = buildURL(for: type)
        
        if WidgetPostParser.isDebugEnabled {
            logger("[Widget] 开始获取\(type.rawValue)帖子，URL: \(urlString)")
        }
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WidgetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            if WidgetPostParser.isDebugEnabled {
                logger("[Widget] HTTP状态码: \(httpResponse.statusCode)")
            }
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            if WidgetPostParser.isDebugEnabled {
                logger("[Widget] 无法解码HTML数据")
            }
            throw NSError(domain: "WidgetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML"])
        }
        
        if WidgetPostParser.isDebugEnabled {
            logger("[Widget] HTML数据长度: \(html.count) 字符")
        }
        
        let posts = WidgetPostParser.parsePostsFromHTML(html)
        
        if WidgetPostParser.isDebugEnabled {
            logger("[Widget] \(type.rawValue)解析结果: \(posts.count) 条帖子")
        }
        
        return posts
    }
    
    // MARK: - URL Builder
    private static func buildURL(for type: PostListType) -> String {
        let path = type.url
        if path.isEmpty {
            return baseURL
        } else {
            return baseURL + path
        }
    }
    
    // MARK: - Legacy Methods (保持向后兼容)
    static func fetchLatestPosts() async throws -> [PostWidgetItem] {
        return try await fetchPosts(for: .latest)
    }
    
    static func fetchHotPosts() async throws -> [PostWidgetItem] {
        return try await fetchPosts(for: .hot)
    }
    
    static func fetchElitePosts() async throws -> [PostWidgetItem] {
        return try await fetchPosts(for: .elite)
    }
}
