//
//  TabBarView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

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
    
    var body: some View {
        tabViewContent
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
            .navigationTitle("过早客")

            Group {
                NavigationStack {
                    NodeListView()
                        .navigationTitle(TabBarView.Tab.home.rawValue)
                }
            }
            .tabItem { Label(TabBarView.Tab.node.rawValue, systemImage: TabBarView.Tab.node.icon) }
            .tag(TabBarView.Tab.node)
            
            Group {
                NavigationStack {
                    NotificationsView()
                        .navigationTitle(TabBarView.Tab.noti.rawValue)
                }
            }
            .tabItem { Label(TabBarView.Tab.noti.rawValue, systemImage: TabBarView.Tab.noti.icon) }
            .tag(TabBarView.Tab.noti)
            
            Group {
                NavigationStack {
                    MeView()
                        .navigationTitle(TabBarView.Tab.mine.rawValue)
                }
            }
            .tabItem { Label(TabBarView.Tab.mine.rawValue, systemImage: TabBarView.Tab.mine.icon) }
            .tag(TabBarView.Tab.mine)
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
