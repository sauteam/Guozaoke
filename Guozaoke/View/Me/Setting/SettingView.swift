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

    
    var body: some View {
        Form {
//            Section {
//                HStack {
//                    ProfileRow(icon: SFSymbol.exit.rawValue, title: "主题色")
//                    Picker("主题色", selection: $themeManager.selectedColor) {
//                       Text("系统蓝").tag(ThemeColor.systemBlue)
//                       Text("咖啡色").tag(ThemeColor.coffeeBrown)
//                       Text("红色").tag(ThemeColor.red)
//                   }
//                   .pickerStyle(SegmentedPickerStyle())
//                   .padding()
//                }
//            } header: {
//                Text("主题色")
//            }
            Section {
                Toggle(isOn: $pushNotificationsEnabled) {
                    Text(pushNotificationsEnabled ? "接收推送消息" : "关闭推送消息")
                        .titleFontStyle()
                }.onChange(of: pushNotificationsEnabled) { newValue in
                    handlePushNotificationToggle(newValue: newValue)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Toggle(isOn: $hapticFeedbackEnabled) {
                    Text("触觉反馈")
                        .titleFontStyle()
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Toggle(isOn: $homeListRefreshEnabled) {
                    Text("首页刷新")
                        .titleFontStyle()
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            } header: {
                Text("设置")
            }
                        
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
        .listStyle(InsetGroupedListStyle())
        .toolbar(.hidden, for: .tabBar)
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
    
    private func handlePushNotificationToggle(newValue: Bool) {
        if newValue {
            print("[noti]用户已开启推送消息")
            NotificationManager.shared.scheduleDailyNotification()
        } else {
            print("[noti]用户已关闭推送消息")
            NotificationManager.shared.cancelDailyNotification()
        }
    }
    
    private func tapTextEvent(_ urlString: String) {
        if urlString == "退出登录" {
            print("退出登录")
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
        .frame(height: 230)
        .padding()
    }
    
    private func logoutUser() {
        Task {
            let response = try await APIService.logout()
            print("response \(response)")
            if !response.isEmpty {
                presentedSheet = nil
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    presentedSheet = .login
//                }
            }
        }
    }
}
