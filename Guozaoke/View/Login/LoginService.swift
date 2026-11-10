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
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?
    
    // XSRF Token
    private var xsrfToken: String = ""
    
    func login(email: String, password: String) async throws -> Bool {
        if email.isEmpty || password.isEmpty {
            ToastView.warningToast("填写账号和密码")
            return false
        }
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        var loginSuccess = false
        guard xsrfToken.isEmpty == false else {
            do {
                let (success, token) = try await APIService.fetchLoginPage()
                if success {
                    logger("login token fetched")
                    xsrfToken = token
                    loginSuccess = try await login(email: email, password: password)
                } else {
                    logger("login token fetch failed")
                    await MainActor.run {
                        self.isLoading = false
                        self.error = "获取页面Token失败"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error.localizedDescription
                }
                throw error
            }
            return loginSuccess
        }
        
        // 构建请求参数并通过 NetworkManager 发送，确保享有自动解算防爬盾和自动带Cookie重试能力
        let parameters: Parameters = [
            "email": email,
            "password": password,
            "_xsrf": xsrfToken
        ]
        
        let responseString: String
        do {
            responseString = try await NetworkManager.shared.request(
                APIService.loginUrl,
                method: .post,
                parameters: parameters
            )
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error.localizedDescription
            }
            throw error
        }
        
        // 解析响应
        let doc = try SwiftSoup.parse(responseString)
        
        // 检查错误信息
        if let errorMessage = try doc.select("ul.alert-danger li").first()?.text() {
            await MainActor.run {
                self.isLoading = false
                self.error = errorMessage
            }
            throw LoginError.loginFailed(message: errorMessage)
        }
        logger("[login] response parsed")
        
        // 尝试多种选择器解析用户名和个人主页链接
        var username = ""
        var userLink = ""
        var avatar = ""
        var nickname = ""
        
        // 1. 尝试从过早客导航栏或头像菜单中提取个人主页链接 (/u/{username}) 与真实 handle
        let userLinkCandidates = [
            ".gzk-avatar-menu-panel a[href^='/u/']",
            ".gzk-avatar-menu a[href^='/u/']",
            "ul.navbar-right a[href^='/u/']",
            ".navbar-nav.navbar-right a[href^='/u/']",
            ".gzk-desktop-account a[href^='/u/']",
            "#navbar5 a[href^='/u/']",
            ".usercard a[href^='/u/']",
            ".ui-header a[href^='/u/']"
        ]
        for sel in userLinkCandidates {
            if let linkElement = try? doc.select(sel).first() {
                let href = (try? linkElement.attr("href")) ?? ""
                if !href.isEmpty && href != "/u/" && href != "/u/guozaoke" {
                    userLink = href
                    let slug = href.replacingOccurrences(of: "/u/", with: "")
                        .components(separatedBy: CharacterSet(charactersIn: "?#/")).first?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let text = (try? linkElement.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let validText = AccountState.isValidDisplayName(text) ? text : ""
                    
                    // 若 href 中的 slug 为纯数字ID，而链接文本为字母用户名，优先以文本为准作为用户名
                    if slug.allSatisfy({ $0.isNumber }) && AccountState.isValidDisplayName(validText) && !validText.allSatisfy({ $0.isNumber }) {
                        username = validText
                        nickname = validText
                    } else if !slug.isEmpty && AccountState.isValidDisplayName(slug) {
                        username = slug
                        if AccountState.isValidDisplayName(validText) {
                            nickname = validText
                        }
                    } else if AccountState.isValidDisplayName(validText) {
                        username = validText
                        nickname = validText
                    }
                    break
                }
            }
        }
        
        // 2. 如果找到了链接，但尚未提取出用户名，从 href 中提取：/u/{username} -> {username}
        if !userLink.isEmpty && username.isEmpty {
            username = userLink.replacingOccurrences(of: "/u/", with: "")
                .components(separatedBy: CharacterSet(charactersIn: "?#/")).first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        
        // 5. 兜底尝试从 Cookie 中解析出 user 的数字ID / 用户名
        if username.isEmpty {
            if let cookieUser = AccountState.extractUsernameFromCookies(), !cookieUser.isEmpty {
                username = cookieUser
                userLink = "/u/\(cookieUser)"
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
            "img.avatar"
        ]
        for sel in avatarCandidates {
            if let img = try? doc.select(sel).first() {
                let src = (try? img.attr("src")) ?? ""
                if !src.isEmpty && src.contains("avatar") {
                    avatar = src
                    break
                }
            }
        }

        let topicCount = (try? doc.select("div.topic-item").count) ?? 0
        if !username.isEmpty || topicCount > 0 {
            let finalUsername = username
            let finalUserLink = userLink
            let finalAvatar = avatar
            let finalNickname = nickname
            let account = AccountInfo(
                username: finalUsername,
                xsrfToken: xsrfToken,
                avatar: finalAvatar,
                userLink: finalUserLink,
                nickname: finalNickname.isEmpty ? nil : finalNickname
            )
            await MainActor.run {
                AccountState.saveAccount(account)
                showToast()
                self.isLoggedIn = true
                self.isLoading = false
                NotificationCenter.default.post(
                    name: .loginSuccessNoti,
                    object: nil,
                    userInfo: ["userId": finalUserLink, "userName": finalUsername, "avatar": finalAvatar, "nickname": finalNickname]
                )
                LoginStateChecker.LoginStateHandle()
            }
            logger("[userInfo]\(account)")                
            APIService.saveCookiesToAppGroups()
            
            // 如果头像或昵称尚不完整，后台异步补全个人资料并预缓存头像
            if finalAvatar.isEmpty || finalNickname.isEmpty {
                Task.detached(priority: .background) {
                    await UserInfoParser().fetchUserInfoAndData(finalUsername.userProfileUrl)
                }
            }
            return true
        } else {
            await MainActor.run {
                self.isLoading = false
            }
            throw LoginError.loginFailed(message: "登录失败")
        }
    }
    
    @MainActor
    func updateLoginState() {
        isLoggedIn = true
        LoginStateChecker.LoginStateHandle()
    }
}
