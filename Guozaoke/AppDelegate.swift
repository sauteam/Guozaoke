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
import WidgetKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    //var notificationManager = NotificationManager()    
    // 应用启动完成时调用
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        logger("App 启动完成")
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
        logger("App 点击通知了")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        logger("App 进入后台")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        logger("App 进入前台")
        WidgetCenter.shared.reloadAllTimelines()
        logger("[AppDelegate] 触发Widget刷新")
        // 检查Widget导航请求
        NavigationManager.shared.checkWidgetNavigation()
    }
    
    private func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserInterfaceStyle]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            if let url = userActivity.webpageURL {
                if url.host == AppInfo.univerLink {
                    if url.pathComponents.last != nil {
                        let (pathComponent, queryParams) = url.extractPathComponentAndQueryParams
                        logger("[url][id]Extracted path component: \(pathComponent ?? "nil") \n Extracted query params: \(String(describing: queryParams))")
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
           
           logger("[AppDelegate] 处理URL: \(url)")
           // 处理帖子详情跳转
           if path == "/t" {
               if let id = queryItems.first(where: { $0.name == "id" })?.value {
                   let title = queryItems.first(where: { $0.name == "title" })?.value ?? ""
                   logger("[Widget] 跳转到帖子详情: \(id), 标题: \(title)")
                   NotificationCenter.default.post(name: .openAppNotification, object: nil, userInfo: ["id": id, "title": title, "isUser": false])
                   return true
               }
           }
           
           // 处理用户信息跳转
           if path == "/u" {
               if let id = queryItems.first(where: { $0.name == "id" })?.value {
                   logger("[Widget] 跳转到用户详情: \(id)")
                   NotificationCenter.default.post(name: .openAppNotification, object: nil, userInfo: ["id": id, "isUser": true])
                   return true
               }
           }
           
           logger("[url][id] \(path)")
           return true
        }
        return false
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
            let notificationIdentifier = response.notification.request.identifier
            logger("Notification clicked: \(notificationIdentifier)")
            if notificationIdentifier == "dailyReminder" {
                logger("Clicked on daily reminder notification.")
            }
            completionHandler()
        }
}
