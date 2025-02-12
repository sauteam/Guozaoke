//
//  AccountState.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import Foundation
import SwiftSoup
import JDStatusBarNotification

struct EditPost: Codable {
    static let editPostInfoKey = "editPostInfo"
    let title: String?
    let content: String?
    let topicId: String?
    let topicLink: String?

    static func saveEditPost(_ post: EditPost) {
        do {
            let jsonData = try JSONEncoder().encode(post)
            Persist.save(value: jsonData, forkey: editPostInfoKey)
            log("account: \(post) saved")
        } catch {
            log("Save post failed")
        }
    }
    
    static func removeEditPost() {
        Persist.remove(key: editPostInfoKey)
    }
    
    static func getEditPost() -> EditPost? {
        do {
            let data = Persist.read(key: editPostInfoKey)
            guard let data = data else { return nil }
            let info = try JSONDecoder()
                .decode(EditPost.self, from: data)
            return info
        } catch {
            log("readAccount failed")
        }
        return nil
    }
}

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
        print("[bao]save \(value) \(key)")
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
            log("account: \(account) saved")
            ACCOUNT = account
        } catch {
            log("Save account failed")
        }
    }
    
    
    static func update(_ account: AccountInfo?) {
        if let account = account {
            saveAccount(account)
        }
    }


    static func deleteAccount() {
        if getAccount() != nil {
            Persist.remove(key: loginUserKey)
            ACCOUNT = nil
            APIService.clearCookie()
        } else {
            log("没登录用户信息")
        }
    }

    static func getAccount() -> AccountInfo? {
        do {
            if ACCOUNT != nil { return ACCOUNT }
            let data = Persist.read(key: loginUserKey)
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
    
    static var userLink: String {
        return getAccount()?.userLink ?? .default
    }

    static var avatarUrl: String {
        return getAccount()?.avatar ?? .default
    }
    
    static func isSelf(userName: String) -> Bool {
        return userName == Self.userName && userName != .default
    }

}


// MARK: - 登录状态检查
class LoginStateChecker: ObservableObject {
    static let shared = LoginStateChecker()
    @Published var isLogin = false
    @Published var needLogin = false
    @Published var error: String?
    
    static func clearUserInfo() {
        runInMain {
            LoginStateChecker.shared.needLogin = true
            LoginStateChecker.shared.isLogin = false
            AccountState.deleteAccount()
            APIService.clearCookie()
        }
    }
    
    static func LoginStateHandle() {
        runInMain {
            let success = isLogin()
            LoginStateChecker.shared.needLogin = !success
            LoginStateChecker.shared.isLogin   = success
        }
    }
        
    static func isLogin() -> Bool {
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
                ToastView.toastText(needLoginTextCanDo)
                    
                if !self.needLogin {
                    self.needLogin = true
                }
            }
            return true
        }
        
        Task { @MainActor in
            if self.needLogin == true {
                self.needLogin = false
                self.error = nil
            }
        }
        return false
    }
}


