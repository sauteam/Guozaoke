//
//  PostDetail.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

// MARK: - 目标定位模型（支持通知跳转、外链、楼层定位）
struct PostTargetLocation: Equatable {
    var floor: Int?
    var page: Int?
    var username: String?
    var contentSnippet: String?
    
    static func parse(
        from link: String,
        targetFloor: Int? = nil,
        targetUsername: String? = nil,
        targetSnippet: String? = nil
    ) -> PostTargetLocation {
        var page: Int? = nil
        var floor: Int? = targetFloor
        
        // 1. 尝试从 URL 查询参数解析页码 ?p=X 或 &p=X
        if let pRange = link.range(of: #"[?&]p=(\d+)"#, options: .regularExpression) {
            let pString = String(link[pRange])
            if let digits = pString.components(separatedBy: "=").last, let p = Int(digits) {
                page = p
            }
        }
        
        // 2. 尝试从 URL 锚点解析楼层编号 #replyX 或 #reply_X
        if floor == nil, link.contains("#reply") {
            let afterHash = link.components(separatedBy: "#reply").last ?? ""
            let digits = afterHash.prefix(while: { $0.isNumber })
            if let f = Int(digits), f > 0 {
                floor = f
            }
        }
        
        // 3. 如果有楼层但无显式页码，且楼层较大，按每页100条估算目标页
        if page == nil, let f = floor, f > 100 {
            page = (f - 1) / 100 + 1
        }
        
        return PostTargetLocation(
            floor: floor,
            page: page,
            username: targetUsername,
            contentSnippet: targetSnippet
        )
    }
}

// MARK: - 帖子详情视图
struct PostDetailView: View {
    @StateObject private var detailParser = PostDetailParser()
    let postId: String
    var targetFloor: Int? = nil
    var targetUsername: String? = nil
    var targetReplySnippet: String? = nil
    
    @State private var showComentView  = false

    @State private var showSendView    = false
    @State private var showRelateTopic = false
    @State private var selectedTopic: Node? = nil
    
    // 添加NavigationManager监听
    @ObservedObject private var navigationManager = NavigationManager.shared
    @State private var currentPostId: String = ""
    @Environment(\.isGKDualColumn) private var isDualColumn
    @State private var showTitleInNavBar = false
    @State private var targetJumpPage: Int? = nil
    @State private var targetJumpFloor: Int? = nil
    @State private var showJumpFloorAlert = false
    @State private var jumpFloorInput = ""
    @State private var highlightedFloor: Int? = nil
    @State private var pendingTargetLocation: PostTargetLocation? = nil

    var body: some View {
        GeometryReader { proxy in
            // 在双栏分屏模式下，右侧外层容器已自动适配了右侧安全边距和底部避让，避免重复内缩导致详情过窄；不展开竖屏时，与右边安全区域保留 8pt 舒适边距 (5~10pt)
            let safeTrailing: CGFloat = isDualColumn ? 0 : 8
            let safeBottom: CGFloat = isDualColumn ? 0 : proxy.safeAreaInsets.bottom
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // 滚动偏移监听锚点
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("detailScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        if let detail = detailParser.postDetail {
                            PostDetailContent(
                                detail: detail,
                                postId: postId,
                                detailParser: detailParser,
                                onJumpToPage: { page in
                                    jumpToCommentPage(page, scrollProxy: scrollProxy)
                                },
                                onJumpFloorTap: {
                                    jumpFloorInput = ""
                                    showJumpFloorAlert = true
                                },
                                onReturnFirstPage: {
                                    jumpToCommentPage(1, scrollProxy: scrollProxy)
                                },
                                highlightedFloor: highlightedFloor
                            )
                        } else if detailParser.isLoading {
                            PostDetailSkeletonView()
                        } else if let error = detailParser.error {
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button("重新加载") {
                                    detailParser.loadNews(postId: currentPostId)
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, safeBottom)
                }
                .coordinateSpace(name: "detailScroll")
                .onChange(of: targetJumpPage) { newPage in
                    if let page = newPage {
                        jumpToCommentPage(page, scrollProxy: scrollProxy)
                        targetJumpPage = nil
                    }
                }
                .onChange(of: targetJumpFloor) { newFloor in
                    if let floor = newFloor {
                        jumpToFloor(floor, scrollProxy: scrollProxy)
                        targetJumpFloor = nil
                    }
                }
                .onChange(of: detailParser.replies.count) { _ in
                    attemptScrollToTarget(scrollProxy: scrollProxy)
                }
                .alert("定位到具体楼层", isPresented: $showJumpFloorAlert) {
                    TextField("请输入楼层号 (如 18)", text: $jumpFloorInput)
                        .keyboardType(.numberPad)
                    Button("取消", role: .cancel) {}
                    Button("定位") {
                        if let floor = Int(jumpFloorInput.trimmingCharacters(in: .whitespacesAndNewlines)), floor > 0 {
                            jumpToFloor(floor, scrollProxy: scrollProxy)
                        } else {
                            ToastView.warningToast("请输入有效的楼层数字")
                        }
                    }
                } message: {
                    Text("请输入要跳转的楼层编号，将自动定位并高亮呈现：")
                }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                // 当向上滚动超过 70pt（头部标题已滑出导航栏可视区）时切换标题
                let shouldShow = offset < -70
                if shouldShow != showTitleInNavBar {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showTitleInNavBar = shouldShow
                    }
                }
            }
            .padding(.trailing, safeTrailing)
        }
        .refreshable {
            detailParser.loadNews(postId: currentPostId)
        }
        .tabbarToolBar()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ZStack {
                    if showTitleInNavBar, let title = detailParser.postDetail?.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 220)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                    } else {
                        Text("主题详情")
                            .font(.custom(titleFontName, size: titleFontSize))
                            .fontWeight(.light)
                            .foregroundColor(.primary)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .bottom))
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: showTitleInNavBar)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                let userIsMe = AccountState.isSelf(userName: detailParser.postDetail?.author.name ?? "")
                Menu {
                    if detailParser.totalPages > 1 {
                        Menu {
                            ForEach(1...detailParser.totalPages, id: \.self) { page in
                                Button {
                                    targetJumpPage = page
                                } label: {
                                    if page == detailParser.activeCommentPage {
                                        Label("第 \(page) 页 (当前)", systemImage: "checkmark")
                                    } else {
                                        Text("第 \(page) 页")
                                    }
                                }
                            }
                        } label: {
                            Label("选择评论页码 (共\(detailParser.totalPages)页)", systemImage: "arrow.up.and.down.circle")
                        }
                    }
                    
                    Button {
                        jumpFloorInput = ""
                        showJumpFloorAlert = true
                    } label: {
                        Label("定位到具体楼层...", systemImage: "number")
                    }
                    
                    Button {
                        showRelateTopic.toggle()
                    } label: {
                        Label("相关主题", systemImage: .topics)
                    }
                    
                    
                    Button {
                        shareContent()
                    } label: {
                        Label("分享", systemImage: .share)
                    }
                    
                    Button {
                        postId.postDetailUrl.copyToClipboard()
                    } label: {
                        Label("拷贝链接", systemImage: .copy)
                    }

                   
                    Button {
                        postId.postDetailUrl.openURL()
                    } label: {
                        Label("网页查看详情", systemImage: .safari)
                    }
                    
                    Button {
                        if LoginStateChecker.isLogin {
                            showComentView = true
                        } else {
                            LoginStateChecker.LoginStateHandle()
                        }
                    } label: {
                        Label("评论", systemImage: .coment)
                    }
                    
                    
                    if userIsMe {
//                        Button {
//                            if LoginStateChecker.isLogin {
//                                showSendView.toggle()
//                            } else {
//                                LoginStateChecker.LoginStateHandle()
//                            }
//                        } label: {
//                            Label("编辑", systemImage: .edit)
//                        }
//                        .font(.caption)
                    }
                    
                    if !userIsMe {
                        Button {
                            ToastView.reportToast()
                        } label: {
                            Label("举报", systemImage: .report)
                        }
                    }

                } label: {
                    SFSymbol.more
                }
            }
        }
        .sheet(isPresented: $showRelateTopic) {
            RelatedTopicView(isPresented: $showRelateTopic, viewModel: detailParser)
        }
        .sheet(isPresented: $showSendView) {
            SendPostView(isPresented: $showSendView, selectedTopic: $selectedTopic, postDetail: detailParser.postDetail) {
                
            }
            .presentationDetents([.height(isPadOrWideScreen ? screenHeight : screenHeight/2), .medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showComentView) { isPresented in
            if isPresented {
                let detailId = detailParser.postDetail?.detailId ?? ""
                let username = detailParser.postDetail?.author.name ?? ""
                CommentInputManager.shared.showCommentInput(detailId: detailId, replyUser: "", username: username) {
                    showComentView = false
                }
            }
        }
        .onAppear() {
            logger("[PostDetailView] onAppear, postId: \(postId)")
            
            // 解析潜在的通知/外链定位目标（支持楼层锚点、页码及回复作者定位）
            let target = PostTargetLocation.parse(
                from: postId,
                targetFloor: targetFloor,
                targetUsername: targetUsername,
                targetSnippet: targetReplySnippet
            )
            if target.floor != nil || target.username != nil {
                pendingTargetLocation = target
            }
            
            // 检查NavigationManager是否有新的导航请求
            if !navigationManager.postDetailId.isEmpty && navigationManager.postDetailId != postId {
                logger("[PostDetailView] 检测到NavigationManager中的新ID，使用新ID: \(navigationManager.postDetailId)")
                currentPostId = navigationManager.postDetailId
                detailParser.loadNews(postId: currentPostId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationManager.resetNavigationState()
                }
            } else {
                currentPostId = postId
                guard detailParser.postDetail == nil else { 
                    logger("[PostDetailView] 帖子详情已存在，尝试定位目标")
                    return 
                }
                logger("[PostDetailView] 开始加载帖子详情")
                if let target = pendingTargetLocation, let page = target.page, page > 1 {
                    detailParser.jumpToPage(page, postId: postId)
                } else {
                    detailParser.loadNews(postId: postId)
                }
            }
        }
        
        .onChange(of: navigationManager.postDetailId) { newPostId in
            if !newPostId.isEmpty && newPostId != currentPostId {
                logger("[PostDetailView] 检测到新的导航请求，从 \(currentPostId) 切换到 \(newPostId)")
                currentPostId = newPostId
                // 强制重新加载，清除旧数据
                detailParser.postDetail = nil
                detailParser.replies = []
                detailParser.relatedTopics = []
                detailParser.error = nil
                detailParser.needLogin = false
                detailParser.loadNews(postId: newPostId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationManager.resetNavigationState()
                }
            }
        }
        
        // 监听detailParser的postDetail变化，确保数据同步
        .onChange(of: detailParser.postDetail?.detailId) { newDetailId in
            if let newDetailId = newDetailId, !newDetailId.isEmpty {
                logger("[PostDetailView] 帖子详情数据已更新，detailId: \(newDetailId)")
            }
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { _ in
            detailParser.loadNews(postId: currentPostId)
        }
        .onDisappear() {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
        }
    }
    
    private func jumpToCommentPage(_ page: Int, scrollProxy: ScrollViewProxy) {
        let target = max(1, min(page, detailParser.totalPages))
        // 1. 立即平滑滚动到评论区头部
        withAnimation(.easeInOut(duration: 0.3)) {
            scrollProxy.scrollTo("commentSectionAnchor", anchor: .top)
        }
        if target == detailParser.activeCommentPage && !detailParser.replies.isEmpty {
            return
        }
        // 2. 加载目标页评论数据并在完成后对齐
        detailParser.jumpToPage(target, postId: currentPostId) {
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollProxy.scrollTo("commentSectionAnchor", anchor: .top)
            }
        }
    }
    
    private func jumpToFloor(_ floor: Int, scrollProxy: ScrollViewProxy) {
        guard floor > 0 else { return }
        
        // 1. 如果当前已加载的回复列表中包含该楼层，直接平滑对齐
        if detailParser.replies.contains(where: { $0.floorNumber == floor }) {
            withAnimation(.easeInOut(duration: 0.35)) {
                scrollProxy.scrollTo("reply_floor_\(floor)", anchor: .top)
            }
            highlightFloor(floor)
            return
        }
        
        // 2. 估算所在页码并拉取
        let pageSize = detailParser.estimatedPageSize
        let targetPage = max(1, min((floor - 1) / pageSize + 1, detailParser.totalPages))
        
        // 先滚动至评论区
        withAnimation(.easeInOut(duration: 0.3)) {
            scrollProxy.scrollTo("commentSectionAnchor", anchor: .top)
        }
        
        // 3. 加载对应页数据，加载完成后定位到具体楼层并高亮
        detailParser.jumpToPage(targetPage, postId: currentPostId) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    scrollProxy.scrollTo("reply_floor_\(floor)", anchor: .top)
                }
                highlightFloor(floor)
            }
        }
    }
    
    private func highlightFloor(_ floor: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            highlightedFloor = floor
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                if highlightedFloor == floor {
                    highlightedFloor = nil
                }
            }
        }
    }
    
    private func attemptScrollToTarget(scrollProxy: ScrollViewProxy) {
        guard let target = pendingTargetLocation else { return }
        guard !detailParser.replies.isEmpty else { return }
        
        // 1. 如果有明确楼层编号
        if let targetFloor = target.floor {
            if let matched = detailParser.replies.first(where: { $0.floorNumber == targetFloor }) {
                pendingTargetLocation = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        scrollProxy.scrollTo("reply_floor_\(matched.floorNumber)", anchor: .top)
                    }
                    highlightFloor(matched.floorNumber)
                }
                return
            }
        }
        
        // 2. 如果有目标用户名，匹配作者
        if let username = target.username, !username.isEmpty {
            let userReplies = detailParser.replies.filter {
                $0.author.name.lowercased() == username.lowercased() ||
                ($0.author.displayName?.lowercased() == username.lowercased())
            }
            
            let matched: Reply?
            if let snippet = target.contentSnippet, !snippet.isEmpty {
                let cleanSnippet = snippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                matched = userReplies.first(where: {
                    !cleanSnippet.isEmpty && $0.content.contains(cleanSnippet.prefix(12))
                }) ?? userReplies.last
            } else {
                matched = userReplies.last
            }
            
            if let found = matched {
                pendingTargetLocation = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        scrollProxy.scrollTo("reply_floor_\(found.floorNumber)", anchor: .top)
                    }
                    highlightFloor(found.floorNumber)
                }
                return
            }
        }
    }
    
    func shareContent() {
        let link = postId.postDetailUrl
        if link.count > 0 {
            let textToShare = (detailParser.postDetail?.title ?? "")
            let activityController = UIActivityViewController(activityItems: [link, textToShare], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityController, animated: true, completion: nil)
            }
        }
    }
}

// MARK: - 帖子详情高保真骨架屏（杜绝白屏与 Loading 粘连）
struct PostDetailSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. 作者头像与元数据占位
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(width: 42, height: 42)
                
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(UIColor.secondarySystemFill))
                        .frame(width: 100, height: 14)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(UIColor.secondarySystemFill))
                        .frame(width: 150, height: 11)
                }
                Spacer()
            }
            .padding(.top, 4)
            
            // 2. 标题区占位
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 22)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(width: 220, height: 22)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // 3. 正文段落占位（多行错落，保持稳定视觉高度）
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 15)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 15)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 15)
                    .frame(width: 260)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 15)
                    .frame(maxWidth: .infinity)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(height: 15)
                    .frame(width: 180)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // 4. 底部操作栏占位
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(width: 68, height: 26)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(width: 50, height: 26)
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(isAnimating ? 0.35 : 0.8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 滚动偏移量偏好键（用于驱动导航栏标题切换）
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

