//
//  SearchListParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import Foundation
import SwiftUI
import SwiftSoup

struct SearchPostItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let url: String
    let description: String
    let meta: String
    var author: String = ""
    var node: String = ""
    var time: String = ""
    var hitType: String = ""
}

/// 过早客官方站内搜索解析器
@MainActor
class SearchListParser: ObservableObject {
    @Published var searchList: [SearchPostItem] = []
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var hasMoreData = false
    @Published var error: Error?
    @Published var statusText: String? = nil
    
    private var currentKeyword: String = ""
    private var loadedKeys: Set<String> = []
    
    func searchText(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchList.removeAll()
            hasMoreData = false
            currentKeyword = ""
            statusText = nil
            return
        }
        currentKeyword = trimmed
        currentPage = 1
        loadedKeys.removeAll()
        searchList.removeAll()
        hasMoreData = false
        statusText = nil
        performSearch(page: 1)
    }
    
    func loadMore() {
        guard !isLoading, hasMoreData else { return }
        performSearch(page: currentPage + 1)
    }
    
    private func performSearch(page: Int) {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        let keyword = currentKeyword
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlPath = "/search?q=\(encodedKeyword)&p=\(page)"
        
        logger("[Search] 开始过早客站内搜索: \(urlPath)")
        
        Task {
            do {
                let html = try await NetworkManager.shared.request(urlPath)
                let (newItems, hasNext, status) = self.parseSearchHTML(html)
                
                self.currentPage = page
                self.statusText = status
                if page == 1 {
                    self.searchList = newItems
                } else {
                    self.searchList.append(contentsOf: newItems)
                }
                self.hasMoreData = hasNext && !newItems.isEmpty
                self.isLoading = false
            } catch {
                logger("[Search] 站内搜索错误: \(error)")
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func parseSearchHTML(_ html: String) -> (items: [SearchPostItem], hasNext: Bool, status: String?) {
        do {
            let doc = try SwiftSoup.parse(html)
            let status = try? doc.select("p.search-status").first()?.text()
            let articles = try doc.select(".search-results article.result")
            var items: [SearchPostItem] = []
            
            for article in articles {
                guard let linkEl = try article.select("h2 > a").first(),
                      let href = try? linkEl.attr("href"), !href.isEmpty else {
                    continue
                }
                
                let title = try linkEl.text().trimmingCharacters(in: .whitespacesAndNewlines)
                let metaEl = try article.select(".meta").first()
                let metaText = try metaEl?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let excerpt = try article.select(".excerpt").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                let node = try metaEl?.select("a[href^=/node/]").first()?.text() ?? ""
                let author = try metaEl?.select("a[href^=/u/]").first()?.text() ?? ""
                
                let key = "\(href)_\(title)"
                if !loadedKeys.contains(key) {
                    loadedKeys.insert(key)
                    let item = SearchPostItem(
                        id: UUID(),
                        title: title,
                        url: href,
                        description: excerpt,
                        meta: metaText,
                        author: author,
                        node: node
                    )
                    items.append(item)
                }
            }
            
            let hasNext = try !doc.select(".search-pages a:contains(下一页)").isEmpty()
            return (items, hasNext, status)
        } catch {
            logger("[Search] 解析 HTML 失败: \(error)")
            return ([], false, nil)
        }
    }
}
