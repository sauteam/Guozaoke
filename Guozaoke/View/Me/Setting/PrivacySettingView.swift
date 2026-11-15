//
//  PrivacySettingView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/15.
//

import SwiftUI

struct PrivacySettingView: View {
    @ObservedObject private var manager = AccountSettingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var setting = PrivacySettingModel()
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    
    var body: some View {
        Form {
            Section {
                Picker("在线状态可见范围", selection: $setting.online) {
                    Text("所有人").tag(0)
                    Text("已登录用户").tag(1)
                    Text("只有我自己").tag(2)
                }
            } header: {
                Text("在线状态")
            } footer: {
                Text("登录后访问页面即显示在线，15 分钟内未访问其他页面则自动离线。")
                    .font(.caption2)
            }
            
            Section {
                Picker("主题列表可见范围", selection: $setting.topics) {
                    Text("所有人").tag(0)
                    Text("已登录用户").tag(1)
                    Text("只有我自己").tag(2)
                }
            } header: {
                Text("主题列表")
            } footer: {
                Text("控制谁能在你的个人主页中浏览你发布的所有历史主题。")
                    .font(.caption2)
            }
            
            Section {
                Picker("回复列表可见范围", selection: $setting.replies) {
                    Text("所有人").tag(0)
                    Text("已登录用户").tag(1)
                    Text("只有我自己").tag(2)
                }
            } header: {
                Text("回复列表")
            } footer: {
                Text("控制谁能在你的个人主页中浏览你的全部历史回帖。")
                    .font(.caption2)
            }
            
            Section {
                Picker("收藏列表可见范围", selection: $setting.favorites) {
                    Text("所有人").tag(0)
                    Text("已登录用户").tag(1)
                    Text("只有我自己").tag(2)
                }
            } header: {
                Text("收藏列表")
            } footer: {
                Text("控制谁能在你的个人主页中查看你收藏的主题。")
                    .font(.caption2)
            }
            
            Section {
                Picker("谁可以给我发私信", selection: $setting.dmReceive) {
                    Text("所有符合条件的用户").tag(0)
                    Text("仅我关注的人").tag(1)
                    Text("拒绝所有私信").tag(2)
                }
            } header: {
                Text("私信接收")
            } footer: {
                Text("拒绝所有私信后，已有会话也不会继续接收新私信。")
                    .font(.caption2)
            }
        }
        .navigationTitle("隐私设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveAction()
                }
                .fontWeight(.semibold)
                .disabled(isLoading || isSaving)
            }
        }
        .task {
            self.setting = await manager.fetchPrivacySettings()
            self.isLoading = false
        }
    }
    
    private func saveAction() {
        hapticFeedback()
        isSaving = true
        Task {
            let success = await manager.savePrivacySettings(setting)
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}
