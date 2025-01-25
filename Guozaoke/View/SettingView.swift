//
//  SettingView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI

struct SettingView: View {
    let items: [String] = ["帮助反馈", "关于", "退出登录"]
    @State private var showLogoutSheet = false
    @State private var isLoggedOut = false

    var body: some View {
            List {
                ForEach(items, id: \.self) { text in
                    HStack {
                        Text(text)
                            .onTapGesture {
                                tapTextEvent(text)
                            }
                        Spacer()
                        SFSymbol.rightIcon
                            .foregroundColor(.gray)
                    }
                }
            .padding(.vertical, 10)
            .listStyle(InsetGroupedListStyle())
            .sheet(isPresented: $showLogoutSheet) {
                LogoutConfirmationSheet(showLogoutSheet: $showLogoutSheet, isLoggedOut: $isLoggedOut)
                    .presentationDetents([.height(230)])
            }
        .sheet(isPresented: $isLoggedOut) {
            LoginView(isPresented: $isLoggedOut) {
                
            }
        }
        }
        .navigationTitle("设置")
    }
    
    private func tapTextEvent(_ urlString: String) {
         if urlString == "退出登录" {
             print("退出登录")
             showLogoutSheet = true
             if !AccountState.isLogin() {
                 isLoggedOut = true
                 return
             }
         } else {
             var url =  APIService.baseUrlString
             if urlString == "帮助反馈" {
                 url = APIService.baseUrlString + APIService.feedback
             }
             url.openURL()
         }
     }
}


struct LogoutConfirmationSheet: View {
    @Binding var showLogoutSheet: Bool
    @Binding var isLoggedOut: Bool
    
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
                showLogoutSheet = false
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
        }
    }
}


//#Preview {
//    SettingView()
//}
