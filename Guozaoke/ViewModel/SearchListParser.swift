import Foundation
import SwiftUI
import SwiftSoup
import WebKit

/// WebView 加载获取
class SearchListParser: NSObject, ObservableObject {
    @Published var searchList: [SearchPostItem] = []
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var hasMoreData = true
    @Published var error: Error?
    
    private let targetDomain = "guozaoke.com/t"
    private var loadedUrls: Set<String> = []
    private var currentKeyword: String = ""
    private var totalPages: Int = 1
    
    private let userAgents = [
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ]
    
    func searchText(_ keyword: String) {
        currentKeyword = keyword
        currentPage = 1
        loadedUrls.removeAll()
        searchList.removeAll()
        hasMoreData = true
        performSearch(keyword)
    }
    
    func loadMore() {
        guard !isLoading, hasMoreData, currentPage < totalPages else { return }
        currentPage += 1
        performSearch(currentKeyword)
    }
    
    private func performSearch(_ keyword: String) {
        guard !isLoading else { return }
        isLoading = true
        
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let first = (currentPage - 1) * 10
        let urlString = "https://www.bing.com/search?q=site:\(targetDomain)%20\(encodedKeyword)&first=\(first)&mkt=zh-CN"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        logger("搜索URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // 更新请求头
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
        request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("none", forHTTPHeaderField: "Sec-Fetch-User")
        
        request.setValue("https://www.bing.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.bing.com/", forHTTPHeaderField: "Referer")
        
        let session = URLSession.shared
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    logger("网络请求错误: \(error)")
                    self?.error = error
                    self?.isLoading = false
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    logger("HTTP状态码: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                   logger("没有接收到数据")
                   self?.isLoading = false
                   return
                }
                       
               logger("接收到数据大小: \(data.count) bytes")
               
               let encodings: [String.Encoding] = [.utf8, .ascii, .isoLatin1, .windowsCP1252]
               var decodedHTML: String?
               
               for encoding in encodings {
                   if let html = String(data: data, encoding: encoding) {
                       decodedHTML = html
                       logger("成功使用编码: \(encoding)")
                       break
                   }
               }
               
               guard let html = decodedHTML else {
                   logger("所有编码方式都无法解码数据")
                   logger("原始数据前100字节: \(Array(data.prefix(100)))")
                   self?.isLoading = false
                   return
               }
               
               let containsResults = html.contains("b_results")
               let containsAlgo = html.contains("b_algo")
               logger("包含搜索结果容器: \(containsResults)")
               logger("包含搜索结果项: \(containsAlgo)")
               
               if html.contains("b_no") {
                   logger("没有找到搜索结果")
                   self?.searchList = []
                   self?.hasMoreData = false
                   self?.isLoading = false
                   return
               }
               
               if containsResults || containsAlgo {
                   self?.parseHTML(html)
               } else {
                   logger("HTML不包含预期的搜索结果结构")
#if DEBUG
                   if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                       let fileURL = documentsPath.appendingPathComponent("debug_response.html")
                       try? html.write(to: fileURL, atomically: true, encoding: .utf8)
                       logger("已保存响应HTML到: \(fileURL)")
                   }
#endif
                   self?.isLoading = false
               }
           }
       }.resume()
    }

    private func parseHTML(_ html: String) {
        do {
            let doc = try SwiftSoup.parse(html)
            
            let searchResults = try doc.select("#b_results .b_algo")
            var newItems: [SearchPostItem] = []
            
            for result in searchResults {
                do {
                    guard let link = try result.select("h2 > a").first(),
                          let url = try? link.attr("href"),
                          url.contains("guozaoke.com/t/"),
                          !loadedUrls.contains(url) else {
                        continue
                    }
                    
                    let title = try link.text()
                    
                    let description = try result.select(".b_caption p").first()?.text() ?? ""
                    
                    let meta = try result.select(".b_attribution").first()?.text() ?? ""
                    
                    loadedUrls.insert(url)
                    let item = SearchPostItem(
                        id: UUID(),
                        title: title,
                        url: url,
                        description: description,
                        meta: meta
                    )
                    newItems.append(item)
                    logger("找到结果: \(title)")
                } catch {
                    logger("解析单个结果时出错: \(error)")
                }
            }
            
            if currentPage == 1 {
                searchList = newItems
            } else {
                searchList.append(contentsOf: newItems)
            }
            
            if let countText = try doc.select(".sb_count").first()?.text(),
               let totalResults = Int(countText.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) {
                totalPages = Int(ceil(Double(totalResults) / 10.0))
                hasMoreData = currentPage < totalPages && !newItems.isEmpty
            } else {
                hasMoreData = false
            }
            
            logger("[search]成功解析 currentKeyword \(currentKeyword) \(newItems.count) 条结果")
            
        } catch {
            logger("解析错误: \(error)")
            self.error = error
        }
        isLoading = false
    }
}

struct SearchPostItem: Identifiable {
    let id: UUID
    let title: String
    let url: String
    let description: String
    let meta: String
}


// MARK: - 直接解析
/// 直接解析
//struct SearchPostItem: Identifiable {
//    var id = UUID()
//    var title: String
//    var url: String
//    var description: String
//    var displayUrl: String
//}
//
//struct SearchKeyword: Identifiable {
//    var id = UUID()
//    var keyword: String
//    var date: Date
//}
//
//class SearchListParser: ObservableObject {
//
//    @Published var isLoading = false
//    @Published var errorMessage: String?
//    @Published var searchList: [SearchPostItem] = []
//    @Published var hasMoreData: Bool = false
//    @Published var savedSearchKeywords: [SearchKeyword] = []
//
//    private var currentPage: Int = 0
//    private var totalPages: Int = 0
//    private var currentQuery: String = ""
//
//    func searchText(_ text: String?) {
//        guard let text = text else {
//            return
//        }
//        currentPage = 0
//        currentQuery = text
//        search(page: currentPage)
//    }
//
//    func loadNews() {
//        guard !isLoading, hasMoreData else {
//            return
//        }
//        currentPage = 0
//        search(page: currentPage)
//    }
//
//    func loadMore() {
//        guard !isLoading, hasMoreData else {
//            return
//        }
//        currentPage += 1
//        search(page: currentPage)
//    }
//
//    private func search(page: Int) {
//        let webPage = page * 10 + 1
//        let searchUrl = "https://www.bing.com/search?q=site:guozaoke.com/t%20\(currentQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&mkt=zh-CN&first=\(webPage)"
//
//        guard let url = URL(string: searchUrl) else {
//            return
//        }
//
//        logger("search \(url)")
//
//        isLoading = true
//        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
//            guard let self = self else { return }
//            defer {
//                DispatchQueue.main.async {
//                    self.isLoading = false
//                }
//            }
//            guard let data = data, error == nil,
//                  let htmlString = String(data: data, encoding: .utf8) else {
//                DispatchQueue.main.async {
//                    self.errorMessage = "请求失败: \(error?.localizedDescription ?? "未知错误")"
//                }
//                return
//            }
//            do {
//                let document = try SwiftSoup.parse(htmlString)
//                let newPosts = try self.parseTopics(doc: document)
//                DispatchQueue.main.async {
//                    if page == 0 {
//                        self.searchList = newPosts
//                    } else {
//                        self.searchList.append(contentsOf: newPosts)
//                    }
//                    self.hasMoreData = page < self.totalPages
//                }
//                logger("searchList \(self.searchList.count) webPage \(webPage) page \(page) totalPages \(totalPages)")
//            } catch {
//                DispatchQueue.main.async {
//                    self.errorMessage = "解析失败: \(error.localizedDescription)"
//                }
//            }
//        }
//        task.resume()
//    }
//
//    private func parseTopics(doc: Document) throws -> [SearchPostItem] {
//        let topics = try doc.select("li.b_algo")
//        let postItems: [SearchPostItem]  = try topics.compactMap { element in
//            let linkUrl = try element.select("h2 a").attr("href")
//            let title   = try element.select("h2 a").text()
//            let content = try element.select("p").text()
//            let validTopic = title.count > 0 && title != content
//            guard validTopic else { return nil }
//            guard linkUrl.contains(APIService.baseUrlString) else { return nil }
//            return SearchPostItem(
//                title: title,
//                url: linkUrl,
//                description: content,
//                displayUrl: try element.select("cite").text()
//            )
//        }
//
//        if let lastPageLink = try doc.select("a.sb_pagN").last() {
//            if let href = try? lastPageLink.attr("href"),
//               let match = href.range(of: "first=(\\d+)", options: .regularExpression) {
//                let pageStr = href[match]
//                if let pageNum = Int(pageStr.replacingOccurrences(of: "first=", with: "")) {
//                    self.totalPages = pageNum / 10
//                }
//            }
//        }
//
//        return postItems
//    }
//
//    private func saveSearchKeyword(_ keyword: String) {
//        let now = Date()
//        if let index = savedSearchKeywords.firstIndex(where: { $0.keyword.lowercased() == keyword.lowercased() }) {
//            savedSearchKeywords[index].date = now
//        } else {
//            savedSearchKeywords.append(SearchKeyword(keyword: keyword, date: now))
//        }
//        savedSearchKeywords.sort(by: { $0.date > $1.date })
//    }
//
//    private func logger(_ message: String) {
//        logger(message)
//    }
//}
