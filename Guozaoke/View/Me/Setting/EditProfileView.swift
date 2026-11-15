//
//  EditProfileView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/15.
//

import SwiftUI

struct EditProfileView: View {
    @StateObject private var manager = AccountSettingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // 表单状态绑定
    @State private var nickname: String = ""
    @State private var gender: Int = 0
    @State private var generation: Int = 0
    @State private var signature: String = ""
    @State private var location: String = ""
    @State private var website: String = ""
    @State private var college: String = ""
    @State private var company: String = ""
    @State private var selfIntro: String = ""
    
    // 图片选择器
    @State private var showingImagePicker: Bool = false
    @State private var selectedImage: UIImage? = nil
    
    // 监听是否有变更
    private var isModified: Bool {
        nickname != manager.profile.nickname ||
        gender != manager.profile.gender ||
        generation != manager.profile.generation ||
        signature != manager.profile.signature ||
        location != manager.profile.location ||
        website != manager.profile.website ||
        college != manager.profile.college ||
        company != manager.profile.company ||
        selfIntro != manager.profile.selfIntro
    }
    
    var body: some View {
        Form {
            // MARK: - 1. 头像区
            avatarSection
            
            // MARK: - 2. 账号识别（只读保护）
            accountIdentifierSection
            
            // MARK: - 3. 基础社交信息
            publicProfileSection
            
            // MARK: - 4. 背景经历
            backgroundSection
            
            // MARK: - 5. 个人简介
            bioSection
            
            // MARK: - 6. 更多设置入口
            moreSettingsSection
        }
        .navigationTitle("编辑个人信息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: saveAction) {
                    if manager.isSaving {
                        ProgressView()
                    } else {
                        Text("保存")
                            .fontWeight(.semibold)
                            .foregroundColor(isModified ? .blue : .gray.opacity(0.5))
                    }
                }
                .disabled(!isModified || manager.isSaving)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { newImg in
            if let img = newImg {
                Task {
                    _ = await manager.uploadAvatar(image: img)
                    selectedImage = nil
                }
            }
        }
        .task {
            await manager.fetchProfile()
            syncFieldsFromManager()
        }
    }
    
    // MARK: - 头像修改区
    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        let avUrl = manager.profile.avatar.isEmpty ? AccountState.avatarUrl : manager.profile.avatar
                        KFImageView(avUrl)
                            .avatar(size: 84)
                            .overlay(Circle().stroke(Color.gray.opacity(0.15), lineWidth: 1.5))
                        
                        if manager.isUploadingAvatar {
                            Circle()
                                .fill(Color.black.opacity(0.45))
                                .frame(width: 84, height: 84)
                                .overlay(ProgressView().tint(.white))
                        }
                        
                        // 相机微标
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 26, height: 26)
                            .overlay(Image(systemName: "camera.fill").font(.system(size: 13)).foregroundColor(.white))
                            .offset(x: 2, y: 2)
                    }
                    .onTapGesture {
                        hapticFeedback()
                        showingImagePicker = true
                    }
                    
                    Button {
                        hapticFeedback()
                        showingImagePicker = true
                    } label: {
                        Text("点击更换头像")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - 账号信息只读区
    private var accountIdentifierSection: some View {
        Section {
            HStack {
                Text("用户名")
                    .foregroundColor(.primary)
                Spacer()
                Text(manager.profile.username.isEmpty ? AccountState.userName : manager.profile.username)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("E-mail")
                    .foregroundColor(.primary)
                Spacer()
                Text(manager.profile.email.isEmpty ? "--" : manager.profile.email)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("账号基础标识")
        } footer: {
            Text("用户名由字母开头，用于身份索引及主页链接。")
                .font(.caption2)
        }
    }
    
    // MARK: - 社区展示资料
    private var publicProfileSection: some View {
        Section {
            HStack {
                Text("昵称")
                    .frame(width: 80, alignment: .leading)
                TextField("填写后用于帖子和回复展示", text: $nickname)
            }
            
            Picker("性别", selection: $gender) {
                Text("不显示").tag(0)
                Text("男").tag(1)
                Text("女").tag(2)
            }
            
            Picker("出生年代", selection: $generation) {
                Text("不显示").tag(0)
                Text("70后").tag(1970)
                Text("80后").tag(1980)
                Text("90后").tag(1990)
                Text("00后").tag(2000)
                Text("10后").tag(2010)
            }
            
            HStack {
                Text("个性签名")
                    .frame(width: 80, alignment: .leading)
                TextField("显示在头像卡片和个人主页", text: $signature)
            }
            
            HStack {
                Text("常居城市")
                    .frame(width: 80, alignment: .leading)
                TextField("你的城市（如武汉）", text: $location)
            }
        } header: {
            Text("公开社交资料")
        } footer: {
            Text("昵称每30天可修改一次，最多12个汉字或24个英文。年代设置后会在头像卡片公开展示。")
                .font(.caption2)
        }
    }
    
    // MARK: - 职业与教育背景
    private var backgroundSection: some View {
        Section {
            HStack {
                Text("毕业院校")
                    .frame(width: 80, alignment: .leading)
                TextField("就读院校", text: $college)
            }
            
            HStack {
                Text("所在公司")
                    .frame(width: 80, alignment: .leading)
                TextField("所在企业或机构", text: $company)
            }
            
            HStack {
                Text("个人网站")
                    .frame(width: 80, alignment: .leading)
                TextField("https://...", text: $website)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
        } header: {
            Text("教育与职业经历")
        }
    }
    
    // MARK: - 个人详细简介
    private var bioSection: some View {
        Section {
            TextField("稍微详细的介绍一下自己...", text: $selfIntro, axis: .vertical)
                .lineLimit(3...8)
                .padding(.vertical, 4)
        } header: {
            Text("个人简介")
        }
    }
    
    // MARK: - 账号安全与高级设置
    private var moreSettingsSection: some View {
        Section {
            NavigationLink(destination: ChangeUsernameView()) {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("更改 ID")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("每年限一次")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: ChangePasswordView()) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("设置 / 修改密码")
                        .foregroundColor(.primary)
                }
            }
            
            NavigationLink(destination: PrivacySettingView()) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    Text("隐私设置")
                        .foregroundColor(.primary)
                }
            }
            
            NavigationLink(destination: ImageHostSettingView()) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    Text("图片托管设置")
                        .foregroundColor(.primary)
                }
            }
            
            NavigationLink(destination: BlockListView()) {
                HStack {
                    Image(systemName: "slash.circle")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("已屏蔽社友")
                        .foregroundColor(.primary)
                }
            }
            
            NavigationLink(destination: SettingView()) {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    Text("偏好与系统设置")
                        .foregroundColor(.primary)
                }
            }
        } header: {
            Text("账号安全与更多设置")
        }
    }
    
    // MARK: - 辅助方法
    private func syncFieldsFromManager() {
        let p = manager.profile
        self.nickname = p.nickname
        self.gender = p.gender
        self.generation = p.generation
        self.signature = p.signature
        self.location = p.location
        self.website = p.website
        self.college = p.college
        self.company = p.company
        self.selfIntro = p.selfIntro
    }
    
    private func saveAction() {
        hapticFeedback()
        var updated = manager.profile
        updated.nickname = nickname
        updated.gender = gender
        updated.generation = generation
        updated.signature = signature
        updated.location = location
        updated.website = website
        updated.college = college
        updated.company = company
        updated.selfIntro = selfIntro
        
        Task {
            let success = await manager.saveProfile(updated)
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        }
    }
}
