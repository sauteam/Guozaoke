//
//  NetworkManager.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI
import Alamofire
import SwiftSoup
import JDStatusBarNotification
import JavaScriptCore

// MARK: - 网络请求管理器
class NetworkManager: ObservableObject {
    
    struct BaseResponse: Codable {
        let message: String
        let success: Bool?
    }
    
    static let shared = NetworkManager()
    private init() {}
    
    // MARK: - 防爬挑战处理 (阿里云 ESA / WAF)
    
    /// 判断是否命中阿里云 ESA 防爬 JS 挑战
    private func isAntiBotChallenge(html: String, response: HTTPURLResponse?) -> Bool {
        if html.contains("acw_sc__v2") && html.contains("arg1") {
            return true
        }
        if let headers = response?.allHeaderFields as? [String: Any],
           let errorHeader = headers["x-tengine-error"] as? String,
           errorHeader.contains("denied by http_custom") {
            return true
        }
        return false
    }
    
    /// 利用 JavaScriptCore 执行防爬 JS 脚本，计算出 acw_sc__v2 Cookie
    private func solveAntiBotChallenge(html: String) -> String? {
        guard let context = JSContext() else { return nil }
        
        context.exceptionHandler = { _, exp in
            logger("[AntiBot] JS执行异常: \(String(describing: exp))")
        }
        
        let shim = """
        var cookieResult = "";
        var document = {
            location: {
                reload: function() {}
            }
        };
        Object.defineProperty(document, "cookie", {
            set: function(val) {
                cookieResult = val;
            },
            get: function() {
                return cookieResult;
            }
        });
        """
        context.evaluateScript(shim)
        
        var jsCode = html
        if let scriptStart = html.range(of: "<script>"),
           let scriptEnd = html.range(of: "</script>") {
            jsCode = String(html[scriptStart.upperBound..<scriptEnd.lowerBound])
        } else {
            jsCode = jsCode
                .replacingOccurrences(of: "<html><script>", with: "")
                .replacingOccurrences(of: "</script></html>", with: "")
        }
        
        context.evaluateScript(jsCode)
        
        if let cookieValue = context.objectForKeyedSubscript("cookieResult")?.toString(), !cookieValue.isEmpty {
            for part in cookieValue.components(separatedBy: ";") {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("acw_sc__v2=") {
                    return String(trimmed.dropFirst("acw_sc__v2=".count))
                }
            }
        }
        return nil
    }
    
    /// 保存从响应头返回的 Cookies (如 acw_tc, cdn_sec_tc 等)
    private func saveCookiesFromResponse(_ response: HTTPURLResponse?) {
        guard let httpResponse = response, let responseUrl = httpResponse.url else { return }
        let headerFields = httpResponse.allHeaderFields as? [String: String] ?? [:]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseUrl)
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        APIService.saveCookiesToAppGroups()
    }
    
    /// 将解算出的 acw_sc__v2 存入 HTTPCookieStorage 并同步至 App Groups
    private func saveAntiBotCookie(value: String) {
        let domains = ["www.guozaoke.com", ".guozaoke.com"]
        for domain in domains {
            let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                .domain: domain,
                .path: "/",
                .name: "acw_sc__v2",
                .value: value,
                .expires: Date(timeIntervalSinceNow: 7200) // 2小时有效期
            ]
            if let cookie = HTTPCookie(properties: cookieProperties) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
        APIService.saveCookiesToAppGroups()
    }
    
    func request(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil,
        showErrorToast: Bool = true,
        retryCount: Int = 0
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var allUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !allUrl.hasPrefix("http://") && !allUrl.hasPrefix("https://") {
                let path = allUrl.hasPrefix("/") ? allUrl : "/" + allUrl
                allUrl = APIService.baseUrlString + path
            }
            logger("[request] \(url) allUrl \(allUrl)")
            var validURL = URL(string: allUrl)
            if validURL == nil {
                if let encoded = allUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    validURL = URL(string: encoded)
                }
            }
            guard let finalURL = validURL else {
                 continuation.resume(throwing: URLError(.badURL))
                 return
            }
     
            // 默认头部 - 使用iOS Safari User-Agent，并在后面添加应用标识
            var defaultHeaders: HTTPHeaders = [
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                "X-Requested-With": "XMLHttpRequest",
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 MyApp/1.0",
                "Cookie": APIService.getStoredCookies()
            ]

            if method == .post {
                defaultHeaders.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
                defaultHeaders.add(name: "Origin", value: APIService.baseUrlString)
                let token = AccountState.token()
                if !token.isEmpty {
                    defaultHeaders.add(name: "X-Xsrftoken", value: token)
                }
            }

            if let headers = headers {
                headers.forEach { defaultHeaders.update($0) }
            }
            
            AF.request(
                finalURL,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: defaultHeaders
            )
            .validate()
            .responseString { [weak self] response in
                guard let self = self else { return }
                
                // 保存响应头中的所有 Cookies (包括 acw_tc 等)
                self.saveCookiesFromResponse(response.response)
                
                switch response.result {
                case .success(let string):
                    // 检查是否命中阿里云 ESA 防爬挑战
                    if self.isAntiBotChallenge(html: string, response: response.response) {
                        logger("[AntiBot] 命中阿里云ESA防爬挑战，准备解算 acw_sc__v2...")
                        if let solvedValue = self.solveAntiBotChallenge(html: string) {
                            logger("[AntiBot] 成功解算 acw_sc__v2: \(solvedValue)")
                            self.saveAntiBotCookie(value: solvedValue)
                            APIService.saveCookiesToAppGroups()
                            
                            if retryCount < 2 {
                                logger("[AntiBot] 携带新Cookie自动重试请求: \(url) (重试次数: \(retryCount + 1))")
                                Task {
                                    do {
                                        let retryResult = try await self.request(
                                            url,
                                            method: method,
                                            parameters: parameters,
                                            encoding: encoding,
                                            headers: headers,
                                            showErrorToast: showErrorToast,
                                            retryCount: retryCount + 1
                                        )
                                        continuation.resume(returning: retryResult)
                                    } catch {
                                        continuation.resume(throwing: error)
                                    }
                                }
                                return
                            }
                        } else {
                            logger("[AntiBot] 解算失败")
                        }
                    }
                    continuation.resume(returning: string)
                case .failure(let error):
                    logger("[request][error] \(parameters ?? [:]) \(headers ?? [:])  \(error) \(response)")
                    continuation.resume(throwing: error)
                    
                    if showErrorToast {
                        let statusCode = response.response?.statusCode ?? 0
                        var desc = "出现错误❌: [\(statusCode)]"
                        
                        if statusCode == 404 {
                            desc = "该内容不存在或已被删除 (404)"
                        } else if statusCode == 403 {
                            desc = "访问被拒绝或登录已过期 (403)"
                            if !LoginStateChecker.isLogin {
                                desc = needLoginTextCanDo
                                LoginStateChecker.LoginStateHandle()
                            }
                            logger("[403]重新登录处理  refreshTokenNoti \(url)")
                            NotificationCenter.default.post(name: .refreshTokenNoti, object: nil)
                        } else if statusCode == 500 {
                            desc = "服务器开小差了，请稍后再试 (500)"
                        } else if !LoginStateChecker.isLogin {
                            desc = needLoginTextCanDo
                            LoginStateChecker.LoginStateHandle()
                        }
                        ToastView.warningToast(desc)
                    }
                }
            }
        }
    }    
    func post(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        showErrorToast: Bool = true
    ) async throws -> String {
        try await request(url, method: .post, parameters: parameters, headers: headers, showErrorToast: showErrorToast)
    }
    
    func postJSON(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        showErrorToast: Bool = true
    ) async throws -> String {
        var jsonHeaders: HTTPHeaders = headers ?? [:]
        jsonHeaders.update(name: "Content-Type", value: "application/json")
        jsonHeaders.update(name: "Accept", value: "application/json")
        return try await request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: jsonHeaders, showErrorToast: showErrorToast)
    }
    
    func get(
        _ url: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        showErrorToast: Bool = true
    ) async throws -> String {
        try await request(url, method: .get, parameters: parameters, headers: headers, showErrorToast: showErrorToast)
    }
}

// MARK: - 网络错误类型
enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .requestFailed(let message):
            return "请求失败: \(message)"
        case .invalidResponse:
            return "无效的响应"
        case .parseError:
            return "数据解析错误"
        }
    }
}
