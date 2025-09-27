//
//  GuozaokeApp.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//  https://github.com/sauteam/Guozaoke
//  https://guozaoke.com
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
    
    @StateObject var themeManager = ThemeManager(theme: Theme(primaryColor: .systemBlue, secondaryColor: .red))
    @StateObject private var purchaseAppState = PurchaseAppState()
    @StateObject var navigationManager = NavigationManager()
    @StateObject private var launchCounter = LaunchCounter.shared

    init() {
        //UINavigationBar.appearance().tintColor = UIColor.brown
        applyTabBarBackground()
        _ = ImageCacheManager.shared
    }

    var body: some Scene {
        WindowGroup {
            if isActive {
                GuozaokeApp.tabbarView
                    //.accentColor(.brown)
                    .onAppear {
                        applyAppearance()
                        addNoti()
                        navigationManager.checkWidgetNavigation()
                        
                        // 增加启动次数
                        launchCounter.incrementLaunchCount()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            APIService.saveCookiesToAppGroups()
                            syncVIPStatusToAppGroups()
                        }
                    }
                    //.environmentObject(themeManager)
                    .environmentObject(purchaseAppState)
                    .environmentObject(launchCounter)
                    .overlay(
                        Group {
                            // 评论引导
                            if launchCounter.shouldShowReviewGuide {
                                ReviewGuideView(isPresented: $launchCounter.shouldShowReviewGuide)
                                    .onDisappear {
                                        launchCounter.markReviewGuideShown()
                                    }
                            }
                        }
                    )
                    .sheet(isPresented: $launchCounter.shouldShowPurchaseView) {
                        InAppPurchaseView(isPresented: $launchCounter.shouldShowPurchaseView, purchaseAppState: purchaseAppState)
                            .onDisappear {
                                launchCounter.markPurchasePromptShown()
                            }
                    }
            } else {
                LaunchScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
    
    func syncVIPStatusToAppGroups() {
        let isVIP = purchaseAppState.isPurchased
        if let userDefaults = UserDefaults(suiteName: guozaokeGroup) {
            userDefaults.set(isVIP, forKey: "is_vip_user")
            userDefaults.set(AppInfo.appVersion, forKey: "app_version")
            userDefaults.synchronize()
        }
    }
    
    struct LaunchScreenView: View {
        var body: some View {
            VStack {
                Spacer()
                
                VStack {
                    Image("zaoIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 80, maxHeight: 80)
                        .padding()
                    
                    Text(FestivalDate.getFestivalGreeting())
                        .font(.title)
                        .fontWeight(.thin)
                        .padding()
                        .foregroundColor(Color.primary)
                }
                .offset(y: -30)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
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
            //APIService.clearCookie()
            //handleTokenExpiration()
        }
        NotificationCenter.default.addObserver(forName: .purchaseSuccessNoti, object: nil, queue: .main) { _ in
            purchaseAppState.savePurchaseStatus(isPurchased: true)
        }
        // 处理从 Widget 或外部链接的跳转
        NotificationCenter.default.addObserver(forName: .openAppNotification, object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let user = userInfo as? Dictionary<String, Any> {
                let id = user["id"] as? String ?? ""
                let isUser = user["isUser"] as? Bool ?? false
                
                if isUser {
                    logger("[App] 准备跳转到用户详情: \(id)")
                    // TODO: 实现用户详情跳转逻辑
                } else {
                    logger("[App] 准备跳转到帖子详情: \(id)")
                    navigationManager.navigateToPostDetail(postId: id)
                }
            }
        }
        
        // 定期检查 Widget 导航请求（降低频率）
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            navigationManager.checkWidgetNavigation()
        }
    }
    
    
    func handleTokenExpiration() {
        Task {
            let (success, token) = try await  APIService.fetchLoginPage()
            logger("handleTokenExpiration \(success), \(token)")
        }
    }
}
