//
//  TabBarView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

//struct TabBarVisibilityPreferenceKey: PreferenceKey {
//    static var defaultValue: Bool = false
//    static func reduce(value: inout Bool, nextValue: () -> Bool) {
//        value = nextValue()
//    }
//}

//struct TabBarView: View {
//    @State private var tab: Tab = .home
//    @State private var hideTabBar = false
//    @StateObject  var loginChecker = LoginStateChecker.shared
//    @ObservedObject var notificationManager = NotificationManager.shared
//
//    var body: some View {
//        TabView(selection: $tab) {
//            PostListView()
//                .tabItem {
//                    Label(Tab.home.rawValue, systemImage: .home)
//                }.tag(Tab.home)
//            
//            NodeListView()
//                .tabItem {
//                    Label(Tab.node.rawValue, systemImage: .node)
//                }.tag(Tab.node)
//            
//            NotificationsView()
//                .tabItem {
//                    Label(Tab.noti.rawValue, systemImage: .noti)
//                }.tag(Tab.noti)
//                .badge(notificationManager.unreadCount)
//            
//            MeView()
//                .tabItem {
//                    Label(Tab.mine.rawValue, systemImage: .mine)
//                }.tag(Tab.mine)
//        }
//        .sheet(isPresented: $loginChecker.needLogin) {
//            LoginView(isPresented: $loginChecker.needLogin) {
//                
//            }
//        }
//        .onChange(of: notificationManager.unreadCount) { newValue in
//            updateAppBadge(newValue) 
//        }
//    }
//}

import SwiftUI

// Tab 枚举扩展
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

    @State private var selectedItem: String?
    let items = ["首页", "节点", "通知", "我的"]
        
    var body: some View {
        Group {
//            if UIDevice.current.userInterfaceIdiom == .pad {
//                NavigationSplitView {
//                    SidebarView(selection: $tab)
//              } detail: {
//                  TabContentView(tab: $tab)
//              }
//            } else {
//                TabContentView(tab: $tab)
//            }
            if showTabBar {
                TabContentView(tab: $tab)
            }
        }
        .sheet(isPresented: $loginChecker.needLogin) {
            LoginView(isPresented: $loginChecker.needLogin) {}
        }
        .onChange(of: notificationManager.unreadCount) { newValue in
            updateAppBadge(newValue)
        }
        .onAppear {
            showTabBar = true
        }
        .onDisappear {
            showTabBar = false
        }
    }
    
    static func hideTabBar() {
        UITabBar.appearance().isHidden = true
    }

    static func showTabBar() {
        UITabBar.appearance().isHidden = false
    }
}

// 侧边栏 (iPad)
struct SidebarView: View {
    @Binding var selection: TabBarView.Tab

    var body: some View {
        List {
            ForEach(TabBarView.Tab.allCases, id: \.self) { item in
                let selected = selection == item
                HStack {
                    Image(systemName: item.icon)
                        .foregroundColor(.blue)
                    Text(item.rawValue)
                        .foregroundColor(selected ? .blue: .black)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = item
                }
                .listRowBackground(selected ? Color.gray.opacity(0.2) : Color.clear)
            }
        }
        .navigationTitle("过早客")
    }
}

// 内容视图 (iPhone & iPad detail)
struct TabContentView: View {
    @Binding var tab: TabBarView.Tab
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    var body: some View {
        tabViewContent
    }
    
    private var tabViewContent: some View {
        TabView(selection: $tab) {
            let isiPad = UIDevice.current.userInterfaceIdiom == .pad
            Group {
                if isiPad {
                    PostListView()
                } else {
                    NavigationStack {
                        PostListView()
                            .navigationTitle("过早客")
                    }
                }
            }
            .tabItem { Label(TabBarView.Tab.home.rawValue, systemImage: TabBarView.Tab.home.icon) }
            .tag(TabBarView.Tab.home)
            .navigationTitle("过早客")
            
            Group {
                if isiPad {
                    NodeListView()
                } else {
                    NavigationStack {
                        NodeListView()
                            .navigationTitle(TabBarView.Tab.home.rawValue)
                    }
                }
            }
            .tabItem { Label(TabBarView.Tab.node.rawValue, systemImage: TabBarView.Tab.node.icon) }
            .tag(TabBarView.Tab.node)
            
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    NotificationsView()
                } else {
                    NavigationStack {
                        NotificationsView()
                            .navigationTitle(TabBarView.Tab.noti.rawValue)
                    }
                }
            }
            .tabItem { Label(TabBarView.Tab.noti.rawValue, systemImage: TabBarView.Tab.noti.icon) }
            .tag(TabBarView.Tab.noti)
            
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    MeView()
                } else {
                    NavigationStack {
                        MeView()
                            .navigationTitle(TabBarView.Tab.mine.rawValue)
                    }
                }
            }
            .tabItem { Label(TabBarView.Tab.mine.rawValue, systemImage: TabBarView.Tab.mine.icon) }
            .tag(TabBarView.Tab.mine)
        }
    }
}

///// 􀻧
//case home = "list.bullet.circle"
///// 􀍡
//case node = "ellipsis.circle"
///// 􀌤 评论
//case noti = "bell.badge.fill"
///// 􀉩
//case mine = "person"


//private extension TabBarView {
//    enum Tab: String {
//        case home = "首页", node = "节点", noti = "通知", mine = "我的"
//    }
//}


//#Preview {
//    TabBarView()
//}
