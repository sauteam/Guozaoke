//
//  NotificationManager.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import SwiftUI

// MARK: - NotificationManager

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var unreadCount: Int = 0
    /// 是否有通知权限 用户关闭或打开
    @Published var notificationGranted: Bool = false
    private init() {}
    
    func cancelDailyNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        print("[noti]设置取消推送通知了")
    }

    func scheduleDailyNotification() {
        if UserDefaultsKeys.settingPushNotificationsEnabled == false {
            log("[noti]设置关闭推送通知了")
        }
        
        let content = UNMutableNotificationContent()
        content.title = "过早客"
        content.body  = FestivalDate.todayEvents() ?? "看看今天在聊啥"
        content.sound = .defaultCritical
        content.badge = 1

        var dateComponents    = DateComponents()
        dateComponents.hour   = 12
        dateComponents.minute = 10

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for every day at 12:00 PM.")
            }
        }
    }

    // 设置通知类别（用于自定义按钮等）
    func setupNotificationCategory() {
         let openAction = UNNotificationAction(identifier: "openAction", title: "打开", options: .foreground)
         let category = UNNotificationCategory(identifier: "customCategory", actions: [openAction], intentIdentifiers: [], options: .customDismissAction)
         UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { [weak self] granted, error in
            if granted {
                print("通知权限已授予")
            } else {
                print("通知权限被拒绝: \(error?.localizedDescription ?? "")")
            }
            self?.notificationGranted = granted
        }
    }
}


func updateAppBadge(_ count: Int) {
    DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = count
    }
}

func clearAppBadge() {
    DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}


