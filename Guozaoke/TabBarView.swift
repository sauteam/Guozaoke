//
//  TabBarView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct TabBarView: View {
    @State private var tab: Tab = .home
    @State private var hideTabBar = false
    @StateObject  var loginChecker = LoginStateChecker.shared
    @ObservedObject var notificationManager = NotificationManager.shared

    var body: some View {
        TabView(selection: $tab) {
            PostListView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: .home)
                }.tag(Tab.home)
            
            NodeListView()
                .tabItem {
                    Label(Tab.node.rawValue, systemImage: .node)
                }.tag(Tab.node)
            
            NotificationsView()
                .tabItem {
                    Label(Tab.node.rawValue, systemImage: .noti)
                }.tag(Tab.noti)
                .badge(notificationManager.unreadCount)
            
            MeView()
                .tabItem {
                    Label(Tab.mine.rawValue, systemImage: .mine)
                }.tag(Tab.mine)
            
//            if hideTabBar {
//                Color(.systemBackground)
//                    .frame(height: 49)
//                    .frame(maxHeight: .infinity, alignment: .bottom)
//                    .ignoresSafeArea()
//            }
        }
        .sheet(isPresented: $loginChecker.needLogin) {
            LoginView(isPresented: $loginChecker.needLogin) {}
        }
        .onChange(of: notificationManager.unreadCount) { newValue in
            updateAppBadge(newValue) 
        }
    }
}

private extension TabBarView {
    enum Tab: String {
        case home = "首页", node = "节点", noti = "通知", mine = "我的"
    }
}


#Preview {
    TabBarView()
}
