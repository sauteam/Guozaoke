//
//  PostRowView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/16.
//

import SwiftUI

// MARK: - 子视图
struct PostRowView: View {
    let post: PostItem
    @State private var isNodeInfoViewActive = false
    @State private var isUserAvatarViewActive = false
    @State private var isLastReplyUserInfoViewActive = false
    @State private var isUserNameInfoViewActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                KFImageView(post.avatar)
                    .avatar()
                    .onTapGesture {
                        log("点击 \(post.avatar)")
                        isUserAvatarViewActive = true
                    }
                    .overlay {
                        NavigationLink(
                            destination: UserInfoView(userId: post.author),
                                isActive: $isUserAvatarViewActive
                            ) {
                                EmptyView()
                            }.hidden()
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(.body)
                        .padding(.horizontal, 2)
                        .lineLimit(2)
                    HStack {
                        Text(post.author)
                            .lineLimit(1)
                            .onTapGesture {
                                log("点击 \(post.author) \(post.nodeUrl)")
                                isUserNameInfoViewActive = true
                            }
                            .overlay {
                                NavigationLink(
                                    destination: UserInfoView(userId: post.author),
                                        isActive: $isUserNameInfoViewActive
                                    ) {
                                        EmptyView()
                                    }
                                    .hidden()
                            }
                        
                        Text(post.time)
                            .foregroundColor(.gray)
                        if let lastReplyUser = post.lastReplyUser {
                            Text("•")
                            Text("\(lastReplyUser)" + " 回复")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .onTapGesture {
                                    log("点击 \(lastReplyUser)")
                                    isLastReplyUserInfoViewActive = true
                                }
                                .background {
                                    NavigationLink(
                                        destination: UserInfoView(userId: lastReplyUser),
                                            isActive: $isLastReplyUserInfoViewActive
                                        ) {
                                            EmptyView()
                                        }.hidden()
                                }
                        }
                        
                        
                        
                        if post.isDetailInfo == false {
                            if post.replyCount > 0 {
                                Text("评论\(post.replyCount)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(2)
                                    .lineLimit(1)
                            }
                        }
                        
                        Text(post.node)
                            .foregroundColor(.blue)
                            .font(.footnote)
                            .cornerRadius(8)
                            .clipShape(Rectangle())
                            .onTapGesture {
                                log("点击 \(post.node) \(post.nodeUrl)")
                                isNodeInfoViewActive = true
                            }
                            .background {
                                NavigationLink(
                                    destination: NodeInfoView(node: post.node, nodeUrl: post.nodeUrl),
                                        isActive: $isNodeInfoViewActive
                                    ) {
                                        EmptyView()
                                    }
                                    .hidden()
                            }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                post.title.copyToClipboard()
            } label: {
                Label("拷贝标题", systemImage: .copy)
            }
            
            Button {
                let url = post.link.postDetailUrl()
                url.copyToClipboard()
                url.openURL()
            } label: {
                Label("网页查看帖子", systemImage: .safari)
            }
                        
            Button {
                let url = post.author.userProfileUrl()
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
//    PostRowView()
//}
