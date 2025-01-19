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
    static let homeList   = "已经到底啦"
    static let commentList = "评论到底了，要不要发一条"
}

enum PostListType: String, CaseIterable {
    case hot     = "默认"
    case latest  = "最新"
    case elite   = "精华"
    case follows = "关注"
    //case node   = "节点"

    
    var url: String {
        switch self {
        case .hot:
            return ""
        case .latest:
            return "/?tab=latest"
        case .elite:
            return "/?tab=elite"
        case .follows:
            return "/?tab=follows"
//        case .node:
//            return "/nodes"
        }
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
    static let forgotUrl     = baseUrlString + "/forgotUrl"
    private init() {}
    
    
    static func sendPost(
            url: String,
            title: String,
            content: String
        ) async throws -> String {
            // 构造参数
            let xsrfToken = AccountState.token()
            if xsrfToken.isEmpty {
                let _  = LoginStateChecker.unLoginState()
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
                "Accept-Encoding": "gzip, deflate"
            ]
            
            // 调用通用请求方法
            let response: String = try await NetworkManager.shared.post(url, parameters: parameters, headers: headers)
            return response
        }
}


extension APIService {
    
    private func printCookies(tag: String = .empty) {
        let storage = HTTPCookieStorage.shared
        if let cookies = storage.cookies {
            for cookie in cookies {
                log("\(tag) --> cookie: \(cookie.name), \(cookie.value)")
            }
        }
    }

    func clearCookie() {
        let cookieStore = HTTPCookieStorage.shared
        for cookie in cookieStore.cookies ?? [] {
            cookieStore.deleteCookie(cookie)
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



