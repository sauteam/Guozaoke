//
//  AppDelegate.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

// com.guozaoke.app.ios
// 

import UIKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {
    //var notificationManager = NotificationManager()

    // 应用启动完成时调用
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("App 启动完成")
        requestNotificationPermission()
        scheduleDailyNotification()
        UNUserNotificationCenter.current().delegate = self
        updateAppBadge(0)
        if #available(iOS 18.0, *) {
            AppReviewRequest.devReview()
            AppReviewRequest.clearReviewData()
            AppReviewRequest.requestReviewIfAppropriate()
        }
        return true
    }
    
    private func application(_ application: UIApplication, didReceive notification: UNNotification) {
        print("App 点击通知了")
    }

    // 进入后台
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App 进入后台")
    }

    // 进入前台
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App 进入前台")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            let notificationIdentifier = response.notification.request.identifier
            print("Notification clicked: \(notificationIdentifier)")
            if notificationIdentifier == "dailyReminder" {
                print("Clicked on daily reminder notification.")
            }
            completionHandler()
        }
}
