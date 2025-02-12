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
        
        if viewModel.isLoading {
            ProgressView()
        }
        if viewModel.notifications.isEmpty, !viewModel.isLoading {
            HStack {
                Spacer()
                Text(NoMoreDataTitle.nodata)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        if !LoginStateChecker.isLogin() {
                            LoginStateChecker.LoginStateHandle()
                        }
                    }
                Spacer()
            }
            .listRowSeparator(.hidden)
            .padding(.vertical, 12)
        }
        
        List(viewModel.notifications) { notification in
            NavigationLink(destination: PostDetailView(postId: notification.topicLink)) {
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
        .padding(.vertical, 5)
        .buttonStyle(.plain)
        .listStyle(.plain)
        .refreshable {
            Task {
                await viewModel.fetchNotificationsRefresh()
            }
        }
        .sheet(item: $selectedNotification, content: { notification in
            let reply = "@" + notification.username + " "
            SendCommentView(
                detailId: notification.username,
                replyUser: reply,
                isPresented: $showCommentView
            ) {
                showCommentView = false
                selectedNotification = nil
            } 
        })
        .navigationTitle("通知")
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { _ in
            Task {
                await viewModel.fetchNotificationsRefresh()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
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
                Text(notification.username)
                    .font(.headline)
                    .onTapGesture {
                        isUserNameInfoViewActive = true
                    }
                    .overlay {
                        
                        NavigationStack {
                             VStack {
                                 Button("跳转到用户信息") {
                                     isUserNameInfoViewActive = true
                                 }
                             }
                             .navigationDestination(isPresented: $isUserNameInfoViewActive) {
                                 UserInfoView(userId: notification.username)
                             }
                        }.hidden()

                    }
                
                Text(notification.topicTitle)
                    .font(.footnote)
                Text(notification.content)
                    .font(.callout)
                    .foregroundColor(.gray)
                    
            }
            Spacer()
        }
        .contextMenu {
            Button {
                notification.topicLink.copyToClipboard()
            } label: {
                Label("拷贝链接", systemImage: .copy)
            }
            
            Button {
                let url = notification.topicLink.postDetailUrl()
                url.copyToClipboard()
                url.openURL()
            } label: {
                Label("网页查看帖子", systemImage: .safari)
            }
                        
            Button {
                let url = notification.username.userProfileUrl()
                url.openURL()
            } label: {
                Label("网页查看主页", systemImage: .safari)
            }
                        
//            Button {
//                
//            } label: {
//                Label("举报帖子", systemImage: .report)
//            }
        }
    }
}

//#Preview {
//    NotificationsView()
//}
