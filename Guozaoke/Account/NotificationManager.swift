//
//  NotificationManager.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var unreadCount: Int = 0
    
    private init() {}
}


func scheduleDailyNotification() {
    let content = UNMutableNotificationContent()
    content.title = FestivalDate.todayEvents() ?? "今日最佳"
    content.body  = "看看今天有什么新鲜事~"
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
//     func setupNotificationCategory() {
//         let openAction = UNNotificationAction(identifier: "openAction", title: "打开", options: .foreground)
//         let category = UNNotificationCategory(identifier: "customCategory", actions: [openAction], intentIdentifiers: [], options: .customDismissAction)
//         UNUserNotificationCenter.current().setNotificationCategories([category])
//     }

func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
        if granted {
            print("通知权限已授予")
        } else {
            print("通知权限被拒绝: \(error?.localizedDescription ?? "")")
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

