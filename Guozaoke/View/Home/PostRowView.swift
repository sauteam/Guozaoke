//
//  PostRowView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/16.
//

let dotText = " • "

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
                let profile     = post.rowEnum == .profileRow
                let nodeInfo    = post.rowEnum == .nodeInfo
                
                KFImageView(post.avatar)
                    .avatar()
                    .disabled(post.rowEnum == .profileRow)
                    .onTapGesture {
                        log("点击 \(post.avatar)")
                        if !profile {
                            isUserAvatarViewActive = true
                        } 
                    }
                    .navigationDestination(isPresented: $isUserAvatarViewActive, destination: {
                        UserInfoView(userId: post.author)
                    })                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        //let content = post.title + (post.postType == .elite ? Text(Image(systemName: SFSymbol.bookmark.rawValue)) : Text(""))
                        Text(post.title)
                            .titleFontStyle()
                            .padding(.horizontal, 2)
                            .lineLimit(2)
                    }
                    HStack {
                        Text(post.author)
                            .usernameFontStyle()
                            .lineLimit(1)
                            .onTapGesture {
                                log("点击 \(post.author) \(post.nodeUrl)")
                                if !profile {
                                    isUserNameInfoViewActive = true
                                }
                            }
                        
                        if let lastReplyUser = post.lastReplyUser {
                            Text("\(post.time)" + dotText + "\(lastReplyUser)" + "回复")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .onTapGesture {
                                    isLastReplyUserInfoViewActive = true
                                    if profile == true, post.author == post.lastReplyUser ?? "" {
                                        isLastReplyUserInfoViewActive = false
                                    }
                                }
                                .navigationDestination(isPresented: $isLastReplyUserInfoViewActive, destination: {
                                    UserInfoView(userId: lastReplyUser)
                                })
                        }
                                                
                        if post.rowEnum != .detailRow {
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
                            .clipShape(Rectangle())
                            .onTapGesture {
                                log("点击 \(post.node) \(post.nodeUrl)")
                                if !nodeInfo {
                                    isNodeInfoViewActive = true
                                }
                            }
                            .navigationDestination(isPresented: $isNodeInfoViewActive, destination: {
                                NodeInfoView(node: post.node, nodeUrl: post.nodeUrl)
                            })
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                post.link.postDetailUrl().copyToClipboard()
            } label: {
                Label("拷贝链接", systemImage: .copy)
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
        }
    }
}

