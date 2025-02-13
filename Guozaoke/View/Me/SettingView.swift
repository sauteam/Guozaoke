import SwiftUI
struct SettingView: View {
    @State private var showLogoutSheet = false
    @State private var showLoginView = false
    @State private var presentedSheet: ActiveSheet?
    
    enum ActiveSheet: Identifiable {
        case logout, login

        var id: Int {
            switch self {
            case .logout: return 1
            case .login: return 2
            }
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: IntroductationView())  {
                    ProfileRow(icon: SFSymbol.coment.rawValue, title: "评论发帖") {}
                }

                NavigationLink(destination: NodeInfoView(node: "意见反馈", nodeUrl: APIService.feedback)) {
                    ProfileRow(icon: SFSymbol.pencilCircle.rawValue, title: "意见反馈") {}
                }
                
                NavigationLink(destination: NodeInfoView(node: "公告", nodeUrl: APIService.notice)) {
                    ProfileRow(icon: SFSymbol.notice.rawValue, title: "公告") {}
                }
                
                NavigationLink(destination: FaqView()) {
                    ProfileRow(icon: SFSymbol.report.rawValue, title: "faq") {}
                }
                
                NavigationLink(destination: AboutGuozaokeView())  {
                    ProfileRow(icon: SFSymbol.info.rawValue, title: "关于") {}
                }
                
                NavigationLink(destination: MoreView())  {
                    ProfileRow(icon: SFSymbol.more.rawValue, title: "更多") {}
                }
            } header: {
                Text("帮助")
            }
                   
            Section {
                ProfileRow(icon: SFSymbol.app.rawValue, title: "App Store查看") {
                    GuozaokeAppInfo.toAppStore()
                }
                ProfileRow(icon: SFSymbol.heartCircle.rawValue, title: "给我们鼓励") {
                    GuozaokeAppInfo.toWriteReview()
                }
               
            } header: {
                Text("App Store查看")
            }
                        
            
            Section {
                ProfileRow(icon: SFSymbol.exit.rawValue, title: "退出登录") {
                    tapTextEvent("退出登录")
                }
                NavigationLink(destination: PostDetailView(postId: APIService.deleteAccountUrl)) {
                    ProfileRow(icon: SFSymbol.remove.rawValue, title: "删除账户") {}
                }
            } header: {
                Text("账号管理")
            }
        }
        .padding(.vertical, 10)
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
        .navigationTitle("设置")
    }
    
    private func tapTextEvent(_ urlString: String) {
        if urlString == "退出登录" {
            print("退出登录")
            if !AccountState.isLogin() {
                //LoginStateChecker.LoginStateHandle()
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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("退出后将不能评论和发帖等操作，您确定要退出登录吗？")
                .font(.body)
                .padding(.horizontal)
                .foregroundColor(.black)
            
            Button("确定退出") {
                logoutUser()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("取消退出") {
                presentedSheet = nil
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    presentedSheet = .login
                }
            }
        }
    }
}
