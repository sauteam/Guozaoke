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

