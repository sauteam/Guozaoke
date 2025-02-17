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
    @State private var showSafariRegister = false
    @State private var showSafariResetPwd = false

    @State private var email = ""
    @State private var password = ""
    @State private var showSafari = false
    @State private var url: URL?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("登录账户")) {
                    TextField("邮箱或手机号", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(PlainTextFieldStyle())

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
                        url = URL(string: APIService.registerUrl)
                        showSafari = true
                    }
                    
                    Button("忘记密码") {
                        url = URL(string: APIService.forgotUrl)
                        showSafari = true
                    }
                }
            }
            .navigationTitle("登录过早客")
            .navigationBarItems(trailing: Button("关闭") {
                closeView()
            })
            .sheet(isPresented: $showSafari) {
                if let url = url {
                    SafariView(url: url)
                }
            }
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
        closeView()
    }
    
    private func closeView() {
        isPresented = false
        dismiss()
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
