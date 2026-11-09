//
//  NotificationsParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import Foundation
import SwiftSoup

struct NotificationItem: Identifiable, Equatable {
    let id = UUID()
    let userId: String
    let username: String
    let avatarURL: String
    let topicTitle: String
    let topicLink: String
    let content: String
    let actionText: String
    
    init(
        userId: String = "",
        username: String,
        avatarURL: String,
        topicTitle: String,
        topicLink: String,
        content: String,
        actionText: String = " 回复了你的主题 "
    ) {
        self.userId = userId.isEmpty ? username : userId
        self.username = username
        self.avatarURL = avatarURL
        self.topicTitle = topicTitle
        self.topicLink = topicLink
        self.content = content
        self.actionText = actionText
    }
}

class NotificationsParser: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading   = false
    @Published var errorMessage  = ""
    private var hasFetched = false  // 避免重复请求

    func fetchNotificationsRefresh() async {
        hasFetched = false
        await fetchNotifications()
    }
    
    func fetchNotifications() async {
        guard !hasFetched else { return }
            hasFetched = true
        runInMain {
            self.isLoading = true
        }
        do {
            let response = try await APIService.getNotifications(url: APIService.notifications)
            //logger("Response: \(response)")
            parseHTML(html: response)
        } catch {
            errorMessage = "发布失败: \(error.localizedDescription)"
        }
        
        runInMain {
            self.isLoading = false
        }
    }
    
    private func parseHTML(html: String) {
        do {
            let document = try SwiftSoup.parse(html)
            let notificationItems = try document.select(".notification-item")
            
            var newNotifications: [NotificationItem] = []
            
            for item in notificationItems {
                var userId = ""
                var displayName = ""
                
                // 优先查找用户链接（支持 .gzk-display-name、a[href^='/u/']、a[href*='/u/']）
                let userLinks = try item.select(".title a[href^='/u/'], a.gzk-display-name, .title a[href*='/u/']")
                if let userLink = userLinks.first() {
                    let dataUsername = try userLink.attr("data-username").trimmingCharacters(in: .whitespacesAndNewlines)
                    let dataMentionUser = try userLink.attr("data-gzk-mention-user").trimmingCharacters(in: .whitespacesAndNewlines)
                    let href = try userLink.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !dataUsername.isEmpty {
                        userId = dataUsername
                    } else if !dataMentionUser.isEmpty {
                        userId = dataMentionUser
                    } else if href.contains("/u/") {
                        let afterU = href.components(separatedBy: "/u/").last ?? ""
                        userId = afterU.components(separatedBy: CharacterSet(charactersIn: "?#/")).first ?? ""
                    }
                    
                    let dataDisplayName = try userLink.attr("data-display-name").trimmingCharacters(in: .whitespacesAndNewlines)
                    let bdiText = try userLink.select("bdi").text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let linkText = try userLink.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !dataDisplayName.isEmpty {
                        displayName = dataDisplayName
                    } else if !bdiText.isEmpty {
                        displayName = bdiText
                    } else if !linkText.isEmpty {
                        displayName = linkText
                    }
                }
                
                // 兜底：从包裹头像的链接中提取 userId
                if userId.isEmpty {
                    if let avatarLink = try item.select("a[href^='/u/'], a[href*='/u/']").first()?.attr("href") {
                        let afterU = avatarLink.components(separatedBy: "/u/").last ?? ""
                        userId = afterU.components(separatedBy: CharacterSet(charactersIn: "?#/")).first ?? ""
                    }
                }
                
                if displayName.isEmpty {
                    displayName = !userId.isEmpty ? userId : "未知用户"
                }
                if userId.isEmpty {
                    userId = displayName
                }
                
                var avatarURL = try item.select(".avatar").attr("src")
                if avatarURL.isEmpty {
                    avatarURL = try item.select("img.avatar").attr("src")
                }
                if avatarURL.isEmpty {
                    avatarURL = try item.select("a.gzk-display-name").attr("data-avatar")
                }
                
                let topicTitle = try item.select(".title a[href^='/t/']").text()
                let topicLink = try item.select(".title a[href^='/t/']").attr("href")
                
                var content = ""
                if let pElem = try item.select(".content p").first() {
                    content = try pElem.html()
                } else if let contentElem = try item.select(".content").first() {
                    content = try contentElem.html()
                } else {
                    content = try item.select(".content").text()
                }
                
                var actionText = " 回复了你的主题 "
                let titleText = try item.select(".title").text()
                if titleText.contains("提到了你") {
                    actionText = " 提到了你 "
                } else if titleText.contains("回复了你的主题") {
                    actionText = " 回复了你的主题 "
                } else if titleText.contains("感谢了你的主题") {
                    actionText = " 感谢了你的主题 "
                } else if titleText.contains("感谢了你的回复") {
                    actionText = " 感谢了你的回复 "
                } else if titleText.contains("收藏了你的主题") {
                    actionText = " 收藏了你的主题 "
                }
                
                let notification = NotificationItem(
                    userId: userId,
                    username: displayName,
                    avatarURL: avatarURL,
                    topicTitle: topicTitle,
                    topicLink: topicLink,
                    content: content,
                    actionText: actionText
                )
                newNotifications.append(notification)
            }
            
            DispatchQueue.main.async {
                self.notifications = newNotifications
            }
            
        } catch {
            logger("解析错误: \(error.localizedDescription)")
        }
    }
    
}
