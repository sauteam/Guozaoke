import Foundation
import SwiftSoup

struct SearchPostItem: Identifiable {
    var id = UUID()
    var title: String
    var link: String
    var description: String
    var displayUrl: String
}

struct SearchKeyword: Identifiable {
    var id = UUID()
    var keyword: String
    var date: Date
}

class SearchListParser: ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchList: [SearchPostItem] = []
    @Published var hasMorePages: Bool = false
    @Published var savedSearchKeywords: [SearchKeyword] = []

    private var currentPage: Int = 0
    private var totalPages: Int = 0
    private var currentQuery: String = ""

    func searchText(_ text: String?) {
        guard let text = text else {
            return
        }
        currentPage = 0
        currentQuery = text
        saveSearchKeyword(text) // Save the search keyword
        search(page: currentPage)
    }

    func loadNews() {
        guard !isLoading, hasMorePages else {
            return
        }
        currentPage = 0
        search(page: currentPage)
    }

    func loadMore() {
        guard !isLoading, hasMorePages else {
            return
        }
        currentPage += 1
        search(page: currentPage)
    }

    private func search(page: Int) {
        let webPage = page * 10 + 1
        let searchUrl = "https://www.bing.com/search?q=site:guozaoke.com/t%20\(currentQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&mkt=zh-CN&first=\(webPage)"
        
        guard let url = URL(string: searchUrl) else {
            return
        }
        
        log("search \(url)")

        isLoading = true
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
            guard let data = data, error == nil,
                  let htmlString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.errorMessage = "请求失败: \(error?.localizedDescription ?? "未知错误")"
                }
                return
            }
            do {
                let document = try SwiftSoup.parse(htmlString)
                let newPosts = try self.parseTopics(doc: document)
                DispatchQueue.main.async {
                    if page == 0 {
                        self.searchList = newPosts
                    } else {
                        self.searchList.append(contentsOf: newPosts)
                    }
                    self.hasMorePages = page < self.totalPages
                }
                print("searchList \(self.searchList.count) webPage \(webPage) page \(page) totalPages \(totalPages)")
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "解析失败: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }
    
    private func parseTopics(doc: Document) throws -> [SearchPostItem] {
        let topics = try doc.select("li.b_algo")
        let postItems: [SearchPostItem]  = try topics.compactMap { element in
            let linkUrl = try element.select("h2 a").attr("href")
            let title   = try element.select("h2 a").text()
            let content = try element.select("p").text()
            let validTopic = title.count > 0 && title != content
            guard validTopic else { return nil }
            guard linkUrl.contains(APIService.baseUrlString) else { return nil }
            return SearchPostItem(
                title: title,
                link: linkUrl,
                description: content,
                displayUrl: try element.select("cite").text()
            )
        }

        if let lastPageLink = try doc.select("a.sb_pagN").last() {
            if let href = try? lastPageLink.attr("href"),
               let match = href.range(of: "first=(\\d+)", options: .regularExpression) {
                let pageStr = href[match]
                if let pageNum = Int(pageStr.replacingOccurrences(of: "first=", with: "")) {
                    self.totalPages = pageNum / 10
                }
            }
        }

        return postItems
    }
    
    private func saveSearchKeyword(_ keyword: String) {
        let now = Date()
        if let index = savedSearchKeywords.firstIndex(where: { $0.keyword.lowercased() == keyword.lowercased() }) {
            savedSearchKeywords[index].date = now
        } else {
            savedSearchKeywords.append(SearchKeyword(keyword: keyword, date: now))
        }
        savedSearchKeywords.sort(by: { $0.date > $1.date })
    }
    
    private func log(_ message: String) {
        print(message)
    }
}
