//
//  NetworkManager.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI
import Alamofire
import SwiftSoup
import JDStatusBarNotification

// MARK: - 网络请求管理器
class NetworkManager: ObservableObject {
    
    struct BaseResponse: Codable {
        let message: String
        let success: Bool?
    }
    
    static let shared = NetworkManager()
    private init() {}
    
    // 基础请求方法
    func request(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var allUrl = url
            if !allUrl.hasPrefix(APIService.baseUrlString) {
                allUrl = APIService.baseUrlString + url
            }
            log("[request] \(url) allUrl \(allUrl)")
            guard let validURL = URL(string: allUrl) else {
                 continuation.resume(throwing: URLError(.badURL))
                 return
             }
     
            // 默认头部
            var defaultHeaders: HTTPHeaders = [
                "Accept": "application/json, text/javascript, text/html, application/xhtml+xml, application/xml",
                "X-Requested-With": "XMLHttpRequest",
                "Content-Type": "text/html",
                "Cookie": APIService.getStoredCookies()
            ]

            // 如果有传入 headers，则合并
            if let headers = headers {
                headers.forEach { defaultHeaders.add($0) }
            }
            
            AF.request(
                validURL,
                method: method,
                parameters: parameters,
                headers: headers
            )
            .validate()
            .responseString { response in
                switch response.result {
                case .success(let string):
                    //log("[request][success]  \(parameters ?? [:]) \(headers ?? [:]) \(string) \(response)")
                    continuation.resume(returning: string)
                case .failure(let error):
                    log("[request][error] \(parameters ?? [:]) \(headers ?? [:])  \(error) \(response)")
                    continuation.resume(throwing: error)
                    let desc = "出现错误❌: " + "[\(response.response?.statusCode ?? 0)[403 可能需要重新登]]"
                    if error.responseCode == 403 {
                        log("[403]重新登录处理 \(url)")
                        NotificationCenter.default.post(name: .refreshTokenNoti, object: nil)
                    }
                    NotificationPresenter.shared.present(desc, includedStyle: .dark, duration: toastDuration)
                }
            }
        }
    }    
    // POST请求
    func post(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> String {
        try await request(url, method: .post, parameters: parameters, headers: headers)
    }
    
    // GET请求
    func get(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> String {
        try await request(url, method: .get, parameters: parameters, headers: headers)
    }
}

// MARK: - 网络错误类型
enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .requestFailed(let message):
            return "请求失败: \(message)"
        case .invalidResponse:
            return "无效的响应"
        case .parseError:
            return "数据解析错误"
        }
    }
}



//// MARK: - 使用示例
//class PostListViewModel: ObservableObject {
//    @Published var posts: [Post] = []
//    @Published var isLoading = false
//    @Published var error: String?
//    @Published var currentPage = 1
//    @Published var hasMoreData = true
//    
//    // 加载帖子列表
//    func loadPosts(type: PostListType, isRefresh: Bool = true) async {
//        guard !isLoading else { return }
//        
//        if isRefresh {
//            currentPage = 1
//            posts = []
//            hasMoreData = true
//        }
//        
//        isLoading = true
//        
//        do {
//            // 构建请求参数
//            var parameters: Parameters = [:]
//            if currentPage > 1 {
//                parameters["p"] = currentPage
//            }
//            
//            // 发起请求
//            let html = try await NetworkManager.shared.get(
//                type.url,
//                parameters: parameters,
//                headers: [
//                    "User-Agent": "Mozilla/5.0",
//                    "Accept": "text/html,application/xhtml+xml,application/xml"
//                ]
//            )
//            
//            // 解析HTML
//            let newPosts = try parsePostList(html: html)
//            
//            await MainActor.run {
//                if isRefresh {
//                    self.posts = newPosts
//                } else {
//                    self.posts.append(contentsOf: newPosts)
//                }
//                
//                self.hasMoreData = !newPosts.isEmpty
//                self.currentPage += 1
//                self.isLoading = false
//                self.error = nil
//            }
//        } catch {
//            await MainActor.run {
//                self.error = error.localizedDescription
//                self.isLoading = false
//            }
//        }
//    }
//}

//func request<T: Codable>(
//    _ url: String,
//    method: HTTPMethod = .get,
//    parameters: Parameters? = nil,
//    headers: HTTPHeaders? = nil,
//    responseType: T.Type
//) async throws -> Result<T, String> {
//    return try await withCheckedThrowingContinuation { continuation in
//        var allUrl = url
//        if !allUrl.hasPrefix(APIService.baseUrlString) {
//            allUrl = APIService.baseUrlString + url
//        }
//        
//        guard let validURL = URL(string: allUrl) else {
//             continuation.resume(throwing: URLError(.badURL))
//             return
//         }
// 
//        // 默认头部
//        var defaultHeaders: HTTPHeaders = [
//            "Accept": "application/json, text/javascript, text/html, application/xhtml+xml,application/xml, */*; q=0.01",
//            "X-Requested-With": "XMLHttpRequest",
//            "Content-Type": "text/html"
//        ]
//
//        // 如果有传入 headers，则合并
//        if let headers = headers {
//            headers.forEach { defaultHeaders.add($0) }
//        }
//        
//        AF.request(
//            validURL,
//            method: method,
//            parameters: parameters,
//            headers: headers
//        )
//        .validate()
//        .responseString { response in
//            switch response.result {
//            case .success(let string):
//                guard let data = data else {
//                    continuation.resume(throwing: APIError(message: "InvalidResponse: No data received"))
//                        return
//                   }

//               // 检查 Content-Type
//               if let contentType = response.response?.mimeType {
//                   if contentType.contains("application/json") {
//                       do {
//                           if let responseType = responseType {
//                               let decoded = try JSONDecoder().decode(responseType, from: data)
//                               continuation.resume(returning: .success(decoded))
//                           } else {
//                               continuation.resume(returning: .success(nil))
//                           }
//                       } catch {
//                           continuation.resume(throwing: error)
//                       }
//                   } else if contentType.contains("text/html") || contentType.contains("text/plain") {
//                       if let htmlString = String(data: data, encoding: .utf8) {
//                           let documents = try SwiftSoup.parse(htmlString)
//                           continuation.resume(returning: .failure(documents))
//                       } else {
//                           continuation.resume(throwing: APIError(message: "Failed to decode HTML content"))
//                       }
//                   } else {
//                       continuation.resume(throwing: APIError(message: "Unsupported content type"))
//                   }
//               } else {
//                   continuation.resume(throwing: APIError(message: "Unsupported content type"))
//               }
//            case .failure(let error):
//                continuation.resume(throwing: error)
//            }
//        }
//    }
//}
//
///// GET 请求
//func get<T: Codable>(
//    _ url: String,
//    parameters: Parameters? = nil,
//    headers: HTTPHeaders? = nil,
//    responseType: T.Type
//) async throws -> T {
//    let result = try await request(url, method: .get, parameters: parameters, headers: headers, responseType: responseType)
//    switch result {
//    case .success(let data):
//        return data
//    case .failure(let errorMessage):
//        throw APIError(message: errorMessage)
//    }
//}
//
///// POST 请求
//func post<T: Codable>(
//    _ url: String,
//    parameters: Parameters? = nil,
//    headers: HTTPHeaders? = nil,
//    responseType: T.Type
//) async throws -> T {
//    let result = try await request(url, method: .post, parameters: parameters, headers: headers, responseType: responseType)
//    switch result {
//    case .success(let data):
//        return data
//    case .failure(let errorMessage):
//        throw APIError(message: errorMessage)
//    }
//}
