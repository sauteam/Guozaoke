//
//  AccountState.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import Foundation
import SwiftSoup

// MARK: - 账户信息
struct AccountInfo: Codable {
    var username: String
    var xsrfToken: String?
    
    func isValid() -> Bool {
        return xsrfToken.isEmpty == true
    }
}

struct Persist {
    private static let userDefault = UserDefaults.standard

    static func save(value: Any, forkey key: String) {
        userDefault.set(value, forKey: key)
    }

    static func read(key: String, default: String = .empty) -> String {
        return userDefault.string(forKey: key) ?? `default`
    }

    static func read(key: String) -> Data? {
        return userDefault.data(forKey: key)
    }
}

struct AccountState {
    static let ACCOUNT_KEY = "com.guozaoke.ios"
    static var ACCOUNT: AccountInfo?

    static func saveAccount(_ account: AccountInfo) {
        do {
            let jsonData = try JSONEncoder().encode(account)
            Persist.save(value: jsonData, forkey: AccountState.ACCOUNT_KEY)
            log("account: \(account) saved")
            ACCOUNT = account
        } catch {
            log("Save account failed")
        }
    }

    static func deleteAccount() {
        Persist.save(value: String.empty, forkey: AccountState.ACCOUNT_KEY)
        ACCOUNT = nil
        APIService.shared.clearCookie()
    }

    static func getAccount() -> AccountInfo? {
        do {
            if ACCOUNT != nil { return ACCOUNT }
            let data = Persist.read(key: ACCOUNT_KEY)
            guard let data = data else { return nil }
            ACCOUNT = try JSONDecoder()
                .decode(AccountInfo.self, from: data)
            return ACCOUNT
        } catch {
            log("readAccount failed")
        }
        return nil
    }

    static func isLogin() -> Bool {
        return getAccount() != nil
    }
    
    static func token() -> String {
        return getAccount()?.xsrfToken ?? ""
    }

    static var userName: String {
        return getAccount()?.username ?? .default
    }

//    static var avatarUrl: String {
//        return getAccount()?.avatar ?? .default
//    }
    
    static func isSelf(userName: String) -> Bool {
        return userName == Self.userName && userName != .default
    }

}


// MARK: - 登录目标枚举
enum LoginDestination {
    case postDetail(postId: String)
    case comment(postId: String)
    case profile
    // ... 其他需要登录的目标
}

// MARK: - 登录状态检查
class LoginStateChecker: ObservableObject {
    static let shared = LoginStateChecker()
    @Published var isLogin = false
    @Published var needLogin = false
    @Published var error: String?
    @Published var loginDestination: LoginDestination?
    
    func loginStateChecker() -> Bool {
        return AccountState.isLogin()
    }
    
    func checkLoginState(doc: Document) throws -> Bool {
        // 检查是否存在登录表单
        let loginForm = try doc.select("form.form-horizontal")
        let alerts    = try doc.select("ul.alert-danger li")
        
        if !loginForm.isEmpty() {
            // 检查错误提示
            if !alerts.isEmpty() {
                error = try alerts.first()?.text() ?? "需要登录"
            } else {
                error = "请先登录社区再完成操作"
            }
            needLogin = true
            return true
        }
        
        needLogin = false
        error = nil
        return true
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let reloadPostDetail = Notification.Name("reloadPostDetail")
    static let reloadComments = Notification.Name("reloadComments")
    static let reloadProfile = Notification.Name("reloadProfile")
}

