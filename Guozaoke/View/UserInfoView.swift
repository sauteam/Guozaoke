//
//  UserInfoView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/15.
//

import SwiftUI

struct UserInfoView: View {
    let userId: String
    @State private var isLoading = true
    @StateObject private var parser = UserInfoParser()
    @State private var selectedTab  = 1
    @State private var followText   = "+关注"

    var body: some View {
        VStack() {
            if parser.isLoading && parser.userInfo == nil {
                ProgressView("")
            } else if let errorMessage = parser.errorMessage {
                Text("加载失败: \(errorMessage)")
                    .foregroundColor(.red)
            } else if let userInfo = parser.userInfo {
                // Header Section
                VStack(spacing: 10) {
                    KFImageView(userInfo.avatar)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
                    Text(userInfo.username)
                        .font(.title2)
                        .fontWeight(.bold)
                    
//                    let isMe = AccountState.isSelf(userName: userId)
//                    Text("\(userInfo.profileInfo ?? "")")
//                        .font(.caption)
//                        .bold()
                    
                    Button(action: {
                        print("关注按钮点击")
                        Task {
                            do {
                                let (success, _) = await parser.followUserAction(userInfo.followLink) ?? (false, nil)
                                if success == true {
                                    await parser.fetchUserInfoAndData(self.userId.userProfileUrl())
                                }
                            }
                        }
                        
                    }) {
                        Text(userInfo.followTextChange)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }

                    Text("\(userInfo.number) \(userInfo.joinDate)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Tab Selection
                Picker("选择列表", selection: $selectedTab) {
                    Text("资料").tag(0)
                    Text("主题").tag(1)
                    Text("回复").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // List Section
                if selectedTab == 0 {
                    List {
                        ForEach(parser.userInfo?.profileInfo ?? [], id: \.self) { userInfo in
                            MyUserInfoView(userInfo: userInfo)
                        }
                        if parser.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .buttonStyle(.plain)
                    .listStyle(.plain)
                } else if selectedTab == 1 {
                    List {
                        ForEach(parser.topics) { post in
                            NavigationLink {
                                PostDetailView(postId: post.link)
                            } label: {
                                PostRowView(post: post)
                                    .onAppear {
                                        if post == parser.topics.last {
                                            Task { await parser.fetchUserInfoAndData(userId, reset: false) }
                                        }
                                    }
                            }
                            
                        }
                        
                        if parser.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        } else if !parser.hasMoreData, !parser.topics.isEmpty {
                            
                            HStack {
                                Spacer()
                                Text(NoMoreDataTitle.homeList)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .listStyle(.plain)
                    .refreshable {
                        Task { await parser.fetchUserInfoAndData(profileUrl(userId), reset: true) }
                    }
                } else if selectedTab == 2 {
                    List {
                        ForEach(parser.replies) { post in
                            NavigationLink {
                                PostDetailView(postId: post.titleLink)
                            } label: {
                                MyReplyRowView(myReply: post, userId: userId)
                                    .onAppear {
                                        if post == parser.replies.last {
                                            Task { await parser.fetchUserInfoAndData(profileUrl(userId), reset: false) }
                                        }
                                    }
                            }
                        }
                        if parser.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        } else if !parser.hasMoreData, !parser.replies.isEmpty {
                            
                            HStack {
                                Spacer()
                                Text(NoMoreDataTitle.homeList)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .listStyle(.plain)
                    .refreshable {
                        Task { await parser.fetchUserInfoAndData(userId.userProfileUrl(), reset: true) }
                    }
                }
            }
        }
        .navigationTitle(AccountState.isSelf(userName: userId) ? "我的主页" : parser.userInfo?.nickname ?? "个人主页")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                
                Menu {
                    Button {
                        profileUrl(userId).copyToClipboard()
                    } label: {
                        Label("拷贝个人主页", systemImage: .copy)
                    }
                    
                    if AccountState.isSelf(userName: userId) {
                        Button {
                            userId.userProfileUrl().openURL()
                        } label: {
                            Label("网页查看主页", systemImage: .safari)
                        }
                    } else {
                        
                        Button {
                            userId.userProfileUrl().openURL()
                        } label: {
                            Label("网页查看主页", systemImage: .safari)
                        }
                        
                        Button {
                            Task {
                                let response = await parser.blockUserAction(parser.userInfo?.blockLink)
                                print("block \(response)")
                            }
                        } label: {
                            
                            Label(parser.userInfo?.blockText ?? "屏蔽此账号", systemImage: parser.userInfo?.isBlocked ?? false ? .block : .unblock)
                        }
                    }

                } label: {
                    SFSymbol.more
                }
            }
        }
        .onAppear {
            if !parser.hadData {
                Task { await parser.fetchUserInfoAndData(profileUrl(userId), reset: true) }
            }
            
            NotificationCenter.default.addObserver(forName: .loginSuccessNoti, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let user = userInfo as? Dictionary<String, Any> {
                    let username  = user["userName"] as? String ?? ""
                    Task { await parser.fetchUserInfoAndData(username, reset: true) }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { notification in
                if let userInfo = notification.userInfo,
                   let user = userInfo as? Dictionary<String, Any> {
                        let username  = user["userName"] as? String ?? ""
                        Task { await parser.fetchUserInfoAndData(username, reset: true) }
                }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
        }
    }
    
    
    private func profileUrl(_ userId: String) -> String {
        return userId.userProfileUrl()
    }
}

struct MyUserInfoView: View {
    let userInfo: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(userInfo)
                    .font(.callout)
                    .onLongPressGesture {
                        userInfo.copyToClipboard()
                    }
            }
        }
    }
}

struct MyReplyRowView: View {
    @State private var isPostDetailViewActive = false
    @State private var isUserInfoViewActive = false
    let myReply: MyReply
    let userId: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(myReply.title)")
                    .font(.footnote)
                    .lineLimit(2)
                    .foregroundColor(.gray)
                    .onTapGesture {
                        isPostDetailViewActive = true
                        log("titleLink \(myReply.titleLink)")
                    }.background {
                        NavigationLink(
                            destination: PostDetailView(postId: myReply.titleLink),
                                isActive: $isPostDetailViewActive
                            ) {
                                EmptyView()
                            }.hidden()
                    }
            }
            
            Text(myReply.content)
                .font(.callout)
                .lineLimit(2)
//                .onTapGesture {
//                    if myReply.userLink.isEmpty == false {
//                        //isUserInfoViewActive = true
//                    }
//                    log("mentionedUser \(myReply.userLink ?? "")")
//                }
                .background {
                    NavigationLink(
                        destination: UserInfoView(userId: myReply.userLink ?? ""),
                            isActive: $isUserInfoViewActive
                        ) {
                            EmptyView()
                        }.hidden()
                }
        }
        .contextMenu {
            
            Button {
                let url = myReply.titleLink.postDetailUrl()
                url.openURL()
            } label: {
                Label("网页查看帖子", systemImage: .safari)
            }
            
            Button {
                let url = userId.userProfileUrl()
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




//
//#Preview {
//    UserInfoView(userId: "testicles")
//}
