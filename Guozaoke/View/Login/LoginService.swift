//
//  LoginService.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup
import JDStatusBarNotification

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
    static let refreshTokenNoti  = Notification.Name("refreshTokenNoti")
    static let loginSuccessNoti  = Notification.Name("loginSuccessNoti")
    static let logoutSuccessNoti = Notification.Name("logoutSuccessNoti")
    static let loginViewAlertNoti = Notification.Name("loginViewAlertNoti")
    static let purchaseSuccessNoti = Notification.Name("purchaseSuccessNoti")
    static let openAppNotification = Notification.Name("openAppNotification")
}

private func showToast() {
    runInMain {
        ToastView.successToast("登录成功")
    }
}


// MARK: - 登录服务
class LoginService: ObservableObject {
    @State var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?
    
    // XSRF Token
    private var xsrfToken: String = ""
    
    func login(email: String, password: String) async throws -> Bool {
        if email.isEmpty || password.isEmpty {
            ToastView.warningToast("填写账号和密码")
            return (false)
        }
        var loginSuccess = false
        guard xsrfToken.isEmpty == false else {
            let (success, token) = try await APIService.fetchLoginPage()
            if success {
                logger("login success")
                xsrfToken = token
                loginSuccess = try await login(email: email, password: password)
            } else {
                logger("login fail")
            }
            return loginSuccess
        }
        
        await MainActor.run {
            isLoggedIn = true
            isLoading  = false
        }
        
        guard let url = URL(string:APIService.loginUrl ) else {
            throw LoginError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 MyApp/1.0", forHTTPHeaderField: "User-Agent")
        
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
            logger("[login] \(doc)")
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
                    showToast()
                    loginSuccess  = true
                    NotificationCenter.default.post(name: .loginSuccessNoti, object: nil, userInfo: ["userId":idLink, "userName": username, "avatar": avatar])
                }
                logger("[userInfo]\(account)")                
                APIService.saveCookiesToAppGroups()
                
                Task {
                    await updateLoginState()
                }
            } else {
                throw LoginError.loginFailed(message: "登录失败")
            }
        } else {
            throw LoginError.httpError(statusCode: httpResponse.statusCode)
        }
        return loginSuccess
    }
    
    @MainActor
    func updateLoginState() {
        isLoggedIn = true
        LoginStateChecker.LoginStateHandle()
    }
}
