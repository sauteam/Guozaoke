//
//  AccountState.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import Foundation
import SwiftSoup
import JDStatusBarNotification

// MARK: - 账户信息
struct AccountInfo: Codable {
    var username: String
    var xsrfToken: String?
    var avatar: String?
    var userLink: String?
    func isValid() -> Bool {
        return xsrfToken.isEmpty == true
    }
}

struct Persist {
    private static let userDefault = UserDefaults.standard

    static func save(value: Any, forkey key: String) {
        logger("[bao]save \(value) \(key)")
        userDefault.set(value, forKey: key)
    }
    
    static func remove(key: String)  {
        return userDefault.removeObject(forKey: key)
    }

    static func read(key: String, default: String = .empty) -> String {
        return userDefault.string(forKey: key) ?? `default`
    }

    static func read(key: String) -> Data? {
        return userDefault.data(forKey: key)
    }
}

struct AccountState {
    static let loginUserKey = "com.guozaoke.ios.user.info"
    static var ACCOUNT: AccountInfo?

    static func saveAccount(_ account: AccountInfo) {
        do {
            let jsonData = try JSONEncoder().encode(account)
            Persist.save(value: jsonData, forkey: loginUserKey)
            logger("account: \(account) saved")
            ACCOUNT = account
        } catch {
            logger("Save account failed")
        }
    }
    
    
    static func update(_ account: AccountInfo?) {
        if let account = account {
            saveAccount(account)
        }
    }


    static func deleteAccount() {
        Persist.remove(key: loginUserKey)
        ACCOUNT = nil
        APIService.clearCookie()
    }

    static func extractUsernameFromCookies() -> String? {
        var userCookieValue: String?
        if let cookies = HTTPCookieStorage.shared.cookies {
            for c in cookies where c.name == "user" {
                userCookieValue = c.value
                break
            }
        }
        if userCookieValue == nil {
            let cookieHeader = APIService.getStoredCookies()
            let pairs = cookieHeader.components(separatedBy: ";")
            for pair in pairs {
                let trimmed = pair.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("user=") {
                    userCookieValue = String(trimmed.dropFirst(5))
                    break
                }
            }
        }
        guard let rawVal = userCookieValue?.replacingOccurrences(of: "\"", with: "") else {
            return nil
        }
        let parts = rawVal.components(separatedBy: "|")
        if let firstPart = parts.first,
           let data = Data(base64Encoded: firstPart),
           let decoded = String(data: data, encoding: .utf8) {
            let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    static func getAccount() -> AccountInfo? {
        do {
            if let acc = ACCOUNT, !acc.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return acc
            }
            let data = Persist.read(key: loginUserKey)
            guard let data = data else { return nil }
            var account = try JSONDecoder()
                .decode(AccountInfo.self, from: data)
            
            // 自动容错修复：如果历史数据中 username 为空，尝试从 Cookie 恢复
            if account.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let healedName = extractUsernameFromCookies(), !healedName.isEmpty {
                    logger("[AccountState] 从Cookie自动修复历史空用户名: \(healedName)")
                    account.username = healedName
                    if account.userLink == nil || account.userLink?.isEmpty == true || account.userLink == "/u/" {
                        account.userLink = "/u/\(healedName)"
                    }
                    saveAccount(account)
                }
            }
            ACCOUNT = account
            return ACCOUNT
        } catch {
            logger("readAccount failed")
        }
        return nil
    }

    static func isLogin() -> Bool {
        guard let account = getAccount() else { return false }
        return !account.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    static func token() -> String {
        return getAccount()?.xsrfToken ?? ""
    }
    
    static var userName: String {
        return getAccount()?.username ?? .default
    }
    
    static var userLink: String {
        return getAccount()?.userLink ?? .default
    }

    static var avatarUrl: String {
        return getAccount()?.avatar ?? .default
    }
    
    static func isSelf(userName: String) -> Bool {
        return userName == Self.userName && userName != .default
    }
    
    static var isISAU: Bool {
        return isSelf(userName: "isau")
    }
}


// MARK: - 登录状态检查
class LoginStateChecker: ObservableObject {
    static let shared = LoginStateChecker()
    @Published var isLogin = false
    @Published var needLogin = false {
        didSet {
            logger("[login] needLogin updated to: \(needLogin)")
        }
    }
    @Published var error: String?
    
    static func clearUserInfo() {
        runInMain {
            LoginStateChecker.shared.needLogin = true
            LoginStateChecker.shared.isLogin = false
            AccountState.deleteAccount()
            APIService.clearCookie()
            //SendCommentInfo.clearAllSendCommentInfo()
        }
    }
    
    static func LoginStateHandle() {
        runInMain {
            let success = isLogin
            LoginStateChecker.shared.needLogin = !success
            LoginStateChecker.shared.isLogin   = success
        }
    }
        
    static var isLogin: Bool {
        return AccountState.isLogin()
    }
    
    func htmlCheckUserState(doc: Document) throws -> Bool {
        // 检查是否存在登录表单
        let loginForm = try doc.select("form.form-horizontal")
        let alerts    = try doc.select("ul.alert-danger li")
        
        if !loginForm.isEmpty() {
            // 检查错误提示
            if !alerts.isEmpty() {
                self.error = try alerts.first()?.text() ?? needLoginTextCanDo
            } else {
                error = needLoginTextCanDo
            }
            LoginStateChecker.clearUserInfo()
            runInMain {
                ToastView.warningToast(needLoginTextCanDo)
                    
                if !self.needLogin {
                    self.needLogin = true
                }
            }
            return true
        } else {
            APIService.saveCookiesToAppGroups()
            // 如果本地已登录但 AccountState.avatarUrl 为空，尝试从页面提取头像
            if AccountState.avatarUrl.isEmpty {
                if let account = AccountState.getAccount() {
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
                                var updated = account
                                updated.avatar = src
                                AccountState.saveAccount(updated)
                                logger("[AccountState] 页面加载时自动修复头像: \(src)")
                                break
                            }
                        }
                    }
                }
            }
            if AccountState.userName.isEmpty {
                if let account = AccountState.getAccount() {
                    var updated = account
                    let userLinkCandidates = [
                        ".gzk-avatar-menu-panel a[href^='/u/']",
                        "ul.navbar-right a[href^='/u/']",
                        ".gzk-desktop-account a[href^='/u/']",
                        "#navbar5 a[href^='/u/']"
                    ]
                    for sel in userLinkCandidates {
                        if let link = try? doc.select(sel).first() {
                            let href = (try? link.attr("href")) ?? ""
                            if !href.isEmpty && href != "/u/" && href != "/u/guozaoke" {
                                let uname = href.replacingOccurrences(of: "/u/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                if !uname.isEmpty {
                                    updated.username = uname
                                    updated.userLink = href
                                    AccountState.saveAccount(updated)
                                    logger("[AccountState] 页面加载时自动修复用户名: \(uname)")
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        // todo 这里有些问题 
//        Task { @MainActor in
//            if self.needLogin == true {
//                self.needLogin = false
//                self.error = nil
//            }
//        }
        return false
    }
}


