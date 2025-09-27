import Foundation
import SwiftSoup

// MARK: - Widget Post Parser
class WidgetPostParser {
    
    static let isDebugEnabled = true
    
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
    
    private static func parseTopics(doc: Document) throws -> [PostWidgetItem] {
        let topics = try doc.select("div.topic-item")
        logger("[Widget] 找到 \(topics.count) 个帖子元素")
        
//        if topics.isEmpty {
//            logger("[Widget] 调试：尝试其他选择器")
//            let alternativeSelectors = [
//                "div.topic",
//                "div.item", 
//                "div.post",
//                "div.topic-list div",
//                ".topic-item",
//                ".topic",
//                ".item",
//                "div[class*='topic']",
//                "div[class*='item']"
//            ]
//            
//            for selector in alternativeSelectors {
//                let elements = try doc.select(selector)
//                if !elements.isEmpty {
//                    let firstElement = elements.first()
//                    let html = try firstElement?.html() ?? ""
//                    logger("[Widget] 第一个元素HTML: \(String(html.prefix(300)))...")
//                }
//            }
//            
//            let title = try doc.select("title").text()
//            let bodyClasses = try doc.select("body").attr("class")
//            let containers = try doc.select("div[class*='container'], div[class*='content'], div[class*='main']")
//            logger("[Widget] 找到 \(containers.count) 个可能的容器")
//        }
        
        // 使用与主应用完全相同的解析逻辑
        return try topics.map { element in
            PostWidgetItem(
                id: UUID().uuidString,
                title: try element.select("h3.title a").text(),
                author: try element.select("span.username a").text(),
                timeAgo: try element.select("span.last-touched").text(),
                replyCount: Int(try element.select("div.count a").text()) ?? 0,
                node: try element.select("span.node a").text(),
                url: try element.select("h3.title a").attr("href")
            )
        }
    }
}

class WidgetAPIService {
    static let baseURL = "https://guozaoke.com"
    
    static func fetchPosts(for type: PostListType) async throws -> [PostWidgetItem] {
        let urlString = buildURL(for: type)
        
        if WidgetPostParser.isDebugEnabled {
            //logger("[Widget] 开始获取\(type.rawValue)帖子，URL: \(urlString)")
        }
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WidgetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        
        // 添加Cookie支持
        if let cookies = getStoredCookiesFromAppGroups(), !cookies.isEmpty {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
            if WidgetPostParser.isDebugEnabled {
                logger("[Widget] 使用Cookie: \(cookies)")
            }
        } else {
            if WidgetPostParser.isDebugEnabled {
                logger("[Widget] 未找到Cookie，可能需要登录")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
            //logger("[Widget] HTML数据长度: \(html.count) 字符 HTML预览: \(html)")
        }
        
        let posts = WidgetPostParser.parsePostsFromHTML(html)
        
        if WidgetPostParser.isDebugEnabled {
            logger("[Widget] \(type.rawValue)解析结果: \(posts.count) 条帖子")
        }
        
        return posts
    }
    
    private static func buildURL(for type: PostListType) -> String {
        let path = type.url
        if path.isEmpty {
            return baseURL
        } else {
            return baseURL + path
        }
    }
    
    static func fetchLatestPosts() async throws -> [PostWidgetItem] {
        return try await fetchPosts(for: .latest)
    }
    
    static func fetchHotPosts() async throws -> [PostWidgetItem] {
        return try await fetchPosts(for: .hot)
    }
    
    static func fetchElitePosts() async throws -> [PostWidgetItem] {
        return try await fetchPosts(for: .elite)
    }
    
    /// 从App Groups 读取存储的Cookie
    private static func getStoredCookiesFromAppGroups() -> String? {
        guard let userDefaults = UserDefaults(suiteName: guozaokeGroup) else {
            logger("[Widget] 无法访问App Groups")
            return nil
        }
        
        let cookies = userDefaults.string(forKey: "stored_cookies")
        if let cookies = cookies {
            logger("[Widget] 从App Groups读取到Cookie: \(cookies)")
        } else {
            logger("[Widget] App Groups中没有找到Cookie")
            //let allKeys = userDefaults.dictionaryRepresentation().keys
            //logger("[Widget] App Groups中的所有键: \(Array(allKeys))")
        }
        return cookies
    }
}
