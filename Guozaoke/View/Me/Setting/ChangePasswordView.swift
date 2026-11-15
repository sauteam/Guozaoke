//
//  ChangePasswordView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/15.
//

import SwiftUI

struct ChangePasswordView: View {
    @ObservedObject private var manager = AccountSettingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        Form {
            Section {
                SecureField("当前密码", text: $oldPassword)
            } header: {
                Text("验证旧密码")
            } footer: {
                Text("输入你当前使用的社区登录密码。")
                    .font(.caption2)
            }
            
            Section {
                SecureField("新密码 (不少于6位)", text: $newPassword)
                SecureField("再次输入新密码", text: $confirmPassword)
            } header: {
                Text("设置新密码")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if !newPassword.isEmpty && newPassword.count < 6 {
                        Text("• 新密码长度需至少 6 个字符")
                            .foregroundColor(.red)
                    }
                    if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("• 两次输入的新密码不一致")
                            .foregroundColor(.red)
                    }
                }
                .font(.caption2)
            }
            
            Section {
                Button(action: submitChange) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("保存新密码")
                                .fontWeight(.semibold)
                                .foregroundColor(canSubmit ? .white : .white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(canSubmit ? Color.blue : Color.gray.opacity(0.4))
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .navigationTitle("设置密码")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var canSubmit: Bool {
        !oldPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }
    
    private func submitChange() {
        hapticFeedback()
        isSubmitting = true
        Task {
            let (success, msg) = await manager.changePassword(
                oldPass: oldPassword,
                newPass: newPassword,
                confirmPass: confirmPassword
            )
            isSubmitting = false
            if success {
                dismiss()
            } else {
                ToastView.warningToast(msg)
            }
        }
    }
}
