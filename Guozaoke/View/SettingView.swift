//
//  SettingView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI
struct SettingView: View {
    let items: [String] = ["帮助反馈", "关于", "退出登录", "删除账户"]
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
                    ProfileRow(icon: SFSymbol.pencilCircle.rawValue, title: "意见反馈") {
                        
                    }
                }
                
                NavigationLink(destination: NodeInfoView(node: "公告", nodeUrl: APIService.notice)) {
                    ProfileRow(icon: SFSymbol.notice.rawValue, title: "公告") {
                        
                    }
                }
                
                NavigationLink(destination: AboutGuozaokeView())  {
                    ProfileRow(icon: SFSymbol.info.rawValue, title: "关于") {
                        
                    }
                }
                
            } header: {
                Text("帮助")
            }
                   
            Section {
                NavigationLink(destination: PostDetailView(postId: APIService.deleteAccountUrl)) {
                    ProfileRow(icon: SFSymbol.remove.rawValue, title: "删除账户") {
                        
                    }
                }
            } header: {
                Text("删除账号")
            }

            Section {
                ProfileRow(icon: SFSymbol.app.rawValue, title: "App Store查看") {
                    
                }.onTapGesture {
                    GuozaokeAppInfo.toAppStore()
                }
                
                ProfileRow(icon: SFSymbol.heartCircle.rawValue, title: "给我们鼓励") {
                    
                }.onTapGesture {
                    GuozaokeAppInfo.toWriteReview()
                }
            } header: {
                Text("App Store查看")
            }
                        
            Section {
                ProfileRow(icon: SFSymbol.exit.rawValue, title: "退出登录") {
                    
                }.onTapGesture {
                    tapTextEvent("退出登录")
                }
            } header: {
                Text("退出账号")
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
        }
        .navigationTitle("设置")
    }
    
    private func tapTextEvent(_ urlString: String) {
         if urlString == "退出登录" {
             print("退出登录")
             if !AccountState.isLogin() {
                 presentedSheet = .login
                 return
             }
             presentedSheet = .logout
         }
     }
}

struct LogoutConfirmationSheet: View {
//    @Binding var showLogoutSheet: Bool
//    @Binding var showLoginView: Bool
    @Binding var presentedSheet: SettingView.ActiveSheet?
    var body: some View {
        VStack(spacing: 20) {
            Text("退出后将不能评论和发帖等操作，您确定要退出登录吗？")
                .font(.body)
                .padding(.horizontal)
                .foregroundColor(.black)
            
            Button("确认退出") {
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
                    //presentedSheet = .login
                }
            }
        }
    }
}
