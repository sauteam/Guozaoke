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
    var body: some View {
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
//                        .onAppear {
//                            if notification == viewModel.notifications.last {
//                            }
//                        }
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
