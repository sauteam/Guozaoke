//
//  TabBarView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

let isiPad   = UIDevice.current.userInterfaceIdiom == .pad
let isiPhone = UIDevice.current.userInterfaceIdiom == .phone

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
    @State private var tab: Tab   = .home
    @StateObject var loginChecker = LoginStateChecker.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init() {
       let appearance = UITabBarAppearance()
       appearance.configureWithDefaultBackground()
       
       UITabBar.appearance().scrollEdgeAppearance = appearance
       UITabBar.appearance().standardAppearance = appearance
       
       if isiPad {
           UITabBar.appearance().isTranslucent = false
       }
   }

    var body: some View {
        TabView(selection: $tab) {
            TabContentView(tab: $tab)
                .tabItem { Label(TabBarView.Tab.home.rawValue, systemImage: TabBarView.Tab.home.icon) }
                .tag(TabBarView.Tab.home)
            
            TabContentView(tab: $tab)
                .tabItem { Label(TabBarView.Tab.node.rawValue, systemImage: TabBarView.Tab.node.icon) }
                .tag(TabBarView.Tab.node)
            
            TabContentView(tab: $tab)
                .tabItem { Label(TabBarView.Tab.noti.rawValue, systemImage: TabBarView.Tab.noti.icon) }
                .tag(TabBarView.Tab.noti)
            
            TabContentView(tab: $tab)
                .tabItem { Label(TabBarView.Tab.mine.rawValue, systemImage: TabBarView.Tab.mine.icon) }
                .tag(TabBarView.Tab.mine)
        }
        .tabViewStyle(.automatic)
        .sheet(isPresented: $loginChecker.needLogin) {
            LoginView(isPresented: $loginChecker.needLogin) {}
        }
        .if(isiPad) { view in
            view.modifier(IPadTabBarModifier())
        }
        .onChange(of: notificationManager.unreadCount) { newValue in
            updateAppBadge(newValue)
        }
    }
}

// Tab 内容视图
struct TabContentView: View {
    @Binding var tab: TabBarView.Tab
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            switch tab {
            case .home:
                PostListView()
                    .navigationTitle(TabBarView.Tab.home.rawValue)
            case .node:
                NodeListView()
                    .navigationTitle(TabBarView.Tab.node.rawValue)
            case .noti:
                NotificationsView()
                    .navigationTitle(TabBarView.Tab.noti.rawValue)
            case .mine:
                MeView()
                    .navigationTitle(TabBarView.Tab.mine.rawValue)
            }
        }
    }
}

// iPad TabBar 修饰符
struct IPadTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.forEach { window in
                        if let tabBarController = window.rootViewController as? UITabBarController {
                            tabBarController.tabBar.frame.size.height = 50
                            tabBarController.tabBar.isHidden = false
                        }
                    }
                }
            }
    }
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// 为子视图添加导航配置
extension View {
    func setupNavigation(title: String) -> some View {
        self.navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                }
            }
    }
}

//// 为子视图添加导航配置
//extension View {
//    func configureNavigationForIPad() -> some View {
//        self.modifier(IPadNavigationModifier())
//    }
//}
//
//struct IPadNavigationModifier: ViewModifier {
//    func body(content: Content) -> some View {
//        content
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    iPadBackButton()
//                }
//            }
//    }
//}
//
//// 自定义返回按钮
//struct iPadBackButton: View {
//    @Environment(\.dismiss) var dismiss
//    
//    var body: some View {
//        Button(action: {
//            dismiss()
//        }) {
//            Image(systemName: "chevron.left")
//                .foregroundColor(.blue)
//        }
//    }
//}


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
