//
//  DirectMessageListView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/14.
//

import SwiftUI

struct DirectMessageListView: View {
    @ObservedObject private var manager = DirectMessageManager.shared
    @State private var threadToDelete: DirectMessageThread? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if manager.isLoadingThreads && manager.threads.isEmpty {
                ProgressView("正在加载私信...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.threads.isEmpty {
                emptyPlaceholder
            } else {
                threadList
            }
        }
        .navigationTitle("私信消息")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            hapticFeedback()
            await manager.fetchThreads()
        }
        .task {
            await manager.fetchThreads()
        }
    }

    // MARK: - 空状态提示
    private var emptyPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 54))
                .foregroundColor(.secondary.opacity(0.5))

            Text("暂无私信消息")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("在社友个人主页点击【私信】即可发起一对一沟通交流")
                .font(.footnote)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - 会话列表
    private var threadList: some View {
        List {
            ForEach(manager.threads) { thread in
                NavigationLink(
                    destination: ChatDetailView(
                        targetId: thread.targetId,
                        targetUsername: thread.targetUsername,
                        targetNickname: thread.targetNickname,
                        targetAvatar: thread.targetAvatar,
                        conversationId: thread.conversationId
                    )
                ) {
                    HStack(spacing: 12) {
                        // 对方头像
                        if let av = thread.targetAvatar, !av.isEmpty, av != "--" {
                            KFImageView(av, placeholder: avatarPlaceholder)
                                .avatar(size: 46)
                        } else {
                            avatarPlaceholder
                                .frame(width: 46, height: 46)
                                .cornerRadius(8)
                        }

                        // 昵称与最后一条消息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thread.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)

                            Text(manager.getDisplayLastMessage(for: thread))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // 时间与未读红点指示器（展示详情最后一条消息的时间）
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(manager.getDisplayTime(for: thread))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            if thread.unreadCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            } else {
                                Spacer().frame(height: 8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        hapticFeedback()
                        threadToDelete = thread
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .alert("删除会话", isPresented: $showDeleteConfirmation, presenting: threadToDelete) { thread in
            Button("取消", role: .cancel) {
                threadToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let t = threadToDelete {
                    Task {
                        await manager.deleteThread(targetId: t.targetId)
                    }
                }
                threadToDelete = nil
            }
        } message: { thread in
            Text("确定要删除与「\(thread.displayName)」的私信会话吗？这不会影响对方的聊天记录。")
        }
    }

    private var avatarPlaceholder: AnyView {
        AnyView(
            ZStack {
                Color.gray.opacity(0.18)
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        )
    }
}
