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

// MARK: - 通知名称扩展
extension Notification.Name {
    static let loginSuccessNoti = Notification.Name("loginSuccessNoti")
}

// MARK: - 登录服务
class LoginService: ObservableObject {
    @State var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?
    
    // XSRF Token
    private var xsrfToken: String = ""

    private let loginUrl = APIService.baseUrlString + "/login"
        
    func fetchLoginPage() async throws -> Bool {
        var success = false
        guard let url = URL(string: loginUrl) else {
            throw LoginError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw LoginError.invalidData
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            saveCookies(from: httpResponse)
        }
        
        let doc = try SwiftSoup.parse(html)
        if let tokenInput = try doc.select("input[name=_xsrf]").first() {
            xsrfToken = try tokenInput.attr("value")
            success =  true
        }
        return success
    }
    
    // 将响应中的 Cookies 保存到 HTTPCookieStorage
    private func saveCookies(from response: HTTPURLResponse) {
        if let cookies = response.allHeaderFields["Set-Cookie"] as? String {
            // 分割多个 Cookies
            let cookieArray = cookies.split(separator: ";")
            
            for cookie in cookieArray {
                let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                    .domain: "www.guozaoke.com",
                    .path: "/",
                    .name: "session_id", // 或者使用从 cookie 字符串中解析出的名称
                    .value: cookie, // 存储每个 Cookie 的值
                    .secure: "TRUE",
                    .expires: NSDate(timeIntervalSinceNow: 31536000)
                ]
                
                if let cookie = HTTPCookie(properties: cookieProperties) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                    print("[cookies]Saved Cookie: \(cookie.name) = \(cookie.value)")
                }
            }
        }
    }
    
//    // 执行登录请求
    func login(email: String, password: String) async throws -> Bool {
        var loginSuccess = false
        guard xsrfToken.isEmpty == false else {
            let success = try await fetchLoginPage()
            if success {
                log("login success")
                loginSuccess = try await login(email: email, password: password)
            } else {
                log("login fail")
            }
            return loginSuccess
        }
        
        await MainActor.run {
            isLoggedIn = true
            isLoading  = false
        }
        
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
            log("[login] \(doc)")
            let avatarElement = try doc.select(".ui-header a img").first()
            let avatar = try avatarElement?.attr("src") ?? ""
            let username = try doc.select(".ui-header .username").first()?.text() ?? ""
//            // Number
//            let numberElement = try doc.select(".user-number .number").first()
//            let number = try numberElement?.text() ?? ""
//            // Since
//            let sinceElement = try doc.select(".user-number .since").first()
//            let since = try sinceElement?.text() ?? ""
            let idElement = try doc.select(".ui-header a").first()
            let idLink = try idElement?.attr("href") ?? ""

            if try doc.select("div.topic-item").count > 0 {
                let account = AccountInfo(username: username, xsrfToken: xsrfToken, avatar: avatar, userLink: idLink)
                DispatchQueue.main.async {
                    AccountState.saveAccount(account)
                }
                log("[userInfo]\(account)")
                NotificationCenter.default.post(name: .loginSuccessNoti, object: nil, userInfo: ["userId":idLink, "userName": username, "avatar": avatar])
                isLoggedIn    = true
                loginSuccess  = true
                LoginStateChecker.LoginStateHandle()
            } else {
                throw LoginError.loginFailed(message: "登录失败")
            }
        } else {
            throw LoginError.httpError(statusCode: httpResponse.statusCode)
        }
        return loginSuccess
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
