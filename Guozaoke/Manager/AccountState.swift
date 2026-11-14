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
    var nickname: String?
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
        // 依次尝试所有 parts (适配 Tornado v1: base64|timestamp|sig 与 v2: 2|1:0|10:timestamp|4:user|44:base64|sig)
        for part in parts {
            var candidate = part
            if let colonIdx = candidate.firstIndex(of: ":") {
                candidate = String(candidate[candidate.index(after: colonIdx)...])
            }
            if let data = Data(base64Encoded: candidate),
               let decoded = String(data: data, encoding: .utf8) {
                let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed.count <= 64 && trimmed.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) == nil {
                    return trimmed
                }
            }
        }
        return nil
    }

    static let invalidDisplayNames: Set<String> = [
        "主页", "我的主页", "个人主页", "设置", "退出", "登出", "登录", "注册",
        "收藏", "我的收藏", "通知", "消息", "动态", "创作", "发帖", "管理", "node", "topic"
    ]
    
    static func isValidDisplayName(_ name: String?) -> Bool {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return false
        }
        return !invalidDisplayNames.contains(trimmed)
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
            
            var needsSave = false
            
            // 自动容错修复 0：如果 nickname 是无效的菜单导航文字（如 "主页" 等），清除
            if let nick = account.nickname, !isValidDisplayName(nick) {
                logger("[AccountState] 自动清除无效昵称: '\(nick)'")
                account.nickname = nil
                needsSave = true
            }
            
            // 自动容错修复 0.1：如果 username 是无效的菜单导航文字（如 "主页"），从 userLink 或 Cookie 恢复真实用户名
            if !isValidDisplayName(account.username) {
                var restored = false
                if let link = account.userLink, link.contains("/u/") {
                    let linkSlug = link.replacingOccurrences(of: "/u/", with: "")
                        .components(separatedBy: CharacterSet(charactersIn: "?#/")).first?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if isValidDisplayName(linkSlug) {
                        logger("[AccountState] 从 userLink 恢复 username: '\(linkSlug)'")
                        account.username = linkSlug
                        needsSave = true
                        restored = true
                    }
                }
                if !restored, let cookieName = extractUsernameFromCookies(), isValidDisplayName(cookieName) {
                    logger("[AccountState] 从 Cookie 恢复 username: '\(cookieName)'")
                    account.username = cookieName
                    needsSave = true
                }
            }
            
            // 自动容错修复 1：如果 username 带有 /u/ 前缀，清理为纯用户名
            if account.username.hasPrefix("/u/") {
                let clean = account.username.replacingOccurrences(of: "/u/", with: "")
                    .components(separatedBy: CharacterSet(charactersIn: "?#/")).first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if isValidDisplayName(clean) {
                    account.username = clean
                    needsSave = true
                }
            }
            
            // 自动容错修复 2：如果 userLink 包含合法 slug，但 username 包含了汉字或为空，修复 username 并保留 nickname
            if let link = account.userLink, link.contains("/u/") {
                let linkSlug = link.replacingOccurrences(of: "/u/", with: "")
                    .components(separatedBy: CharacterSet(charactersIn: "?#/")).first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if isValidDisplayName(linkSlug) && linkSlug != "guozaoke" {
                    let hasNonAscii = account.username.unicodeScalars.contains { $0.value > 127 }
                    if account.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasNonAscii {
                        if (account.nickname == nil || account.nickname?.isEmpty == true) && isValidDisplayName(account.username) {
                            account.nickname = account.username
                        }
                        logger("[AccountState] 自动校正用户名: 原 '\(account.username)' -> slug '\(linkSlug)'")
                        account.username = linkSlug
                        needsSave = true
                    }
                }
            }
            
            // 自动容错修复 3：如果历史数据中 username 为空，尝试从 Cookie 恢复
            if account.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let healedName = extractUsernameFromCookies(), isValidDisplayName(healedName) {
                    logger("[AccountState] 从Cookie自动修复历史空用户名: \(healedName)")
                    account.username = healedName
                    if account.userLink == nil || account.userLink?.isEmpty == true || account.userLink == "/u/" {
                        account.userLink = "/u/\(healedName)"
                    }
                    needsSave = true
                }
            }
            
            // 自动容错修复 4：如果 username 是纯数字（即被错存为数字ID），而 nickname 是可读文本（用户名），自动纠正
            if account.username.allSatisfy({ $0.isNumber }) && !account.username.isEmpty {
                if let nick = account.nickname, isValidDisplayName(nick) && !nick.allSatisfy({ $0.isNumber }) {
                    logger("[AccountState] 自动校正：原 username 为数字ID '\(account.username)', 校正为用户名 '\(nick)'")
                    account.username = nick
                    needsSave = true
                }
            }
            
            if needsSave {
                saveAccount(account)
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
        // 1. 优先从当前 HTTPCookieStorage 中获取最新的 _xsrf
        if let cookieToken = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "_xsrf" })?.value,
           !cookieToken.isEmpty {
            return cookieToken
        }
        // 2. 其次从 App Groups 共享存储中提取 _xsrf
        if let userDefaults = UserDefaults(suiteName: guozaokeGroup),
           let storedCookies = userDefaults.string(forKey: "stored_cookies") {
            let pairs = storedCookies.components(separatedBy: ";")
            for pair in pairs {
                let parts = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: "=")
                if parts.count >= 2 && parts[0] == "_xsrf" && !parts[1].isEmpty {
                    return parts[1]
                }
            }
        }
        // 3. 兜底使用持久化存储的 xsrfToken
        return getAccount()?.xsrfToken ?? ""
    }
    
    static var userName: String {
        return getAccount()?.username ?? .default
    }
    
    static var displayName: String {
        let acc = getAccount()
        if let nick = acc?.nickname, isValidDisplayName(nick) {
            return nick
        }
        if isValidDisplayName(userName) {
            return userName
        }
        return ""
    }
    
    static var nickname: String {
        return displayName
    }
    
    static var userLink: String {
        return getAccount()?.userLink ?? .default
    }

    static var avatarUrl: String {
        return getAccount()?.avatar ?? .default
    }
    
    static func isSelf(userName: String) -> Bool {
        var clean = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty || clean == .default { return false }
        if clean.hasPrefix("@") {
            clean = String(clean.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if clean.hasPrefix("#") {
            clean = String(clean.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if clean.hasPrefix("/u/") {
            clean = String(clean.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        clean = clean.components(separatedBy: CharacterSet(charactersIn: "?#/")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? clean
        if let range = clean.range(of: "Lv.", options: .caseInsensitive) {
            clean = String(clean[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !clean.isEmpty else { return false }

        let selfUser = Self.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selfNick = Self.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        var selfLink = Self.userLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if selfLink.hasPrefix("/u/") {
            selfLink = String(selfLink.dropFirst(3))
        }
        selfLink = selfLink.components(separatedBy: CharacterSet(charactersIn: "?#/")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !selfUser.isEmpty && selfUser != .default {
            if clean.caseInsensitiveCompare(selfUser) == .orderedSame { return true }
        }
        if !selfNick.isEmpty {
            if clean.caseInsensitiveCompare(selfNick) == .orderedSame { return true }
        }
        if !selfLink.isEmpty && selfLink != .default {
            if clean.caseInsensitiveCompare(selfLink) == .orderedSame { return true }
        }

        // 针对 isau / 80687 映射（如果当前登录为 isau 或包含 80687，两者互相认定为本人）
        let isUserIsau = selfUser.lowercased() == "isau" || selfLink == "80687" || selfNick.lowercased() == "isau"
        if isUserIsau && (clean.lowercased() == "isau" || clean == "80687") {
            return true
        }

        return false
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
                        "img.avatar"
                    ]
                    for sel in avatarCandidates {
                        if let img = try? doc.select(sel).first() {
                            let src = (try? img.attr("src")) ?? ""
                            if !src.isEmpty && src.contains("avatar") {
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
            if let account = AccountState.getAccount() {
                var updated = account
                var hasChanges = false
                let userLinkCandidates = [
                    ".gzk-avatar-menu-panel a[href^='/u/']",
                    ".gzk-avatar-menu a[href^='/u/']",
                    "ul.navbar-right a[href^='/u/']",
                    ".navbar-nav.navbar-right a[href^='/u/']",
                    ".gzk-desktop-account a[href^='/u/']",
                    "#navbar5 a[href^='/u/']",
                    ".usercard a[href^='/u/']"
                ]
                for sel in userLinkCandidates {
                    if let link = try? doc.select(sel).first() {
                        let href = (try? link.attr("href")) ?? ""
                        if !href.isEmpty && href != "/u/" && href != "/u/guozaoke" {
                            let uname = href.replacingOccurrences(of: "/u/", with: "")
                                .components(separatedBy: CharacterSet(charactersIn: "?#/")).first?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            let linkText = (try? link.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            let validText = AccountState.isValidDisplayName(linkText) ? linkText : ""
                            
                            // 优先采用字母用户名：若 href 中的 uname 为纯数字ID，而链接文本为真实用户名，采用真实用户名
                            let finalName = (uname.allSatisfy({ $0.isNumber }) && AccountState.isValidDisplayName(validText) && !validText.allSatisfy({ $0.isNumber })) ? validText : uname
                            
                            if AccountState.isValidDisplayName(finalName) {
                                let hasNonAscii = updated.username.unicodeScalars.contains { $0.value > 127 }
                                let isDigits = updated.username.allSatisfy { $0.isNumber }
                                if updated.username.isEmpty || hasNonAscii || (isDigits && !finalName.allSatisfy { $0.isNumber }) || updated.username.hasPrefix("/u/") || !AccountState.isValidDisplayName(updated.username) {
                                    logger("[AccountState] 页面加载时自动修复用户名: 原 '\(updated.username)' -> '\(finalName)'")
                                    updated.username = finalName
                                    hasChanges = true
                                }
                                if updated.userLink != href {
                                    updated.userLink = href
                                    hasChanges = true
                                }
                                if AccountState.isValidDisplayName(validText) && updated.nickname != validText {
                                    updated.nickname = validText
                                    hasChanges = true
                                }
                                break
                            }
                        }
                    }
                }
                if hasChanges {
                    AccountState.saveAccount(updated)
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


