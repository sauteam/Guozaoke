//
//  APIService.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//
// https://github.com/mzlogin/guanggoo-android/blob/master/docs/guanggoo-api.md#获取主题列表

import Foundation
import SwiftSoup
import Alamofire
import WebKit

/// href
let ghref = "href"
/// src
let gsrc  = "src"

let spanNode = "span.node"
let spanUsername = "span.username"
let imgAvatar = "img.avatar"
let spanTime = "span.time"
let spanContent = "span.content"

let needLoginTextCanDo  = "请先登录社区再完成操作"


struct NoMoreDataTitle {
    static let nodaText   = "没有数据"
    static let nodata     = nodaText//LoginStateChecker.isLogin ? nodaText : needLoginTextCanDo
    static let homeList   = "到底啦"
    static let notiList   = "没有通知消息"
    static let commentList = "评论到底了，要不要发一条"
}

enum MyTopicEnum: String {
    case collections = "favorites"
    case topics = "topics"
    case browse = "replies"
    
    var title: String {
        switch self {
        case .collections:
            return "我的收藏"
        case .topics:
            return "我的主题"
        case .browse:
            return "我的回复"
        }
    }
}

struct DeveloperInfo {
    static let username =  "isau"
    static let email =  "268144637@qq.com"
    
}

/// App 版本信息
struct AppInfo {
    /// guozaoke github url
    static let guozaokeGithubUrl = "https://github.com/sauteam/Guozaoke"
    static let appleEula = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let univerLink   = "www.guozaoke.com"
    static let scheme = "guozaoke"
    static let appIntro = "过早客是源自武汉的高端社交网络，这里有关于创业、创意、IT、金融等最热话题的交流，也有招聘问答、活动交友等最新资讯的发布。"
    /// 默认不展示备案号，后期有需要可置为 true
    static let showBeiAnNumber: Bool = false
    static let AppBeiAnText = "粤ICP备2025374276号-2A"
    static let beianGovUrl = "https://beian.miit.gov.cn"
    static let AppId = "6740704728"
    static let AppStoreUrl = "https://apps.apple.com/app/id\(AppId)"
    static let AppStoreReviewUrl = "itms-apps://itunes.apple.com/app/id\(AppId)?action=write-review"

    static var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "过早客"
    }
    
    static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static var buildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "100"
    }
    
    
    /// 去AppStore
    static func toAppStore() {
        logger("url \(AppInfo.AppStoreUrl)")
        AppInfo.AppStoreUrl.openURL()
    }
    /// 去评论
    static func toWriteReview() {
        AppInfo.AppStoreReviewUrl.openURL()
    }
}


struct BaseResponse: Codable {
    let message: String?
    let success: Int?
    let voted: Bool?
    let count: Int?
}

struct APIError: Error {
    let message: String
}

struct APIService {
    static let shared  = APIService()
    static let baseUrlString = "https://www.guozaoke.com"
    static let baseURL       = URL(string: baseUrlString)!
    static let registerUrl   = baseUrlString + "/register"
    static let forgotUrl     = baseUrlString + "/forgot"
    static let loginUrl      = baseUrlString + "/login"
    static let notifications = "/notifications"
    static let favorites     = "/favorites"
    static let feedback      = "/node/feedback"
    static let helper        = "/node/guide"
    static let notice        = "/node/notice"
    static let deleteTopicUrl = "/t/112831"
    static let deleteAccountUrl = "/t/116623"
    static let iosUpdateTopicInfo = "/t/119731"
    static let androidUpdateTopicInfo = "/t/75634"
    static let faq = "/faq"
    static let members = "/members"
    static let blockedUser = "/setting/blockedUser"
    static let points = "/points"
    static let pointsLedger = "/points/ledger"
    static let pointsLevels = "/points/levels"
    static let messages = "/messages"
    /// baseUrlString + feedback
    static let feedbackAllLink = baseUrlString + feedback

    private init() {}
    
    
    static func fetchLoginPage() async throws -> (Bool, String) {
        var success   = false
        var tokenText = ""
        
        let html = try await NetworkManager.shared.get(loginUrl)
        
        // 注意：NetworkManager使用Alamofire，cookie会自动处理
        // 如果需要手动保存cookie，可以通过Alamofire的响应获取
        
        let doc = try SwiftSoup.parse(html)
        if let tokenInput = try doc.select("input[name=_xsrf]").first() {
            tokenText = try tokenInput.attr("value")
            if tokenText.count > 0 {
                var account = AccountState.getAccount()
                account?.xsrfToken = tokenText
                AccountState.update(account)
            }
            success   =  true
        }
        return (success, tokenText)
    }

    // 将响应中的 Cookies 保存到 HTTPCookieStorage
    static func saveCookies(from response: HTTPURLResponse) {
        if let responseUrl = response.url {
            let headerFields = response.allHeaderFields as? [String: String] ?? [:]
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseUrl)
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
                logger("[cookies]Saved Cookie: \(cookie.name) = \(cookie.value)")
            }
            saveCookiesToAppGroups()
        }
    }
    
    static func saveCookiesToAppGroups() {
        let cookieString = getStoredCookies()
        if let userDefaults = UserDefaults(suiteName: guozaokeGroup) {
            userDefaults.set(cookieString, forKey: "stored_cookies")
            userDefaults.synchronize()
            // 验证保存是否成功
            let savedCookie = userDefaults.string(forKey: "stored_cookies")
            if savedCookie == cookieString {
                //logger("[cookies]Cookie长度: \(cookieString.count) 字符 [cookies]保存Cookie到App Groups: \(cookieString)")
            } else {
                logger("[cookies]Cookie保存验证失败")
            }
        } else {
            logger("[cookies]无法访问App Groups")
        }
    }
    
    static func getNotifications(url: String) async throws -> String {
        let response: String = try await NetworkManager.shared.get(url)
        return response
    }
    
    static func logout() async throws -> String {
        let response: String = try await NetworkManager.shared.get(APIService.baseUrlString + "/logout")
        if response.isEmpty == false {
            LoginStateChecker.clearUserInfo()
            NotificationCenter.default.post(name: .logoutSuccessNoti, object: nil)
        }
        return response
    }
    
    static func extractNumberSimple(from text: String) -> String? {
        let clean = text.components(separatedBy: CharacterSet(charactersIn: "?#")).first ?? text
        let digits = clean.filter { $0.isNumber }
        if !digits.isEmpty {
            return digits
        }
        let components = clean.split(separator: "/")
        if let last = components.last {
            return String(last)
        }
        return nil
    }
    
    /// 发表评论
    static func sendComment(url: String, content: String) async throws -> String {
        let cleanUrl = url.postDetailUrl
        let tid = extractNumberSimple(from: cleanUrl) ?? cleanUrl.extractDigits()
        let parameters: Parameters = [
            "tid": tid,
            "content": content
        ]
        return try await toServer(url: cleanUrl, parameters: parameters)
    }
        
    /// 发布主题
    static func sendPost(
        url: String,
        title: String,
        content: String
    ) async throws -> String {
        let parameters: Parameters = [
            "title": title,
            "content": content,
        ]
        return try await toServer(url: url, parameters: parameters)
    }
    
    static func toServer(url: String, parameters: Parameters) async throws -> String {
        let xsrfToken = AccountState.token()
        if xsrfToken.isEmpty {
            let _  = LoginStateChecker.clearUserInfo()
        }
        
        var baseParams: [String: Any] = [
            "_xsrf": xsrfToken
        ]
        
        for (key, value) in parameters {
            baseParams[key] = value
        }
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
            "Accept-Encoding": "gzip, deflate",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36",
            "Referer": url
        ]
        
        // 调用通用请求方法
        let response: String = try await NetworkManager.shared.post(url, parameters: baseParams, headers: headers)
        return response
    }
}


extension APIService {
//    static func getCookies() async throws -> (String, [HTTPCookie]?) {
//        if let existingCookies = cookies(), !existingCookies.isEmpty {
//            saveCookies(existingCookies)
//            return ("读取", existingCookies)
//        }
//        let response: String = try await NetworkManager.shared.get(APIService.baseUrlString)
//        if let newCookies = cookies(), !newCookies.isEmpty {
//            saveCookies(newCookies)
//        }
//        return (response, cookies())
//    }
    
    // 获取存储的 Cookies 并格式化为请求头
    static func getStoredCookies() -> String {
        var cookieDict: [String: String] = [:]
        
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                if cookie.domain.contains("guozaoke.com") {
                    cookieDict[cookie.name] = cookie.value
                }
            }
        }
        
        var cookieHeader = cookieDict.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        
        // 如果从HTTPCookieStorage获取不到Cookie，尝试从App Groups读取
        if cookieHeader.isEmpty {
            if let userDefaults = UserDefaults(suiteName: guozaokeGroup),
               let storedCookies = userDefaults.string(forKey: "stored_cookies") {
                cookieHeader = storedCookies
                logger("[cookies]从App Groups读取Cookie: \(cookieHeader)")
            }
        }
        
        return cookieHeader
    }
    
    static func saveCookies(_ cookies: [HTTPCookie]) {
        let cookieStorage = HTTPCookieStorage.shared
        for cookie in cookies {
            cookieStorage.setCookie(cookie)
            logger("[save]Saved Cookie: \(cookie.name) = \(cookie.value)")
        }
    }
    
    static func cookies() -> [HTTPCookie]? {
        let cookies = HTTPCookieStorage.shared.cookies
        //logger("[cookies]\(cookies)")
        return cookies
    }
    
    private static func isAntiBotCookieName(_ name: String) -> Bool {
        return name == "acw_sc__v2" || name == "acw_tc" || name == "cdn_sec_tc"
    }

    static func clearCookiesForDomain() {
        if let cookies = cookies() {
            for cookie in cookies {
                if cookie.domain.contains("guozaoke.com") {
                    if !isAntiBotCookieName(cookie.name) {
                        HTTPCookieStorage.shared.deleteCookie(cookie)
                        logger("[cookies]Deleted user session cookie: \(cookie.name)")
                    }
                }
            }
        }
    }
    
    static func clearCookieStorage() {
        let cookieStore = URLSession.shared.configuration.httpCookieStorage
        cookieStore?.cookies?.forEach { cookie in
            if !isAntiBotCookieName(cookie.name) {
                cookieStore?.deleteCookie(cookie)
            }
        }
        logger("[cookies][httpCookieStorage] Deleted user session cookies.")
    }
    
    static func clearWebViewCookies() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: [WKWebsiteDataTypeCookies]) { records in
            records.forEach { record in
                dataStore.removeData(ofTypes: [WKWebsiteDataTypeCookies], for: [record]) {
                    logger("Deleted WebView cookies for \(record.displayName)")
                }
            }
        }
    }

    static func clearCookie() {
        clearCookieStorage()
        clearWebViewCookies()
        clearCookiesForDomain()
        let cookieStore = HTTPCookieStorage.shared
        for cookie in cookieStore.cookies ?? [] {
            if !isAntiBotCookieName(cookie.name) {
                cookieStore.deleteCookie(cookie)
            }
        }
        
        // 重新同步保留的防爬Cookie到App Groups
        saveCookiesToAppGroups()
        logger("[cookies]已清理用户登录Cookie，并保留防爬盾通行证")
    }
    
    private func printCookies(tag: String = .empty) {
        let storage = HTTPCookieStorage.shared
        if let cookies = storage.cookies {
            for cookie in cookies {
                logger("\(tag) --> cookie: \(cookie.name), \(cookie.value)")
            }
        }
    }
}

extension String {
    /// 提取数字
    var extractNumericPart: String {
        let regex = "[0-9]+"
        if let range = self.range(of: regex, options: .regularExpression) {
            return String(self[range])
        }
        return ""
    }
    
    /// 使用 CharacterSet 判断是否全部是数字
    var allCharactersAreDigits: Bool {
        return self.allSatisfy { $0.isNumber }
    }
    
    /// 后面拼接参数
    var addUrl: String {
        return APIService.baseUrlString + self
    }
    
    /// 个人主页
    var userProfileUrl: String {
        let uid = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if uid.hasPrefix("http://") || uid.hasPrefix("https://") {
            return uid
        }
        if uid.hasPrefix("/u/") {
            return APIService.baseUrlString + uid
        }
        if uid.hasPrefix("/") {
            return APIService.baseUrlString + "/u" + uid
        }
        return APIService.baseUrlString + "/u/" + uid
    }
    
    /// 详情主页
    var postDetailUrl: String {
        let tid = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let t   = "/t/"
        let base  = APIService.baseUrlString
        let baseT = base + t
        if tid.contains(baseT) {
            return tid
        }
        
        // 站内搜索命中回复时返回 /search/reply/{id}，需保留该路径由服务端302重定向至对应帖子
        if tid.contains("/search/reply/") {
            if tid.hasPrefix("http://") || tid.hasPrefix("https://") {
                return tid
            }
            let path = tid.hasPrefix("/") ? tid : "/" + tid
            return base + path
        }
        
        // 兼容处理缺少斜杠拼接的情况（如 https://www.guozaoke.com134555）
        var rawTid = tid
        if rawTid.hasPrefix(base) {
            rawTid = String(rawTid.dropFirst(base.count))
        }
        rawTid = rawTid.components(separatedBy: CharacterSet(charactersIn: "?#")).first ?? rawTid
        if rawTid.hasPrefix(t) {
            return base + rawTid
        }
        if rawTid.hasPrefix("/") {
            rawTid = String(rawTid.dropFirst())
        }
        if rawTid.hasPrefix("t/") {
            rawTid = String(rawTid.dropFirst(2))
        }
        
        let numericId = rawTid.filter { $0.isNumber }
        let finalId = numericId.isEmpty ? rawTid : numericId
        return baseT + finalId
    }
        
    /// /node/IT => /t/create/IT
    var createPostUrl: String {
        var url = self
        if url.hasPrefix("/node") {
            url = url.replacingOccurrences(of: "/node", with: "create")
        }
        if !url.hasPrefix("/t") {
            url = "/t/" + url
        }
        return APIService.baseUrlString + url
    }
    
}



