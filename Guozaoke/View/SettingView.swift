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
            List {
                ForEach(items, id: \.self) { text in
                    HStack {
                        Text(text)
                            .onTapGesture {
                                tapTextEvent(text)
                            }
                            //.padding()
                        if text == "删除账户" {
                            Text("删除账户需要去官网操作，删除账号不能恢复，请确认后再操作")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        SFSymbol.rightIcon
                            .foregroundColor(.gray)
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
         } else {
             var url =  APIService.baseUrlString
             if urlString == "帮助反馈"  {
                 url = APIService.baseUrlString + APIService.feedback
             } else if urlString == "删除账户" {
                 url = APIService.baseUrlString + APIService.deleteAccountUrl
             }
             url.openURL()
             //SafariView(url: URL(string: url) ?? APIService.baseURL)
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
