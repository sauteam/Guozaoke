//
//  NotificationsParser.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import Foundation
import SwiftSoup

struct NotificationItem: Identifiable {
    let id = UUID()
    let username: String
    let avatarURL: String
    let topicTitle: String
    let topicLink: String
    let content: String
}

class NotificationsParser: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var isLoading   = false
    @Published var errorMessage  = ""
    private var hasFetched = false  // 避免重复请求

    func fetchNotifications() async {
        guard !hasFetched else { return }
            hasFetched = true
        runInMain {
            self.isLoading = true
        }
        do {
            let response = try await APIService.getNotifications(url: APIService.notifications)
            //print("Response: \(response)")
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
                let username = try item.select(".title a").first()?.text() ?? "未知用户"
                let avatarURL = try item.select(".avatar").attr("src")
                let topicTitle = try item.select(".title a[href^='/t/']").text()
                let topicLink = try item.select(".title a[href^='/t/']").attr("href")
                let content = try item.select(".content p").text()
                
                let notification = NotificationItem(username: username, avatarURL: avatarURL, topicTitle: topicTitle, topicLink: topicLink, content: content)
                newNotifications.append(notification)
            }
            
            DispatchQueue.main.async {
                self.notifications = newNotifications
            }
            
        } catch {
            print("解析错误: \(error.localizedDescription)")
        }
    }
    
}
