//
//  MessageListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import JDStatusBarNotification

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsParser()
    @ObservedObject private var dmManager = DirectMessageManager.shared
    @State private var showCommentView = false
    @State private var showDirectMessages = false
    @State private var selectedNotification: NotificationItem? = nil
    @State private var selectedTopicLink: String? = nil

    var body: some View {
        GeometryReader { proxy in
            let isDual = GKDisplayMetrics.isDualColumnDisplay(size: proxy.size)
            
            if isDual {
                // 折叠屏展开横屏：Master-Detail 双窗格
                HStack(spacing: 0) {
                    notificationListContent(isDual: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 中缝避让隔离 (32pt)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: GKDisplayMetrics.hingeExclusionRadius * 2)
                        .allowsHitTesting(false)
                    
                    // 右窗格：选中通知所对应的主题详情 (右边距TabBar仅保留10pt，充盈饱满不空旷)
                    ZStack {
                        if let topicLink = selectedTopicLink, !topicLink.isEmpty {
                            let noti = viewModel.notifications.first(where: { $0.topicLink == topicLink })
                            PostDetailView(
                                postId: topicLink,
                                targetUsername: noti?.username,
                                targetReplySnippet: noti?.content
                            )
                            .id(topicLink)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.blue.opacity(0.6))
                                Text("选择通知查看相关主题详情")
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("在展开屏幕上直接阅读通知内容与回复")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, 10)
                }
                .environment(\.isGKDualColumn, true)
            } else {
                notificationListContent(isDual: false)
                    .environment(\.isGKDualColumn, false)
            }
        }
        .navigationTitleStyle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showDirectMessages) {
            DirectMessageListView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    hapticFeedback()
                    guard AccountState.isLogin() else {
                        LoginStateChecker.LoginStateHandle()
                        ToastView.warningToast("请先登录社区再查看私信")
                        return
                    }
                    showDirectMessages = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)

                        if dmManager.hasUnread {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -2)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .onAppear {
            if !AccountState.isLogin() {
                LoginStateChecker.LoginStateHandle()
                return
            }
            Task {
                await viewModel.fetchNotifications()
                await dmManager.fetchSummary()
                await dmManager.fetchThreads()
            }
            
            NotificationCenter.default.addObserver(forName: .logoutSuccessNoti, object: nil, queue: .main) { _ in
                viewModel.notifications.removeAll()
                logger("[logout] noti")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { _ in
            logger("[login] noti")
            Task {
                await viewModel.fetchNotificationsRefresh()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
            NotificationCenter.default.removeObserver(self, name: .logoutSuccessNoti, object: nil)
        }
    }
    
    @ViewBuilder
    private func notificationListContent(isDual: Bool) -> some View {
        VStack {
            if viewModel.isLoading, viewModel.notifications.isEmpty  {
                ProgressView()
            }
            if viewModel.notifications.isEmpty, !viewModel.isLoading {
                HStack {
                    Spacer()
                    Text(NoMoreDataTitle.nodata)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            if !LoginStateChecker.isLogin {
                                LoginStateChecker.LoginStateHandle()
                            }
                        }
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 12)
            }
            
            List(viewModel.notifications) { notification in
                if isDual {
                    Button {
                        selectedTopicLink = notification.topicLink
                    } label: {
                        NotificationRowView(
                            notification: notification,
                            isDual: true,
                            isSelected: selectedTopicLink == notification.topicLink
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedTopicLink == notification.topicLink ? Color.blue.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            showCommentView      = true
                            selectedNotification = notification
                        } label: {
                            SFSymbol.reply
                        }
                    }
                } else {
                    NavigationLink {
                        PostDetailView(
                            postId: notification.topicLink,
                            targetUsername: notification.username,
                            targetReplySnippet: notification.content
                        )
                    } label: {
                        NotificationRowView(
                            notification: notification,
                            isDual: false,
                            isSelected: false
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            showCommentView      = true
                            selectedNotification = notification
                        } label: {
                            SFSymbol.reply
                        }
                    }
                }
            }
            .padding(.vertical, 5)
            .listStyle(.plain)
            .refreshable {
                Task {
                    await viewModel.fetchNotificationsRefresh()
                }
            }
            .onChange(of: viewModel.notifications.count) { _ in
                if isDual && (selectedTopicLink == nil || selectedTopicLink?.isEmpty == true) {
                    selectedTopicLink = viewModel.notifications.first?.topicLink
                }
            }
            .onChange(of: showCommentView) { isPresented in
                if isPresented, let notification = selectedNotification {
                    let reply = "@" + notification.username + " "
                    CommentInputManager.shared.showCommentInput(
                        detailId: notification.topicLink,
                        replyUser: reply,
                        username: notification.username
                    ) {
                        showCommentView = false
                        selectedNotification = nil
                    }
                }
            }
        }
    }
}

struct NotificationRowView: View {
    let notification: NotificationItem
    var isDual: Bool = false
    var isSelected: Bool = false
    
    @State private var isUserAvatarViewActive = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            KFImageView(notification.avatarURL)
                .avatar()
                .onTapGesture {
                    isUserAvatarViewActive = true
                }
                .navigationDestination(isPresented: $isUserAvatarViewActive) {
                    UserInfoView(userId: notification.userId)
                }
            
            VStack(alignment: .leading, spacing: 5) {
                // 用户名与行为描述（如：xxx 回复了你的主题）
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(notification.username)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                        .fontWeight(.medium)
                        .foregroundColor(.adaptableBlack)
                        .onTapGesture {
                            isUserAvatarViewActive = true
                        }
                    
                    Text(notification.actionText)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                        .foregroundColor(.secondary)
                }
                
                // 主题标题（蓝色高亮表明可点击跳转，不带任何内联箭头，撑满剩余宽度）
                Text(notification.topicTitle)
                    .font(.custom(titleFontName, size: subTitleFontSize))
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 回复内容详情
                if !notification.content.isEmpty {
                    HTMLContentView(content: notification.content, fontSize: subTitleFontSize)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 仅在双窗格模式下由视图手动渲染箭头（单栏模式由外层 NavigationLink 自动在 Cell 右侧提供原生单个箭头）
            if isDual {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .accentColor : Color(UIColor.tertiaryLabel))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

//#Preview {
//    NotificationsView()
//}
