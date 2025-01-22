//
//  MessageListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsParser()
    
    var body: some View {
        NavigationView {
            List(viewModel.notifications) { notification in
                NavigationLink(destination: PostDetailView(postId: notification.topicLink)) {
                    NotificationRowView(notification: notification)
                }
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.notifications.isEmpty {
                    HStack {
                        Spacer()
                        Text(NoMoreDataTitle.notiList)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 12)
                }
            }
            .padding(.vertical, 5)
            .buttonStyle(.plain)
            .listStyle(.plain)
//            .refreshable {
//                Task {
//                    await viewModel.fetchNotifications()
//                }
//            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.fetchNotifications()
                }
            }
        }
    }
}

struct NotificationRowView: View {
    let notification: NotificationItem
    @State private var isUserAvatarViewActive = false
    @State private var isUserNameInfoViewActive = false

    var body: some View {
        HStack {
            KFImageView(notification.avatarURL)
                .avatar()
            .onTapGesture {
                isUserAvatarViewActive = true
            }
            .overlay {
                NavigationLink(
                    destination: UserInfoView(userId: notification.username),
                        isActive: $isUserAvatarViewActive
                    ) {
                        EmptyView()
                    }.hidden()
            }
            
            VStack(alignment: .leading) {
                Text(notification.username)
                    .font(.headline)
                    .onTapGesture {
                        isUserNameInfoViewActive = true
                    }
                    .overlay {
                        NavigationLink(
                            destination: UserInfoView(userId: notification.username),
                                isActive: $isUserNameInfoViewActive
                            ) {
                                EmptyView()
                            }.hidden()
                    }
                
                Text(notification.topicTitle)
                    .font(.footnote)
                    .lineLimit(2)
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
                        
            Button {
                
            } label: {
                Label("举报帖子", systemImage: .report)
            }
        }
    }
}

//#Preview {
//    NotificationsView()
//}
