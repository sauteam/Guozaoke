//
//  LoginService.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup

// MARK: - 错误定义
enum LoginError: LocalizedError {
    case invalidURL
    case invalidData
    case invalidResponse
    case loginFailed(message: String)
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidData:
            return "无效的数据"
        case .invalidResponse:
            return "无效的响应"
        case .loginFailed(let message):
            return message
        case .httpError(let statusCode):
            return "HTTP错误: \(statusCode)"
        }
    }
}

// MARK: - 登录服务
class LoginService: ObservableObject {
    @State var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?
    
    // XSRF Token
    private var xsrfToken: String = ""
    private let loginUrl = APIService.baseUrlString + "/login"
        
    func fetchLoginPage() async throws {
        guard let url = URL(string: loginUrl) else {
            throw LoginError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw LoginError.invalidData
        }
        
        let doc = try SwiftSoup.parse(html)
        // 解析XSRF Token
        if let tokenInput = try doc.select("input[name=_xsrf]").first() {
            xsrfToken = try tokenInput.attr("value")
        }
    }
    
//    // 执行登录请求
    func login(email: String, password: String) async throws {
        guard xsrfToken.isEmpty == false else {
            try await fetchLoginPage()
            return
        }
        
        isLoggedIn = true
        isLoading  = false
        
        guard let url = URL(string: loginUrl) else {
            throw LoginError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 构建请求参数
        let parameters: [String: String] = [
            "email": email,
            "password": password,
            "_xsrf": xsrfToken
        ]
        
        let bodyString = parameters.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }.joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoginError.invalidResponse
        }
        
        // 解析响应
        if httpResponse.statusCode == 200 {
            // 检查是否登录成功
            let doc = try SwiftSoup.parse(String(data: data, encoding: .utf8) ?? "")
            
            // 检查错误信息
            if let errorMessage = try doc.select("ul.alert-danger li").first()?.text() {
                throw LoginError.loginFailed(message: errorMessage)
            }
            if try doc.select("div.topic-item").count > 0 {
                let paramater = ["loginId": email, "token": xsrfToken]
                isLoggedIn    = true
                DispatchQueue.main.async { 
                    Persist.save(value: paramater, forkey: AccountState.ACCOUNT_KEY)
                }
            } else {
                throw LoginError.loginFailed(message: "登录失败")
            }
        } else {
            throw LoginError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
//    func login(email: String, password: String) {
//        isLoading = true
//        
//        Task {
//            do {
//                // 获取登录页面的XSRF Token
//                let loginPageHtml = try await NetworkManager.shared.request(
//                    "https://www.guozaoke.com/login",
//                    method: .get
//                )
//                
//                let doc = try SwiftSoup.parse(loginPageHtml)
//                let xsrfToken = try doc.select("input[name=_xsrf]").first()?.attr("value") ?? ""
//                
//                // 发起登录请求
//                let parameters: Parameters = [
//                    "email": email,
//                    "password": password,
//                    "_xsrf": xsrfToken
//                ]
//                
//                let headers: HTTPHeaders = [
//                    "Content-Type": "application/x-www-form-urlencoded",
//                    "User-Agent": "Mozilla/5.0",
//                    "Referer": "https://www.guozaoke.com/login"
//                ]
//                
//                let response = try await NetworkManager.shared.request(
//                    "https://www.guozaoke.com/login",
//                    method: .post,
//                    parameters: parameters,
//                    headers: headers
//                )
//                
//                await MainActor.run {
//                    self.isLoading = false
//                    // 处理登录响应
//                    if response.contains("登录失败") {
//                        self.error = "登录失败，请检查账号密码"
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    self.isLoading = false
//                    self.error = error.localizedDescription
//                }
//            }
//        }
//    }

}
