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
            let safeTrailing = GKDisplayMetrics.safeTabBarTrailingInset(
                geometryTrailing: proxy.safeAreaInsets.trailing
            )
            let safeBottom = GKDisplayMetrics.safeTabBarBottomInset(
                geometryBottom: proxy.safeAreaInsets.bottom
            )
            
            if isDual {
                // 折叠屏展开横屏：Master-Detail 双窗格
                HStack(spacing: 0) {
                    notificationListContent(isDual: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, safeBottom)
                    
                    // 中缝避让隔离 (32pt)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: GKDisplayMetrics.hingeExclusionRadius * 2)
                        .allowsHitTesting(false)
                    
                    // 右窗格：选中通知所对应的主题详情 (直接对齐右侧安全边距)
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
                    .padding(.trailing, safeTrailing)
                    .padding(.bottom, safeBottom)
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
                if isDual {
                    Button {
                        selectedTopicLink = notification.topicLink
                    } label: {
                        NotificationRowView(notification: notification)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedTopicLink == notification.topicLink ? Color.blue.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
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
                        PostDetailView(postId: notification.topicLink)
                    } label: {
                        NotificationRowView(notification: notification)
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
    @State private var isUserAvatarViewActive = false
    @State private var isUserNameInfoViewActive = false
    @State private var showCommentView = true

    var body: some View {
        HStack {
            KFImageView(notification.avatarURL)
                .avatar()
            .onTapGesture {
                isUserAvatarViewActive = true
            }
            .overlay {
                NavigationStack {
                     VStack {
                         Button("跳转到用户信息") {
                             isUserAvatarViewActive = true
                         }
                     }
                     .navigationDestination(isPresented: $isUserAvatarViewActive) {
                         UserInfoView(userId: notification.username)
                     }
                }.hidden()
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text(notification.username)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                        .foregroundColor(.adaptableBlack)
                    +
                    Text(" 回复了你的主题 ")
                        .font(.custom(titleFontName, size: subTitleFontSize))
                        .foregroundColor(.gray)
                    +
                    Text(notification.topicTitle)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                        .foregroundColor(.adaptableBlack)
                }
                HTMLContentView(content: notification.content, fontSize: subTitleFontSize)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
}

//#Preview {
//    NotificationsView()
//}
