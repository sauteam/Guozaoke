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

    var body: some View {
        TabView(selection: $tab) {
            PostListView()
                .tabItem {
                    Label("首页", systemImage: .home)
                }.tag(Tab.home)
            
            NodeListView()
                .tabItem {
                    Label("节点", systemImage: .node)
                }.tag(Tab.node)
            
            MessageListView()
                .tabItem {
                    Label("通知", systemImage: .noti)
                }.tag(Tab.noti)
            
            MeView(userId: AccountState.userName)
                .tabItem {
                    Label("我的", systemImage: .mine)
                }.tag(Tab.me)
            
            if hideTabBar {
                Color(.systemBackground)
                    .frame(height: 49)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $loginChecker.needLogin) {
            LoginView(isPresented: $loginChecker.needLogin) {
                
            }
        }
    }
}

private extension TabBarView {
    enum Tab: String {
        case home = "首页", node = "节点", noti = "通知", me = "我的"
    }
}


#Preview {
    TabBarView()
}
