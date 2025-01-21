//
//  AppDelegate.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // 应用启动完成时调用
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("App 启动完成")
        return true
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
