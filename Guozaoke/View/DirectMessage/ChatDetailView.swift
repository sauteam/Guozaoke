//
//  ChatDetailView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/14.
//

import SwiftUI

struct ChatDetailView: View {
    let targetId: String
    let targetUsername: String
    let targetNickname: String?
    let targetAvatar: String?
    var conversationId: Int? = nil

    @ObservedObject private var manager = DirectMessageManager.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var currentMyAvatar: String? = nil
    @State private var showClearConfirmation: Bool = false
    @State private var selectedUserIdForProfile: String? = nil
    @State private var hasScrolledToBottomOnFirstLoad: Bool = false

    private var currentThread: DirectMessageThread? {
        manager.findThread(targetId: targetId)
    }

    private var currentTitle: String {
        if let nick = currentThread?.targetNickname, !nick.isEmpty {
            return nick
        }
        if let nick = targetNickname, !nick.isEmpty {
            return nick
        }
        if let user = currentThread?.targetUsername, !user.isEmpty {
            return user
        }
        return targetUsername.isEmpty ? "社友 #\(targetId)" : targetUsername
    }

    private var messages: [ChatMessage] {
        manager.getMessages(for: targetId)
    }

    private var myAvatarUrl: String? {
        if let av = currentMyAvatar, !av.isEmpty, av != "--" {
            return av
        }
        let stateUrl = AccountState.avatarUrl
        if !stateUrl.isEmpty && stateUrl != "--" {
            return stateUrl
        }
        if let u = AccountState.getAccount()?.avatar, !u.isEmpty, u != "--" {
            return u
        }
        return nil
    }

    private func peerAvatarUrl(for msg: ChatMessage) -> String? {
        if let av = msg.senderAvatar, !av.isEmpty, av != "--" {
            return av
        }
        if let av = currentThread?.targetAvatar, !av.isEmpty, av != "--" {
            return av
        }
        if let av = targetAvatar, !av.isEmpty, av != "--" {
            return av
        }
        return nil
    }

    private func resolvedPeerUsername(for msg: ChatMessage) -> String {
        if !msg.senderUsername.isEmpty && msg.senderUsername != AccountState.userName {
            return msg.senderUsername
        }
        if let uname = currentThread?.targetUsername, !uname.isEmpty {
            return uname
        }
        if !targetUsername.isEmpty {
            return targetUsername
        }
        return targetId
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 顶部安全提醒条（对审合规护身符）
                    safetyBanner

                    if manager.isLoadingMessages && messages.isEmpty {
                        ProgressView("加载私信历史...")
                            .padding(.vertical, 20)
                    }

                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                bottomInputBar
            }
            .onTapGesture {
                isInputFocused = false
            }
            .onChange(of: messages.count) { _ in
                if let lastId = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if !hasScrolledToBottomOnFirstLoad, let lastId = messages.last?.id {
                    hasScrolledToBottomOnFirstLoad = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle(currentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(
            get: { selectedUserIdForProfile != nil },
            set: { if !$0 { selectedUserIdForProfile = nil } }
        )) {
            if let uid = selectedUserIdForProfile {
                UserInfoView(userId: uid, fromChatTargetId: targetId)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                chatMenu
            }
        }
        .task {
            currentMyAvatar = AccountState.avatarUrl
            await manager.ensureMyAvatar()
            currentMyAvatar = AccountState.avatarUrl
            if messages.isEmpty {
                let cid = conversationId ?? currentThread?.conversationId
                await manager.fetchMessages(for: targetId, specificCid: cid)
            }
            await manager.markAsRead(targetId: targetId)
        }
        .onDisappear {
            Task {
                await manager.markAsRead(targetId: targetId)
                await manager.fetchThreads()
            }
        }
    }

    // MARK: - 顶部合规安全提示
    private var safetyBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.checkerboard")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text("私信受社区公约保护，请文明交流，勿向陌生社友泄露敏感信息。")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.bottom, 6)
    }

    // MARK: - 单条消息气泡
    private func messageBubble(_ msg: ChatMessage) -> some View {
        VStack(spacing: 4) {
            Text(msg.timeFormatted)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 2)

            HStack(alignment: .top, spacing: 8) {
                if msg.isFromMe {
                    Spacer(minLength: 40)

                    Text(LocalizedStringKey(msg.content.decodingHTMLEntities))
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])

                    // 我的头像：点击进入我的主页
                    Button {
                        selectedUserIdForProfile = AccountState.userName
                    } label: {
                        avatarView(url: myAvatarUrl)
                    }
                    .buttonStyle(.plain)
                } else {
                    // 对方头像：点击进入对方主页
                    Button {
                        selectedUserIdForProfile = resolvedPeerUsername(for: msg)
                    } label: {
                        avatarView(url: peerAvatarUrl(for: msg))
                    }
                    .buttonStyle(.plain)

                    Text(LocalizedStringKey(msg.content.decodingHTMLEntities))
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])

                    Spacer(minLength: 40)
                }
            }
        }
    }

    // MARK: - 头像视图与兜底
    @ViewBuilder
    private func avatarView(url: String?) -> some View {
        let clean = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validUrl = clean, !validUrl.isEmpty, validUrl != "--" {
            KFImageView(validUrl, placeholder: avatarPlaceholder)
                .avatar(size: 34)
        } else {
            avatarPlaceholder
                .frame(width: 34, height: 34)
                .cornerRadius(8)
        }
    }

    private var avatarPlaceholder: AnyView {
        AnyView(
            ZStack {
                Color.gray.opacity(0.18)
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        )
    }

    // MARK: - 底部输入栏
    private var bottomInputBar: some View {
        HStack(spacing: 10) {
            TextField("输入私信内容...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(18)
                .focused($isInputFocused)

            Button(action: sendAction) {
                if manager.isSending {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray.opacity(0.5) : .blue)
                        .frame(width: 36, height: 36)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    private func sendAction() {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        guard AccountState.isLogin() else {
            LoginStateChecker.LoginStateHandle()
            ToastView.warningToast(needLoginTextCanDo)
            return
        }
        
        hapticFeedback()
        let sendingText = content
        inputText = ""
        
        Task {
            _ = await manager.sendMessage(
                to: targetId,
                targetUsername: targetUsername,
                targetNickname: targetNickname,
                targetAvatar: targetAvatar,
                content: sendingText
            )
        }
    }

    // MARK: - 右上角菜单
    private var chatMenu: some View {
        Menu {
            Button {
                Task {
                    let cid = conversationId ?? currentThread?.conversationId
                    await manager.fetchMessages(for: targetId, specificCid: cid)
                    await manager.markAsRead(targetId: targetId)
                    ToastView.successToast("已刷新")
                }
            } label: {
                Label("刷新消息", systemImage: "arrow.clockwise")
            }

            let peerUser = currentThread?.targetUsername.isEmpty == false ? currentThread!.targetUsername : targetUsername
            if !peerUser.isEmpty {
                Button {
                    selectedUserIdForProfile = peerUser
                } label: {
                    Label("查看社友主页", systemImage: "person.circle")
                }
            }

            Button {
                ToastView.reportToast()
            } label: {
                Label("举报此对话", systemImage: "exclamationmark.bubble")
            }

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("清空聊天记录", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.primary)
                .padding(4)
        }
        .alert("清空聊天记录", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                hapticFeedback()
                manager.clearMessages(for: targetId)
            }
        } message: {
            Text("确定要清空与当前社友的所有私信记录吗？此操作无法撤销。")
        }
    }
}
