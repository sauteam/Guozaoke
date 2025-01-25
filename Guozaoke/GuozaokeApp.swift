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
    @AppStorage("appearanceMode") private var darkMode: String = "system"
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    public static var rootViewController: UIViewController?
    public static var statusBarState: UIStatusBarStyle = .darkContent
    public static var window: UIWindow?
    public static var tabbarView = TabBarView()
    @State private var isActive = false

    init() {
        ///UINavigationBar.appearance().tintColor = themeColor
        applyTabBarBackground()
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            if isActive {
                GuozaokeApp.tabbarView
                    //.accentColor(.brown)
                    ///.environment(\.themeColor, .brown)
                    .onAppear {
                        applyAppearance()
                        addNoti()
                    }
            } else {
                LaunchScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                isActive = true
                            }
                        }
                    }
            }
        }
    }
    
    static func changeStatusBarStyle(_ style: UIStatusBarStyle) {
        guard style != statusBarState else { return }
        statusBarState = style
        rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }
    
}


private extension GuozaokeApp {
    
    struct LaunchScreenView: View {
        var body: some View {
            VStack {
                Image("zaoIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 80, maxHeight: 80)
                    .padding()
                
                Text(getFestivalGreeting())
                    .font(.title)
                    .fontWeight(.thin)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .ignoresSafeArea()
        }
        
        private func getFestivalGreeting() -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let today = dateFormatter.string(from: Date())

            let festivalMessages: [String: String] = [
                "2025-01-28": "除夕快乐！",   // 2025年除夕
                "2025-01-29": "新年快乐！",   // 2025年春节
                "2025-02-03": "元宵节快乐！"  // 2025年元宵节
            ]
            return festivalMessages[today] ?? "欢迎进入过早客"
        }
    }
    
    // MARK TabBar Appearance
    func applyTabBarBackground() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor  = .secondarySystemBackground.withAlphaComponent(0.3)
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

     func applyAppearance() {
        let style: UIUserInterfaceStyle
        switch darkMode {
        case "light":
            style = .light
        case "dark":
            style = .dark
        default:
            style = .unspecified
        }
        
        UIApplication.shared.connectedScenes.forEach { scene in
            if let windowScene = scene as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
    
    func addNoti() {
        NotificationCenter.default.addObserver(forName: .refreshTokenNoti, object: nil, queue: .main) { _ in
            handleTokenExpiration()
        }
    }
    
    func handleTokenExpiration() {
        Task {
            let (success, token) = try await  APIService.fetchLoginPage()
            log("handleTokenExpiration \(success), \(token)")
        }
    }
}
