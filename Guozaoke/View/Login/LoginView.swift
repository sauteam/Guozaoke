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
    let agreementUrl = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    @StateObject private var loginService = LoginService()
    @Binding var isPresented: Bool
    let onLoginSuccess: () -> Void
    @State private var showSafariRegister = false
    @State private var showSafariResetPwd = false

    @State private var email = ""
    @State private var password = ""
    @State private var showSafari = false
    @State private var isSecured = true
    @State private var url: URL?
    @Environment(\.dismiss) var dismiss
    @State private var isAgreed = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("邮箱或手机号", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(height: 40)
                        .titleFontStyle()

                    SecureTextField(text: $password)
                        .frame(height: 40)
                        .listRowBackground(Color.clear)
                        .titleFontStyle()
                }

                Section {
                    if let error = loginService.error {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    HStack {
                        Image(systemName: isAgreed ? "checkmark.circle.fill" : "circle")
                            .onTapGesture {
                                isAgreed.toggle()
                            }
                        
                        Text("我已阅读并同意")
                            .subTitleFontStyle()
                        
                        Link("《用户使用协议》", destination: URL(string: agreementUrl)!)
                            .subTitleFontStyle()
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 15)
                    .buttonStyle(.plain)
                    .listStyle(.plain)
                }

                Section {
                    let enable = password.count < 5 || email.count < 5 || !isAgreed
                    Button(action: performLogin) {
                        if loginService.isLoading {
                            ProgressView()
                        } else {
                            Text("登录")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.blue)
                                .cornerRadius(10)
                                .subTitleFontStyle()
                        }
                    }
                    .disabled(loginService.isLoading || enable)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .buttonStyle(.plain)
                    .listStyle(.plain)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("登录过早客")
            .sheet(isPresented: $showSafari) {
                if let url = url {
                    SafariView(url: url)
                }
            }
        }
        .onDisappear {
            print("[login]登录提示框 needLogin2")
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
