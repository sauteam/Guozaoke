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
        Persist.remove(key: loginUserKey)
        ACCOUNT = nil
        APIService.clearCookie()
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
            print("[login] needLogin updated to: \(needLogin)")
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
        }
        //这里有些问题 
//        Task { @MainActor in
//            if self.needLogin == true {
//                self.needLogin = false
//                self.error = nil
//            }
//        }
        return false
    }
}


