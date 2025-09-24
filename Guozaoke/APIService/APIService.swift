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
    static let homeList   = "已经到底啦"
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
    static let AppBeiAnText = "粤ICP备2025374276号-2A"
    static let beianGovUrl = "https://beian.miit.gov.cn"
    static let AppId = "6740704728"
    static let AppStoreUrl = "https://apps.apple.com/app/id\(AppId)"
    static let AppStoreReviewUrl = "itms-apps://itunes.apple.com/app/id\(AppId)?action=write-review"

    static var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "过早客"
    }
    
    static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
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
    /// baseUrlString + feedback
    static let feedbackAllLink = baseUrlString + feedback

    private init() {}
    
    
    static func fetchLoginPage() async throws -> (Bool, String) {
        var success   = false
        var tokenText = ""
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
                    logger("[cookies]Saved Cookie: \(cookie.name) = \(cookie.value)")
                }
            }
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
        let components = text.split(separator: "/")
        if let last = components.last {
            return String(last)
        }
        return nil
    }
    
    /// 发表评论
    static func sendComment(url: String, content: String) async throws -> String {
        let tid = extractNumberSimple(from: url)
        let parameters: Parameters = [
            "tid": tid ?? "",
            "content": content
        ]
        return try await toServer(url: url, parameters: parameters)
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
        var cookieHeader = ""
        
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                if cookie.domain.contains("guozaoke.com") {
                    cookieHeader += "\(cookie.name)=\(cookie.value); "
                }
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
    
    static func clearCookiesForDomain() {
        if let cookies = cookies() {
            for cookie in cookies {
                if cookie.domain.contains("guozaoke.com") {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                    logger("[cookies]Deleted cookie: \(cookie.name)")
                }
            }
        }
    }
    
    static func clearCookieStorage() {
        let cookieStore = URLSession.shared.configuration.httpCookieStorage
        cookieStore?.cookies?.forEach { cookie in
            cookieStore?.deleteCookie(cookie)
        }
        logger("[cookies][httpCookieStorage] Deleted all session cookies.")
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
            cookieStore.deleteCookie(cookie)
        }
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
        let uid = self
        if uid.hasPrefix("/u/") {
            return APIService.baseUrlString + uid
        }
        return APIService.baseUrlString + "/u/" + uid
    }
    
    /// 详情主页
    var postDetailUrl: String {
        var tid = self
        let t   = "/t/"
        let base  = APIService.baseUrlString
        let baseT = base + t
        //logger("[tid][detail] tid \(tid)")
        if tid.contains(baseT) {
            return tid
        }
        
        if !tid.allCharactersAreDigits {
            tid = tid.extractNumericPart
        }
        
        //logger("[tid][detail]2 tid \(tid)")
        if !tid.contains(t) {
            tid = t + tid
        }
        
        if tid.contains(base) {
            return tid
        }
        
        if tid.hasPrefix(t) {
            return base + tid
        }
        
        return base + "/" + tid
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



