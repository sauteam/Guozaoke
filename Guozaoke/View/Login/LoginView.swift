//
//  LoginView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import SwiftSoup

// MARK: - 登录视图
struct LoginView: View {
    @StateObject private var loginService = LoginService()
    @Binding var isPresented: Bool
    let onLoginSuccess: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("登录账户")) {
                    TextField("邮箱或手机号", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("密码", text: $password)
                        .textContentType(.password)
                }
                
                if let error = loginService.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: performLogin) {
                        if loginService.isLoading {
                            ProgressView()
                        } else {
                            Text("登录")
                        }
                    }
                    .disabled(loginService.isLoading)
                    
                    Button("注册账号") {
                        // 跳转到注册页面
                        APIService.registerUrl.openURL()
                    }
                    
                    Button("忘记密码") {
                        // 跳转到找回密码页面
                        if let url = URL(string: APIService.forgotUrl) {
                            url.openSafari()
                        }
                    }
                }
            }
            .navigationTitle("登录过早客")
            .navigationBarItems(trailing: Button("取消") {
                isPresented = false
            })
        }
        .onChange(of: loginService.isLoggedIn) { newValue in
            if newValue {
                successAsyn()
            }
        }
    }
    
    private func successAsyn() {
        LoginStateChecker.shared.isLogin = true
        onLoginSuccess()
        isPresented = false
    }
    
    private func performLogin() {
        Task {
            do {
                let success = try await loginService.login(email: email, password: password)
                if success {
                    successAsyn()
                }
            } catch {
                loginService.error = error.localizedDescription
            }
        }
    }
}
