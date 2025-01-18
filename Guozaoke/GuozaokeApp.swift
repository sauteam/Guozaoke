//
//  GuozaokeApp.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

@main
struct GuozaokeApp: App {
    init() {
        //UINavigationBar.appearance().tintColor = .brown
        applyTabBarBackground()
    }

    var body: some Scene {
        WindowGroup {
            TabBarView()
                ///.accentColor(.brown)
                ///.environment(\.themeColor, .brown)
        }
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
