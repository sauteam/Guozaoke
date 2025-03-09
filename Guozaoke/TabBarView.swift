//
//  TabBarView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import Combine

let isiPad   = UIDevice.current.userInterfaceIdiom == .pad
let isiPhone = UIDevice.current.userInterfaceIdiom == .phone

extension TabBarView {
    enum Tab: String, CaseIterable {
        case home = "首页", node = "节点", noti = "通知", mine = "我的"
        var icon: String {
            switch self {
            case .home: return "list.bullet.circle.fill"
            case .node: return "ellipsis.circle.fill"
            case .noti: return "bell.fill"
            case .mine: return "person.fill"
            }
        }
    }
}

struct TabBarView: View {
    @State private var tab: Tab = .home
    @State private var hideTabBar = false
    @StateObject var loginChecker = LoginStateChecker.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showTabBar = true
    @State private var showLoginView = false

    @State private var selectedItem: String?
    let items = ["首页", "节点", "通知", "我的"]
        
    var body: some View {
        Group {
            if isiPad {
                TabContentView(tab: $tab)
            } else {
                if showTabBar {
                    TabContentView(tab: $tab)
                }
            }
        }
        .sheet(isPresented: $loginChecker.needLogin) {
            LoginView(isPresented: $loginChecker.needLogin) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginViewAlertNoti)) { _ in
            loginChecker.needLogin = true
            showLoginView = true
            print("[login]登录提示框 needLogin \(loginChecker.needLogin)")
        }
        .onChange(of: notificationManager.unreadCount) { newValue in
            updateAppBadge(newValue)
        }
        .onAppear {
            if isiPhone {
                showTabBar = true
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .loginViewAlertNoti, object: nil)
            if isiPhone {
                showTabBar = false
            }
        }
    }
    
    static func hideTabBar() {
        if isiPhone {
            UITabBar.appearance().isHidden = true
        }
    }

    static func showTabBar() {
        if isiPhone {
            UITabBar.appearance().isHidden = false
        }
    }
}


struct TabContentView: View {
    @Binding var tab: TabBarView.Tab
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PostListViewModel()

    @State private var lastSelectedTab: TabBarView.Tab?
    @State private var lastTapTime: Date?
    @State private var lastRefreshTime: Date?
        
    var body: some View {
        tabViewContent
            .onTabChange(of: $tab) { newValue in
                handleTabChange(newTab: newValue)
            }
    }
    
    private var tabViewContent: some View {
        TabView(selection: $tab) {
            Group {
                NavigationStack {
                    PostListView(viewModel: viewModel)
                }
            }
            .tabItem { Label(TabBarView.Tab.home.rawValue, systemImage: TabBarView.Tab.home.icon) }
            .tag(TabBarView.Tab.home)
            // 在NavigationStack 不响应onTapGesture 事件
//            .onTapGesture(count: 2) {
//                log("[tab]\(TabBarView.Tab.home.rawValue) tap 2")
//            }


            Group {
                NavigationStack {
                    NodeListView()
                }
            }
            .tabItem { Label(TabBarView.Tab.node.rawValue, systemImage: TabBarView.Tab.node.icon) }
            .tag(TabBarView.Tab.node)
            
            Group {
                NavigationStack {
                    NotificationsView()
                }
            }
            .tabItem { Label(TabBarView.Tab.noti.rawValue, systemImage: TabBarView.Tab.noti.icon) }
            .tag(TabBarView.Tab.noti)
            
            Group {
                NavigationStack {
                    MeView()
                }
            }
            .tabItem { Label(TabBarView.Tab.mine.rawValue, systemImage: TabBarView.Tab.mine.icon) }
            .tag(TabBarView.Tab.mine)
        }
    }
}

private extension TabContentView {
    
    private func handleTabChange(newTab: TabBarView.Tab) {
        let now = Date()
        //log("[tab] \(newTab.rawValue) double tap")
        if let lastTab = lastSelectedTab, let lastTime = lastTapTime, lastTab == newTab {
            if now.timeIntervalSince(lastTime) < 0.5 {
                handleDoubleTap(for: newTab)
            }
        }
        lastSelectedTab = newTab
        lastTapTime = now
    }
    
    private func handleDoubleTap(for tab: TabBarView.Tab) {
        let now = Date()
        if let lastRefreshTime = lastRefreshTime {
            if now.timeIntervalSince(lastRefreshTime) >= 10 {
                refreshTab(tab)
                self.lastRefreshTime = now
            } else {
                print("[tab] \(tab.rawValue) double tap ignored (wait 60 seconds)")
            }
        } else {
            refreshTab(tab)
            self.lastRefreshTime = now
        }
    }
    
    private func refreshTab(_ tab: TabBarView.Tab) {
        //print("[tab] \(tab.rawValue) double tap - refreshing...")
        switch tab {
        case .home:
            
            break
        case .node:
            break
        case .noti:
            break
        case .mine:
            break
        }
    }
}

// MARK: - Tab Change Handler
extension View {
    func onTabChange(of tab: Binding<TabBarView.Tab>, perform action: @escaping (TabBarView.Tab) -> Void) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                self.onChange(of: tab.wrappedValue) { oldValue, newValue in
                    log("[tab][onTabChange] \(oldValue.rawValue) -> \(newValue.rawValue)")
                    action(newValue)
                }
            } else {
                self.onReceive(Just(tab.wrappedValue), perform: action)
            }
        }
        .background(
            TabTapView(tab: tab, action: action)
                .allowsHitTesting(true)
        )
    }
}

struct TabTapView: View {
    @Binding var tab: TabBarView.Tab
    let action: (TabBarView.Tab) -> Void
    
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                //log("[tab][TabTapView] \(tab.rawValue) tapped")
                action(tab)
            }
    }
}

// 侧边栏 (iPad)
//struct SidebarView: View {
//    @Binding var selection: TabBarView.Tab
//
//    var body: some View {
//        List {
//            ForEach(TabBarView.Tab.allCases, id: \.self) { item in
//                let selected = selection == item
//                HStack {
//                    Image(systemName: item.icon)
//                        .foregroundColor(.blue)
//                    Text(item.rawValue)
//                        .foregroundColor(selected ? .blue: .black)
//                }
//                .contentShape(Rectangle())
//                .onTapGesture {
//                    selection = item
//                }
//                .listRowBackground(selected ? Color.gray.opacity(0.2) : Color.clear)
//            }
//        }
//    }
//}
