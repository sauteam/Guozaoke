//
//  LoginService.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup
import JDStatusBarNotification
import Alamofire

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
        
        // 构建请求参数并通过 NetworkManager 发送，确保享有自动解算防爬盾和自动带Cookie重试能力
        let parameters: Parameters = [
            "email": email,
            "password": password,
            "_xsrf": xsrfToken
        ]
        
        let responseString = try await NetworkManager.shared.request(
            APIService.loginUrl,
            method: .post,
            parameters: parameters
        )
        
        // 解析响应
        let doc = try SwiftSoup.parse(responseString)
        
        // 检查错误信息
        if let errorMessage = try doc.select("ul.alert-danger li").first()?.text() {
            throw LoginError.loginFailed(message: errorMessage)
        }
        logger("[login] \(doc)")
        
        // 尝试多种选择器解析用户名和个人主页链接
        var username = ""
        var userLink = ""
        var avatar = ""
        
        // 1. 尝试从过早客导航栏或头像菜单中提取个人主页链接 (/u/{username})
        let userLinkCandidates = [
            ".gzk-avatar-menu-panel a[href^='/u/']",
            "ul.navbar-right a[href^='/u/']",
            ".gzk-desktop-account a[href^='/u/']",
            ".usercard a[href^='/u/']",
            ".ui-header a[href^='/u/']",
            "#navbar5 a[href^='/u/']"
        ]
        for sel in userLinkCandidates {
            if let linkElement = try? doc.select(sel).first() {
                let href = (try? linkElement.attr("href")) ?? ""
                if !href.isEmpty && href != "/u/" && href != "/u/guozaoke" {
                    userLink = href
                    let text = (try? linkElement.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !text.isEmpty && text != "我的主页" && text != "个人主页" {
                        username = text
                    }
                    break
                }
            }
        }
        
        // 2. 如果找到了链接，但文本不是用户名，从 href 中提取：/u/{username} -> {username}
        if !userLink.isEmpty && username.isEmpty {
            username = userLink.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 3. 兜底尝试 .ui-header .username
        if username.isEmpty {
            username = (try? doc.select(".ui-header .username").first()?.text()) ?? ""
        }
        
        // 4. 兜底尝试从 body 的 data-gzk-viewer 属性中获取用户数字ID
        if username.isEmpty {
            let viewerId = (try? doc.select("body").attr("data-gzk-viewer")) ?? ""
            if !viewerId.isEmpty && viewerId != "0" {
                username = viewerId
                userLink = "/u/\(viewerId)"
            }
        }
        
        // 5. 兜底尝试从 Cookie 中解析出 user 的数字ID
        if username.isEmpty {
            if let cookies = HTTPCookieStorage.shared.cookies {
                for c in cookies where c.name == "user" {
                    let rawVal = c.value.replacingOccurrences(of: "\"", with: "")
                    let parts = rawVal.components(separatedBy: "|")
                    if let firstPart = parts.first,
                       let data = Data(base64Encoded: firstPart),
                       let decodedUid = String(data: data, encoding: .utf8), !decodedUid.isEmpty {
                        username = decodedUid
                        userLink = "/u/\(decodedUid)"
                        break
                    }
                }
            }
        }
        
        // 6. 如果登录输入的非邮箱（无 @），它本身就可能是用户名
        if username.isEmpty && !email.contains("@") {
            username = email
            userLink = "/u/\(email)"
        }
        
        if userLink.isEmpty && !username.isEmpty {
            userLink = "/u/\(username)"
        }
        
        // 7. 解析头像
        let avatarCandidates = [
            ".gzk-avatar-menu summary img",
            ".gzk-avatar-menu img",
            "ul.navbar-right a[href^='/u/'] img",
            "ul.navbar-right img.avatar",
            "#navbar5 a[href^='/u/'] img",
            ".usercard img.avatar",
            ".ui-header a img"
        ]
        for sel in avatarCandidates {
            if let img = try? doc.select(sel).first() {
                let src = (try? img.attr("src")) ?? ""
                if !src.isEmpty {
                    avatar = src
                    break
                }
            }
        }

        let topicCount = (try? doc.select("div.topic-item").count) ?? 0
        if !username.isEmpty || topicCount > 0 {
            let account = AccountInfo(username: username, xsrfToken: xsrfToken, avatar: avatar, userLink: userLink)
            DispatchQueue.main.async {
                AccountState.saveAccount(account)
                showToast()
                loginSuccess  = true
                NotificationCenter.default.post(name: .loginSuccessNoti, object: nil, userInfo: ["userId":userLink, "userName": username, "avatar": avatar])
            }
            logger("[userInfo]\(account)")                
            APIService.saveCookiesToAppGroups()
            
            Task {
                await updateLoginState()
            }
        } else {
            throw LoginError.loginFailed(message: "登录失败")
        }
        return loginSuccess
    }
    
    @MainActor
    func updateLoginState() {
        isLoggedIn = true
        LoginStateChecker.LoginStateHandle()
    }
}
