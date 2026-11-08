import SwiftUI

struct SettingView: View {
    
    enum ActiveSheet: Identifiable {
        case logout, login
        var id: Int {
            switch self {
            case .logout: return 1
            case .login: return 2
            }
        }
    }

    
    @State private var showLogoutSheet = false
    @State private var showLoginView = false
    @State private var presentedSheet: ActiveSheet?
    @EnvironmentObject var themeManager: ThemeManager  
    @Environment(\.dismiss) var dismiss

    @AppStorage(UserDefaultsKeys.pushNotificationsEnabled) private var pushNotificationsEnabled: Bool = true
    @AppStorage(UserDefaultsKeys.hapticFeedbackEnabled) private var hapticFeedbackEnabled: Bool = true
    @AppStorage(UserDefaultsKeys.homeListRefreshEnabled) private var homeListRefreshEnabled: Bool = false
    @AppStorage(UserDefaultsKeys.hiddenTabView) private var hiddenTabView: Bool = false

    
    var body: some View {
        GeometryReader { proxy in
            let isDual = GKDisplayMetrics.isDualColumnDisplay(size: proxy.size)
            let safeTrailing = GKDisplayMetrics.safeTabBarTrailingInset(
                geometryTrailing: proxy.safeAreaInsets.trailing
            )
            let safeBottom = GKDisplayMetrics.safeTabBarBottomInset(
                geometryBottom: proxy.safeAreaInsets.bottom
            )
            
            if isDual {
                // 折叠屏展开横屏：偏好设置与账号管理双窗格 (Dual Pane Settings)
                HStack(spacing: 0) {
                    // 左窗格：基础设置与交互偏好
                    Form {
                        preferencesSection
                    }
                    .listStyle(InsetGroupedListStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, safeBottom)
                    
                    // 中缝避让隔离 (32pt)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: GKDisplayMetrics.hingeExclusionRadius * 2)
                        .allowsHitTesting(false)
                    
                    // 右窗格：账号管理与安全
                    Form {
                        accountSection
                    }
                    .listStyle(InsetGroupedListStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, safeTrailing)
                    .padding(.bottom, safeBottom)
                }
                .environment(\.isGKDualColumn, true)
            } else {
                Form {
                    preferencesSection
                    accountSection
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.isGKDualColumn, false)
            }
        }
        .tabbarToolBar()
        .sheet(item: $presentedSheet) { sheetType in
            switch sheetType {
            case .logout:
                LogoutConfirmationSheet(presentedSheet: $presentedSheet)
                    .presentationDetents([.height(230)])
            case .login:
                LoginView(isPresented: .constant(true)) {
                    presentedSheet = nil
                }
            }
        }
        .navigationTitleStyle("设置")
    }
    
    // MARK: - Grouped Setting Sections
    
    @ViewBuilder
    private var preferencesSection: some View {
        Section {
            Toggle(isOn: $pushNotificationsEnabled) {
                Text(pushNotificationsEnabled ? "一天一条" : "不推送消息")
                    .titleFontStyle()
            }
            .onChange(of: pushNotificationsEnabled) { newValue in
                if !NotificationManager.shared.notificationGranted {
                    NotificationManager.shared.requestNotificationPermission()
                    runInMain(delay: 1) {
                        pushNotificationsEnabled = NotificationManager.shared.notificationGranted
                    }
                    UIApplication.toSettingUrl()
                    return
                }
                handlePushNotificationToggle(newValue: newValue)
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Toggle(isOn: $hapticFeedbackEnabled) {
                Text("触感反馈")
                    .titleFontStyle()
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Toggle(isOn: $homeListRefreshEnabled) {
                Text("首页刷新")
                    .titleFontStyle()
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Toggle(isOn: $hiddenTabView) {
                Text(hiddenTabView ? "隐藏TabView" : "一直显示TabView")
                    .titleFontStyle()
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))

        } header: {
            Text("基础设置")
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        Section {
            Button {
                tapTextEvent("退出登录")
            } label: {
                ProfileRow(icon: SFSymbol.exit.rawValue, title: "退出登录")
            }

            NavigationLink(destination: PostDetailView(postId: APIService.deleteAccountUrl)) {
                ProfileRow(icon: SFSymbol.remove.rawValue, title: "删除账户") 
            }
        } header: {
            Text("账号管理")
        }
    }
    
    private func handlePushNotificationToggle(newValue: Bool) {
        if newValue {
            logger("[noti]用户已开启推送消息")
            NotificationManager.shared.scheduleDailyNotification()
        } else {
            logger("[noti]用户已关闭推送消息")
            NotificationManager.shared.cancelDailyNotification()
        }
    }
    
    private func tapTextEvent(_ urlString: String) {
        if urlString == "退出登录" {
            logger("退出登录")
            if !AccountState.isLogin() {
                ///LoginStateChecker.LoginStateHandle()
                presentedSheet = .login
                return
            }
            presentedSheet = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                presentedSheet = .logout
            }
        }
    }
}

struct LogoutConfirmationSheet: View {
    @Binding var presentedSheet: SettingView.ActiveSheet?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("退出后将不能评论和发帖等操作，您确定退出登录吗？")
                .titleFontStyle()
                .padding(.horizontal)
                .foregroundColor(.black)
            
            Button {
                logoutUser()
            } label: {
                Text("确定退出")
                    .titleFontStyle()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button {
                presentedSheet = nil
            } label: {
                Text("取消退出")
                    .titleFontStyle()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: GKDisplayMetrics.floatingPanelWidth)
        .frame(height: 230)
        .padding()
    }
    
    private func logoutUser() {
        Task {
            let response = try await APIService.logout()
            logger("response \(response)")
            if !response.isEmpty {
                presentedSheet = nil
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    presentedSheet = .login
//                }
            }
        }
    }
}
