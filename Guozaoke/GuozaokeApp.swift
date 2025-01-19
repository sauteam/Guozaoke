//
//  GuozaokeApp.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//
// 过早客是源自武汉的高端社交网络，这里有关于创业、创意、IT、金融等最热话题的交流，也有招聘问答、活动交友等最新资讯的发布。
// 过早客，光谷社区，武汉，guanggu，光谷软件园，guozaoke.com，guanggoo.com，光谷，创业，社区

import SwiftUI

@main
struct GuozaokeApp: App {
    public static var rootViewController: UIViewController?
    public static var statusBarState: UIStatusBarStyle = .darkContent
    public static var window: UIWindow?
    public static var tabbarView = TabBarView()
    init() {
        //UINavigationBar.appearance().tintColor = .brown
        applyTabBarBackground()
    }

    var body: some Scene {
        WindowGroup {
            GuozaokeApp.tabbarView
                ///.accentColor(.brown)
                ///.environment(\.themeColor, .brown)
        }
    }
    
    static func changeStatusBarStyle(_ style: UIStatusBarStyle) {
        guard style != statusBarState else { return }
        statusBarState = style
        rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }
}


extension GuozaokeApp {
    // MARK TabBar Appearance
    func applyTabBarBackground() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor  = .secondarySystemBackground.withAlphaComponent(0.3)
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
