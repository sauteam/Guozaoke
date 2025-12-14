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
            logger("[request] \(url) allUrl \(allUrl)")
            guard let validURL = URL(string: allUrl) else {
                 continuation.resume(throwing: URLError(.badURL))
                 return
             }
     
            // 默认头部 - 使用iOS Safari User-Agent，并在后面添加应用标识
            var defaultHeaders: HTTPHeaders = [
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                "X-Requested-With": "XMLHttpRequest",
                "Content-Type": "text/html",
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 MyApp/1.0",
                "Cookie": APIService.getStoredCookies()
            ]

            if let headers = headers {
                headers.forEach { defaultHeaders.add($0) }
            }
            
            AF.request(
                validURL,
                method: method,
                parameters: parameters,
                headers: defaultHeaders
            )
            .validate()
            .responseString { response in
                switch response.result {
                case .success(let string):
                    //logger("[request][success]  \(parameters ?? [:]) \(headers ?? [:]) \(string) \(response)")
                    continuation.resume(returning: string)
                case .failure(let error):
                    logger("[request][error] \(parameters ?? [:]) \(headers ?? [:])  \(error) \(response)")
                    continuation.resume(throwing: error)
                    var desc = "出现错误❌: " + "[\(response.response?.statusCode ?? 0)[403-重新登录试试]]"
                    if !LoginStateChecker.isLogin {
                        desc = needLoginTextCanDo
                        LoginStateChecker.LoginStateHandle()
                    }
                    if error.responseCode == 403 {
                        logger("[403]重新登录处理  refreshTokenNoti \(url)")
                        NotificationCenter.default.post(name: .refreshTokenNoti, object: nil)
                    }
                    ToastView.warningToast(desc)
                }
            }
        }
    }    
    func post(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> String {
        try await request(url, method: .post, parameters: parameters, headers: headers)
    }
    
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
