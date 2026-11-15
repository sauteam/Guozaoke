//
//  ImageHostSettingView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/15.
//

import SwiftUI

struct ImageHostSettingView: View {
    @ObservedObject private var manager = AccountSettingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var setting = ImageHostSettingModel()
    @State private var inputToken: String = ""
    @State private var autoRevoke: Bool = false
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    
    var body: some View {
        Form {
            if !setting.statusText.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(setting.statusText)
                            .font(.subheadline)
                    }
                } header: {
                    Text("当前托管状态")
                }
            }
            
            Section {
                SecureField("sk- 开头的 Token；已绑定留空保留", text: $inputToken)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Toggle("修改论坛密码后自动撤销图床托管", isOn: $autoRevoke)
            } header: {
                Text("ImgURL API Token 配置")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Token 在服务端加密保存，不会明文回显。")
                    Text("• 解绑只移除论坛的托管凭证，已上传图片和帖子图片外链仍会保留。")
                    Text("• 请在图床控制台自行管理或撤销不再使用的 Token。")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Section {
                Button(action: saveAction) {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存图床配置")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.blue)
                .disabled(isSaving)
            }
            
            if setting.bound {
                Section {
                    Button(role: .destructive, action: unbindAction) {
                        HStack {
                            Spacer()
                            Text("解除图床绑定")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle("图片托管设置")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            self.setting = await manager.fetchImageHostSettings()
            self.autoRevoke = self.setting.autoRevoke
            self.isLoading = false
        }
    }
    
    private func saveAction() {
        hapticFeedback()
        isSaving = true
        Task {
            let success = await manager.saveImageHostSettings(
                token: inputToken,
                autoRevoke: autoRevoke,
                version: setting.version,
                albumId: setting.albumId
            )
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
    
    private func unbindAction() {
        hapticFeedback()
        isSaving = true
        Task {
            let success = await manager.unbindImageHost(version: setting.version)
            isSaving = false
            if success {
                self.setting = await manager.fetchImageHostSettings()
                self.autoRevoke = self.setting.autoRevoke
            }
        }
    }
}
