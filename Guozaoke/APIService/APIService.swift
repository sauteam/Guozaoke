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


struct NoMoreDataTitle {
    static let nodata     = "没有数据"
    static let homeList   = "已经到底啦"
    static let notiList   = "没有通知消息"
    static let commentList = "评论到底了，要不要发一条"
}

/// 首页tab 
enum PostListType: String, CaseIterable {
    case hot      = "默认"
    case latest   = "最新"
    case elite    = "精华"
    case interest = "兴趣"
    case follows  = "关注"
    var url: String {
        switch self {
        case .hot:
            return ""
        case .latest:
            return "/?tab=latest"
        case .elite:
            return "/?tab=elite"
        case .interest:
            return "/?tab=interest"
        case .follows:
            return "/?tab=follows"
        }
    }
}

enum MyTopicEnum: String {
    case collections = "favorites"
    case follows = "topics"
    case browse = "replies"
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
    static let forgotUrl     = baseUrlString + "/forgotUrl"
    static let notifications = "/notifications"
    static let favorites     = "/favorites"
    private init() {}
    
    static func getNotifications(url: String) async throws -> String {
        let response: String = try await NetworkManager.shared.get(url)
        return response
    }
    
    static func sendPost(
        url: String,
        title: String,
        content: String
    ) async throws -> String {
        // 构造参数
        let xsrfToken = AccountState.token()
        if xsrfToken.isEmpty {
            let _  = LoginStateChecker.clearUserInfo()
        }
        let parameters: Parameters = [
            "title": title,
            "content": content,
            "_xsrf": xsrfToken
        ]
        
        // 构造头部
        let headers: HTTPHeaders = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
            "Accept-Encoding": "gzip, deflate",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36",
            "Referer": url
        ]
        
        // 调用通用请求方法
        let response: String = try await NetworkManager.shared.post(url, parameters: parameters, headers: headers)
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
            log("[save]Saved Cookie: \(cookie.name) = \(cookie.value)")
        }
    }
    
    static func cookies() -> [HTTPCookie]? {
        let cookies = HTTPCookieStorage.shared.cookies
        //log("[cookies]\(cookies)")
        return cookies
    }
    
    static func clearCookiesForDomain() {
        if let cookies = cookies() {
            for cookie in cookies {
                if cookie.domain.contains("guozaoke.com") {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                    log("[cookies]Deleted cookie: \(cookie.name)")
                }
            }
        }
    }
    
    static func clearCookieStorage() {
        let cookieStore = URLSession.shared.configuration.httpCookieStorage
        cookieStore?.cookies?.forEach { cookie in
            cookieStore?.deleteCookie(cookie)
        }
        log("[cookies][httpCookieStorage] Deleted all session cookies.")
    }
    
    static func clearWebViewCookies() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: [WKWebsiteDataTypeCookies]) { records in
            records.forEach { record in
                dataStore.removeData(ofTypes: [WKWebsiteDataTypeCookies], for: [record]) {
                    print("Deleted WebView cookies for \(record.displayName)")
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
                log("\(tag) --> cookie: \(cookie.name), \(cookie.value)")
            }
        }
    }
}

extension String {
    /// 后面拼接参数
    func addUrl() -> String {
        return APIService.baseUrlString + self
    }
    /// 个人主页
    func userProfileUrl() -> String {
        let uid = self
        if uid.hasPrefix("/u/") {
            return APIService.baseUrlString + uid
        }
        return APIService.baseUrlString + "/u/" + uid
    }
    /// 详情主页
    func postDetailUrl() -> String {
        let uid = self
        if uid.hasPrefix("/") {
            return APIService.baseUrlString + uid
        }
        return APIService.baseUrlString + "/" + uid
    }
    
    /// /node/IT => /t/create/IT
    func createPostUrl() -> String {
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



