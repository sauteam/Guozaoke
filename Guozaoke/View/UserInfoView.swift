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
    @State private var showCollectionView = false
    @State private var showMyReplyView = false

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
                        .avatar(size: 60)
                    let isMe = AccountState.isSelf(userName: userInfo.username)
                    HStack {
                        Text(userInfo.username)
                            .subTitleFontStyle()
//                        Button {
//                            Task {
//                                let response = await parser.blockUserAction(parser.userInfo?.blockLink)
//                                print("block \(response)")
//                            }
//                        } label: {
//                            Label("", systemImage: parser.userInfo?.isBlocked ?? false ? .unblock : .block)
//                        }
                    }
                    if isMe == false {
                        HStack {
                            Button(action: {
                                hapticFeedback()
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
                        }
                    }
                    Text("\(userInfo.number) \(userInfo.joinDate)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Picker("选择列表", selection: $selectedTab) {
                    Text("资料")
                        .tag(0)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                    Text("主题")
                        .tag(1)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                    Text("回复")
                        .tag(2)
                        .font(.custom(titleFontName, size: subTitleFontSize))
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.leading, 16)
                .padding(.trailing, 16)

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
                        } else if parser.topics.isEmpty {
                            HStack {
                                Spacer()
                                Text(NoMoreDataTitle.nodaText)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
                        } else if !parser.topics.isEmpty, !parser.noMoreTopics {
                            HStack {
                                if let linkUrl = parser.userInfo?.topicLink, !linkUrl.isEmpty, parser.topics.count > 5  {
                                    Spacer()
                                    Text("更多主题")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .onTapGesture {
                                            hapticFeedback()
                                            showCollectionView.toggle()
                                        }
                                    Spacer()
                                    
                                    } else {
                                        EmptyView()
                                    }
                            }
                            .frame(height: 20)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
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
                        } else if parser.replies.isEmpty {
                            
                            HStack {
                                Spacer()
                                Text(NoMoreDataTitle.nodaText)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 2)
                        } else if !parser.replies.isEmpty, !parser.noMoreReplies {
                            HStack {
                                if let linkUrl = parser.userInfo?.replyLink, !linkUrl.isEmpty, parser.replies.count > 5  {
                                    Spacer()
                                    Text("更多回复")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .frame(height: 20)
                                        .onTapGesture {
                                            hapticFeedback()
                                            showMyReplyView.toggle()
                                        }
                                    Spacer()
                                } else {
                                    EmptyView()
                                }
                            }
                            .frame(height: 20)
                            .listRowSeparator(.hidden)
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
        .navigationDestination(isPresented: $showCollectionView, destination: {
            if let linkUrl = parser.userInfo?.topicLink, !linkUrl.isEmpty {
                MyCollectionView(
                    linkUrl: linkUrl,
                    linkText: (parser.userInfo?.username ?? "") + "的更多主题"
                )
            }
        })
        .navigationDestination(isPresented: $showMyReplyView, destination: {
            if let linkUrl = parser.userInfo?.replyLink, !linkUrl.isEmpty {
                MyReplyListView(
                    linkUrl: linkUrl,
                    linkText: (parser.userInfo?.username ?? "") + "的更多回复")
            }
        })
        .navigationTitleStyle(AccountState.isSelf(userName: userId) ? "我的主页" : parser.userInfo?.nickname ?? "个人主页")
        .navigationBarTitleDisplayMode(.inline)
        .tabbarToolBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        profileUrl(userId).copyToClipboard()
                    } label: {
                        Label("拷贝个人主页", systemImage: .copy)
                    }
                    
//                    if parser.userInfo?.favoritesCount ?? 0 > 0  {
//                        Button {
//                            showCollectionView = true
//                        } label: {
//                            Label("\(parser.userInfo?.username ?? "TA")的收藏", systemImage: .bookmarkFill)
//                        }
//                        
//                        NavigationLink(value: parser.userInfo?.favoritesLink) {
//                            EmptyView()
//                        }
//                        .navigationDestination(for: String.self) { userId in
//                            MyCollectionView(linkUrl: userId, linkText: parser.userInfo?.username ?? "")
//                        }
//                    }
                    
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
                            ToastView.reportToast()
                        } label: {
                            Label("举报", systemImage: .safari)
                        }
                        
                        Button {
                            Task {
                                let response = await parser.blockUserAction(parser.userInfo?.blockLink)
                                print("block \(response)")
                            }
                        } label: {
                            
                            Label(parser.userInfo?.blockText ?? "屏蔽此账号", systemImage: parser.userInfo?.blockUser ?? false ? .block : .unblock)
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
    @State private var showSafari = false
    @State private var showSystemCopy = false
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(userInfo)
                    .titleFontStyle()
                    .dynamicContextMenu(userInfo: userInfo, showSafari: $showSafari, showSystemCopy: $showSystemCopy)
            }
        }
        .onAppear {
            text = userInfo
        }
        .sheet(isPresented: $showSafari) {
            if let url = userInfo.extractURLs.first {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showSystemCopy) {
            CopyableTextSheet(isPresented: $showSystemCopy, text: $text)
            .presentationDetents([.height(200), .medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct MyReplyRowView: View {
    @State private var isPostDetailViewActive = false
    let myReply: MyReply
    let userId: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(myReply.title)
                    .subTitleFontStyle(weight: .black)
                    //.lineLimit(2)
                    .foregroundColor(.gray)
            }
            HTMLContentView(content: myReply.content, fontSize: subTitleFontSize)
                .titleFontStyle()
        }
        .navigationDestination(isPresented: $isPostDetailViewActive, destination: {
            PostDetailView(postId: myReply.titleLink)
        })
        .onTapGesture {
            isPostDetailViewActive = true
            log("titleLink \(myReply.titleLink)")
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
