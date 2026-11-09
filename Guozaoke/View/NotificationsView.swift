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
    @State private var showCommentView = false
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
                            PostDetailView(postId: topicLink)
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
        .onAppear {
            if !AccountState.isLogin() {
                LoginStateChecker.LoginStateHandle()
                return
            }
            Task {
                await viewModel.fetchNotifications()
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
                NotificationRowView(
                    notification: notification,
                    isDual: isDual,
                    isSelected: isDual && selectedTopicLink == notification.topicLink,
                    onSelectTopic: {
                        selectedTopicLink = notification.topicLink
                    }
                )
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        showCommentView      = true
                        selectedNotification = notification
                    } label: {
                        SFSymbol.reply
                    }
                }
            }
            .padding(.vertical, 5)
            .buttonStyle(.plain)
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
    var onSelectTopic: (() -> Void)? = nil
    
    @State private var isUserAvatarViewActive = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                isUserAvatarViewActive = true
            } label: {
                KFImageView(notification.avatarURL)
                    .avatar()
            }
            .buttonStyle(.plain)
            .navigationDestination(isPresented: $isUserAvatarViewActive) {
                UserInfoView(userId: notification.userId)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Button {
                        isUserAvatarViewActive = true
                    } label: {
                        Text(notification.username)
                            .font(.custom(titleFontName, size: subTitleFontSize))
                            .fontWeight(.medium)
                            .foregroundColor(.adaptableBlack)
                    }
                    .buttonStyle(.plain)
                    
                    Text(notification.actionText)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                        .foregroundColor(.gray)
                    
                    if isDual {
                        Button {
                            onSelectTopic?()
                        } label: {
                            Text(notification.topicTitle)
                                .font(.custom(titleFontName, size: subTitleFontSize))
                                .foregroundColor(.adaptableBlack)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if isDual {
                    if !notification.content.isEmpty {
                        Button {
                            onSelectTopic?()
                        } label: {
                            HTMLContentView(content: notification.content, fontSize: subTitleFontSize)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // 单栏模式下整行只有一个 NavigationLink，确保右侧仅展示一个导航箭头
                    NavigationLink {
                        PostDetailView(postId: notification.topicLink)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.topicTitle)
                                .font(.custom(titleFontName, size: subTitleFontSize))
                                .foregroundColor(.adaptableBlack)
                                .lineLimit(2)
                            
                            if !notification.content.isEmpty {
                                HTMLContentView(content: notification.content, fontSize: subTitleFontSize)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.12) : Color.clear)
        )
    }
}

//#Preview {
//    NotificationsView()
//}
