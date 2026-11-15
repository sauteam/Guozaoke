//
//  ChangeUsernameView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/15.
//

import SwiftUI

struct ChangeUsernameView: View {
    @ObservedObject private var manager = AccountSettingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var newUsername: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showConfirmDialog: Bool = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("当前 ID")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(manager.profile.username.isEmpty ? AccountState.userName : manager.profile.username)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("当前账号标识")
            }
            
            Section {
                HStack {
                    Text("新 ID")
                        .frame(width: 70, alignment: .leading)
                    TextField("3~14位，字母开头", text: $newUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            } header: {
                Text("设置新 ID")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• 规则：由字母开头，只能含有字母、数字或者下划线，长度 3~14 位。")
                    Text("• 频率：每次成功修改后需满一年才能再次修改。")
                    Text("• 权益保留：你的帖子、回复、收藏和早点全部保留，旧 ID 的个人主页链接仍然有效，旧 ID 也不会被他人占用。")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
            
            Section {
                SecureField("请输入当前登录密码", text: $password)
            } header: {
                Text("安全校验")
            } footer: {
                Text("更改账号唯一 ID 属于高敏感操作，需验证当前登录密码。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button(action: {
                    hapticFeedback()
                    showConfirmDialog = true
                }) {
                    HStack {
                        Spacer()
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("确认更改 ID")
                                .fontWeight(.semibold)
                                .foregroundColor(isInputValid ? .white : .white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(isInputValid ? Color.blue : Color.gray.opacity(0.4))
                .disabled(!isInputValid || isSubmitting)
            }
        }
        .navigationTitle("更改 ID")
        .navigationBarTitleDisplayMode(.inline)
        .alert("更改 ID 确认", isPresented: $showConfirmDialog) {
            Button("取消", role: .cancel) {}
            Button("确认更改", role: .destructive) {
                performChange()
            }
        } message: {
            Text("确定要将用户名修改为【\(newUsername)】吗？每年仅限修改一次，确认后立即生效！")
        }
    }
    
    private var isInputValid: Bool {
        let clean = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 && clean.count <= 14 else { return false }
        guard let first = clean.first, first.isLetter else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard clean.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard !password.isEmpty else { return false }
        return true
    }
    
    private func performChange() {
        isSubmitting = true
        Task {
            let (success, msg) = await manager.changeUsername(newId: newUsername, password: password)
            isSubmitting = false
            if success {
                dismiss()
            } else {
                ToastView.warningToast(msg)
            }
        }
    }
}
