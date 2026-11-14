//
//  UserInfoView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/15.
//

import SwiftUI

struct UserInfoView: View {
    let userId: String
    var fromChatTargetId: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @StateObject private var parser = UserInfoParser()
    @ObservedObject private var pointsParser = PointsParser.shared
    @State private var selectedTab  = 1
    @State private var followText   = "+关注"
    @State private var showCollectionView = false
    @State private var showMyReplyView = false
    @State private var showChatDetail = false

    private var isCurrentUser: Bool {
        AccountState.isSelf(userName: parser.userInfo?.username ?? "") ||
        AccountState.isSelf(userName: parser.userInfo?.number ?? "") ||
        AccountState.isSelf(userName: userId) ||
        AccountState.isSelf(userName: resolvedUserId)
    }

    private var pointsDisplay: String {
        let p = pointsParser.pointsBalance.trimmingCharacters(in: .whitespacesAndNewlines)
        if p.isEmpty || p == "--" {
            let cached = Persist.read(key: PointsParser.pointsCacheKey, default: "0")
            return (cached.isEmpty || cached == "--") ? "0" : cached
        }
        return p
    }

    private var resolvedUserId: String {
        var trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            trimmed = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            if let lastComp = trimmed.split(separator: "/").last {
                trimmed = String(lastComp)
            }
        }
        if trimmed.hasPrefix("/u/") {
            trimmed = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        trimmed = trimmed.components(separatedBy: CharacterSet(charactersIn: "?#/")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        if let range = trimmed.range(of: "Lv.", options: .caseInsensitive) {
            trimmed = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.isEmpty || trimmed == "/u/" || trimmed == "我的账号" || AccountState.invalidDisplayNames.contains(trimmed) {
            let uName = AccountState.userName
            if !uName.isEmpty && uName != "/u/" && AccountState.isValidDisplayName(uName) {
                return uName
            }
            let link = AccountState.userLink
            let linkSlug = link.replacingOccurrences(of: "/u/", with: "")
                .components(separatedBy: CharacterSet(charactersIn: "?#/")).first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !linkSlug.isEmpty && linkSlug != "/u/" && linkSlug != "guozaoke" && AccountState.isValidDisplayName(linkSlug) {
                return linkSlug
            }
            if let cookieUser = AccountState.extractUsernameFromCookies(), AccountState.isValidDisplayName(cookieUser) {
                return cookieUser
            }
            return ""
        }
        // 如果传入的是当前登录用户的昵称，且本地已存有对应真实用户名 slug，自动转换为真实 slug
        if AccountState.isLogin() && trimmed == AccountState.displayName && !AccountState.userName.isEmpty {
            return AccountState.userName
        }
        return trimmed
    }

    var body: some View {
        VStack {
            if resolvedUserId.isEmpty {
                Text("未获取到用户信息，请重新登录")
                    .foregroundColor(.secondary)
                    .padding()
            } else if parser.isLoading && parser.userInfo == nil {
                ProgressView("")
            } else if let errorMessage = parser.errorMessage {
                VStack(spacing: 12) {
                    Text("加载失败: \(errorMessage)")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("点击重试") {
                        let targetId = resolvedUserId
                        if !targetId.isEmpty {
                            Task { await parser.fetchUserInfoAndData(profileUrl(targetId), reset: true) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let userInfo = parser.userInfo {
                userInfoHeader(userInfo)
                userInfoTabs(userInfo)
                userInfoContent(userInfo)
            } else {
                Text("暂无个人信息")
                    .foregroundColor(.secondary)
                    .padding()
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
        .navigationDestination(isPresented: $showChatDetail, destination: {
            if let u = parser.userInfo {
                let cleanNum = u.number.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined()
                let targetId = cleanNum.isEmpty ? u.username : cleanNum
                let thread = DirectMessageManager.shared.findThread(targetId: targetId)
                ChatDetailView(
                    targetId: targetId,
                    targetUsername: u.username,
                    targetNickname: u.nickname.isEmpty ? u.username : u.nickname,
                    targetAvatar: u.avatar,
                    conversationId: thread?.conversationId
                )
            }
        })
        .navigationTitle((AccountState.isSelf(userName: userId) || AccountState.isSelf(userName: resolvedUserId)) ? "我的主页" : (parser.userInfo?.nickname ?? "个人主页"))
        .navigationTitleStyle((AccountState.isSelf(userName: userId) || AccountState.isSelf(userName: resolvedUserId)) ? "我的主页" : (parser.userInfo?.nickname ?? "个人主页"))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ConditionalTabBarToolBar(shouldApply: fromChatTargetId == nil))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                profileMenu()
            }
        }
        .onAppear {
            if isCurrentUser {
                Task { await pointsParser.fetchPointsSummary() }
            }
            if !parser.hadData {
                let targetId = resolvedUserId
                if !targetId.isEmpty {
                    Task { await parser.fetchUserInfoAndData(profileUrl(targetId), reset: true) }
                }
            }
            NotificationCenter.default.addObserver(forName: .loginSuccessNoti, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let user = userInfo as? [String: Any] {
                    let username  = user["userName"] as? String ?? ""
                    if !username.isEmpty {
                        Task { await parser.fetchUserInfoAndData(username.userProfileUrl, reset: true) }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { notification in
            if let userInfo = notification.userInfo,
               let user = userInfo as? [String: Any] {
                let username  = user["userName"] as? String ?? ""
                if !username.isEmpty {
                    Task { await parser.fetchUserInfoAndData(username.userProfileUrl, reset: true) }
                }
            }
        }
        .onChange(of: parser.userInfo?.username) { _ in
            if isCurrentUser {
                Task { await pointsParser.fetchPointsSummary() }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
        }
    }
    
    private func profileUrl(_ customId: String? = nil) -> String {
        let cleanId = (customId != nil && !customId!.isEmpty) ? customId! : resolvedUserId
        if cleanId.isEmpty {
            return AccountState.userName.userProfileUrl
        }
        return cleanId.userProfileUrl
    }
    
    private func userInfoHeader(_ userInfo: UserInfo) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                KFImageView(userInfo.avatar)
                    .avatar(size: 50)
                
                if userInfo.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
            let isMe = AccountState.isSelf(userName: userInfo.username)
            HStack(spacing: 6) {
                Text(userInfo.username)
                    .subTitleFontStyle()
                
                if let level = userInfo.level, !level.isEmpty {
                    Text(level)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                }
            }
            if !isMe {
                userActionButtons(userInfo)
            }
            Text("\(userInfo.number) \(userInfo.joinDate)")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func userActionButtons(_ userInfo: UserInfo) -> some View {
        HStack(spacing: 12) {
            // 关注按钮（纯文字，无icon）
            Button(action: {
                hapticFeedback()
                guard AccountState.isLogin() else {
                    LoginStateChecker.LoginStateHandle()
                    ToastView.warningToast(needLoginTextCanDo)
                    return
                }
                logger("关注按钮点击")
                Task {
                    do {
                        let followUrl = userInfo.followLink.isEmpty ? "/f/user/\(userInfo.username)" : userInfo.followLink
                        let (success, _) = await parser.followUserAction(followUrl) ?? (false, nil)
                        if success {
                            let isFollowed = parser.userInfo?.followTextChange == "取消关注"
                            ToastView.successToast(isFollowed ? "关注成功" : "已取消关注")
                        }
                    }
                }
            }) {
                Text(userInfo.followTextChange)
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(userInfo.followTextChange == "取消关注" ? Color.gray.opacity(0.6) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            
            // 私信按钮（纯文字，无icon，与关注按钮保持严格一致，严格校验登录状态）
            Button(action: {
                hapticFeedback()
                guard AccountState.isLogin() else {
                    LoginStateChecker.LoginStateHandle()
                    ToastView.warningToast("请先登录社区再发送私信")
                    return
                }
                
                // 如果当前正是从私信详情进入该主页，点击直接返回私信详情，避免再次重复跳转
                if let chatTarget = fromChatTargetId, !chatTarget.isEmpty {
                    let cleanNum = parser.userInfo?.number.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined() ?? ""
                    let uname = parser.userInfo?.username ?? ""
                    let currentProfileTarget = cleanNum.isEmpty ? uname : cleanNum
                    
                    if DirectMessageManager.shared.isSameConversation(
                        DirectMessageThread(conversationId: nil, targetId: chatTarget, targetUsername: chatTarget, lastMessage: "", lastUpdated: Date(), unreadCount: 0),
                        DirectMessageThread(conversationId: nil, targetId: currentProfileTarget, targetUsername: uname, lastMessage: "", lastUpdated: Date(), unreadCount: 0)
                    ) || chatTarget == currentProfileTarget || chatTarget == uname || chatTarget == userId || chatTarget == resolvedUserId {
                        dismiss()
                        return
                    }
                }
                
                showChatDetail = true
            }) {
                Text("私信")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
            }
        }
    }
    
    private func userInfoTabs(_ userInfo: UserInfo) -> some View {
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
    }
    
    private func userInfoContent(_ userInfo: UserInfo) -> some View {
        Group {
            if selectedTab == 0 {
                profileInfoList()
            } else if selectedTab == 1 {
                topicList()
            } else if selectedTab == 2 {
                replyList()
            }
        }
    }
    
    // MARK: - profileInfoList
    private func profileInfoList() -> some View {
        List {
            ForEach(parser.userInfo?.profileInfo ?? [], id: \.self) { item in
                if item.hasPrefix("早点:") || item.hasPrefix("社区早点:") {
                    ZStack(alignment: .leading) {
                        NavigationLink(destination: CommunityPointsView()) {
                            EmptyView()
                        }
                        .opacity(0)
                        
                        MyUserInfoView(userInfo: "早点: \(pointsDisplay) 点")
                    }
                } else {
                    MyUserInfoView(userInfo: item)
                }
            }
            if parser.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .buttonStyle(.plain)
        .listStyle(.plain)
    }
    
    // MARK: - topicList
    private func topicList() -> some View {
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
                moreTopicsLink()
            }
        }
        .buttonStyle(.plain)
        .listStyle(.plain)
        .refreshable {
            Task { await parser.fetchUserInfoAndData(profileUrl(resolvedUserId), reset: true) }
        }
    }
    
    private func moreTopicsLink() -> some View {
        HStack {
            if let linkUrl = parser.userInfo?.topicLink, !linkUrl.isEmpty, parser.topics.count > 5 {
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
    
    // MARK: - replyList
    private func replyList() -> some View {
        List {
            ForEach(parser.replies) { post in
                NavigationLink {
                    PostDetailView(postId: post.titleLink)
                } label: {
                    MyReplyRowView(myReply: post, userId: resolvedUserId)
                        .onAppear {
                            if post == parser.replies.last {
                                Task { await parser.fetchUserInfoAndData(profileUrl(resolvedUserId), reset: false) }
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
                moreRepliesLink()
            }
        }
        .buttonStyle(.plain)
        .listStyle(.plain)
        .refreshable {
            Task { await parser.fetchUserInfoAndData(profileUrl(resolvedUserId), reset: true) }
        }
    }
    
    private func moreRepliesLink() -> some View {
        HStack {
            if let linkUrl = parser.userInfo?.replyLink, !linkUrl.isEmpty, parser.replies.count > 5 {
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
    
    private func profileMenu() -> some View {
        Menu {
            Button {
                profileUrl(resolvedUserId).copyToClipboard()
            } label: {
                Label("拷贝个人主页", systemImage: .copy)
            }
            if AccountState.isSelf(userName: resolvedUserId) {
                Button {
                    resolvedUserId.userProfileUrl.openURL()
                } label: {
                    Label("网页查看主页", systemImage: .safari)
                }
            } else {
                Button {
                    resolvedUserId.userProfileUrl.openURL()
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
                        logger("block \(response)")
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

// MARK: - MyUserInfoView
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

// MARK: - MyReplyRowView
struct MyReplyRowView: View {
    @State private var isPostDetailViewActive = false
    let myReply: MyReply
    let userId: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(myReply.title)
                    .subTitleFontStyle(weight: .black)
                    .foregroundColor(.gray)
            }
            HTMLContentView(content: myReply.content, fontSize: subTitleFontSize)
        }
        .navigationDestination(isPresented: $isPostDetailViewActive, destination: {
            PostDetailView(postId: myReply.titleLink)
        })
        .onTapGesture {
            isPostDetailViewActive = true
            logger("titleLink \(myReply.titleLink)")
        }
    }
}

fileprivate struct ConditionalTabBarToolBar: ViewModifier {
    let shouldApply: Bool
    func body(content: Content) -> some View {
        if shouldApply {
            content.tabbarToolBar()
        } else {
            content
        }
    }
}
