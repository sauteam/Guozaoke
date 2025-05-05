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
        NotificationManager.shared.requestNotificationPermission()
        NotificationManager.shared.scheduleDailyNotification()
        UNUserNotificationCenter.current().delegate = self
        updateAppBadge(0)
        if #available(iOS 18.0, *) {
#if DEBUG
            AppReviewRequest.clearReviewData()
            AppReviewRequest.devReview()
#else
            AppReviewRequest.requestReviewIfAppropriate()
#endif
            
        }
        return true
    }
    
    private func application(_ application: UIApplication, didReceive notification: UNNotification) {
        print("App 点击通知了")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App 进入后台")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App 进入前台")
    }
    
    private func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserInterfaceStyle]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            if let url = userActivity.webpageURL {
                if url.host == AppInfo.univerLink {
                    if url.pathComponents.last != nil {
                        let (pathComponent, queryParams) = url.extractPathComponentAndQueryParams
                        log("[url][id]Extracted path component: \(pathComponent ?? "nil") \n Extracted query params: \(String(describing: queryParams))")
                    }
                }
            }
        }
        return true
    }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == AppInfo.scheme {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
               return false
           }
           let path = components.path
           let queryItems = components.queryItems ?? []
           if path == "/t" || path == "/u" {
               if let id = queryItems.first(where: { $0.name == "id" })?.value {
                   let isUserInfo = path == "/u"
                   NotificationCenter.default.post(name: .openAppNotification, object: nil, userInfo: ["id": id, "isUser": isUserInfo])
                   return true
               }
           }
           log("[url][id] \(path)")
           return true
        }
        return false
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
