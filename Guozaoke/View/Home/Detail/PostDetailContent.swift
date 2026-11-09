//
//  PostDetailContent.swift
//  Guozaoke
//
//  Created by scy on 2025/3/3.
//

import SwiftUI


private var devContent: String {
    let ttt = ""
#if DEBUG
    //ttt = "<br /> <p>写一个样式调试测试：<br /> 测试邮箱：<a target=\"_blank\" href=\"mailto:i@guozaoke.com\">i@guozaoke.com</a> 跳转<br /> 手机号：19078787878<br /> <a target=\"_blank\" href=\"/u/isau\" class=\"user-mention\">@isau</a> <br /> tag #过早客#</p> \n<p><a target=\"_blank\" href=\"https://www.guozaoke.com/t/118684\">https://www.guozaoke.com/t/118684</a></p>"
#endif
    return ttt
}

private var commentStyle: String {
    let ttt = ""
#if DEBUG
    //ttt = "\n i@guozaoke.com 手机号：19078787878 \n @isau tag #过早客# https://www.guozaoke.com/t/118684"
#endif
    return ttt
}


// MARK: - 帖子详情内容视图
struct PostDetailContent: View, Equatable {
    
    let detail: PostDetail
    let postId: String
    @ObservedObject var detailParser: PostDetailParser
    var onJumpPageTap: (() -> Void)? = nil
    var onReturnFirstPage: (() -> Void)? = nil
    var highlightedFloor: Int? = nil
    @State private var showUserInfo = false
    @State private var linkUserId = ""
    
    static func == (lhs: PostDetailContent, rhs: PostDetailContent) -> Bool {
        return lhs.detail.id == rhs.detail.id &&
               lhs.detailParser.activeCommentPage == rhs.detailParser.activeCommentPage &&
               lhs.detailParser.replies.count == rhs.detailParser.replies.count &&
               lhs.detailParser.isJumpingPage == rhs.detailParser.isJumpingPage &&
               lhs.highlightedFloor == rhs.highlightedFloor
    }
    
    var body: some View {

        VStack(alignment: .leading, spacing: 16) {
            let replay = detail.replies.last
            let post = PostItem(
                title: detail.title,
                link: postId,
                author: detail.author.name,
                avatar: detail.author.avatar,
                node: detail.author.node,
                nodeUrl: detail.nodeUrl,
                time: detail.author.joinDate ?? "",
                replyCount: detail.replies.count,
                lastReplyUser: replay?.author.name,
                rowEnum: .detailRow,
                isOnline: detail.author.isOnline,
                level: detail.author.level,
                displayName: detail.author.displayName
            )

            PostRowView(post: post)
                .padding(.horizontal)
            let detailContent = "\(detail.contentHtml)" + devContent
            if !detailContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                RichTextView(content: detailContent)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            // 帖子图片
            if !detail.images.isEmpty {
                //PostImagesView(images: detail.images)
                    //.padding(.horizontal)
            }
            
            PostFooterView(detail: detail, detailParser: detailParser, postId: postId)
                .padding(.top, 4)
            
            // 评论区定位锚点
            Color.clear
                .frame(height: 1)
                .id("commentSectionAnchor")
            
            Divider()
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
            // 回复列表
            if !detailParser.replies.isEmpty || detailParser.isJumpingPage {
                ReplyListView(
                    detailParser: detailParser,
                    highlightedFloor: highlightedFloor,
                    onJumpTap: onJumpPageTap,
                    onReturnFirstPage: onReturnFirstPage
                )
                .padding(.horizontal)
                    
            }
        }
    }
}


struct PostFooterView: View {
    var detail: PostDetail
    @ObservedObject var detailParser: PostDetailParser
    let postId: String
    @State private var isLoading: Bool = false
    @State private var message: String?
    @State private var showComentView  = false

    var body: some View {
                
        HStack {
            Button {
                hapticFeedback()
                Task {
                    do {
                        let model = await detailParser.fetchCollectionAction(link: detailParser.postDetail?.collectionsLink)
                        if model?.success == 1 {
                            
                        } else if model?.success == 0 {
                            
                        }
                    }
                }
            } label: {
                Text(detailParser.postDetail?.collectionString ?? "加入收藏")
            }
            .padding(.horizontal, 16)
            .font(.caption)
            .lineLimit(1)

            Button {
                hapticFeedback()
                Task {
                    do {
                        let _ = await detailParser.fetchCollectionAction(link: detail.zanLink, voted: !detailParser.isZan)
                    }
                }

            } label: {
                Text(detailParser.postDetail?.zanString ?? "赞")
            }
            .font(.caption)
            .disabled(detailParser.isZan)
            .padding(.horizontal, 2)
            .lineLimit(1)
                        
            Button {
                
            } label: {
                Text(detailParser.zanColHit)
            }
            .font(.caption)
            .disabled(true)
            .padding(.horizontal, 2)
            .lineLimit(1)
            
            Button {
                hapticFeedback()
                if LoginStateChecker.isLogin {
                    showComentView = true
                } else {
                    LoginStateChecker.LoginStateHandle()
                }
            } label: {
                Text("评论")
            }
            .font(.caption)
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
    }
}

// MARK: - 回复列表视图
struct ReplyListView: View {
    @ObservedObject var detailParser: PostDetailParser
    var highlightedFloor: Int? = nil
    var onJumpTap: (() -> Void)? = nil
    var onReturnFirstPage: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Text("全部回复")
                    .titleFontStyle()
                if detailParser.activeCommentPage > 1 {
                    Text("(第 \(detailParser.activeCommentPage) 页)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if !detailParser.replies.isEmpty {
                    Text("(\(detailParser.replies.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if detailParser.totalPages > 1 {
                Button {
                    onJumpTap?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 13))
                        Text("第 \(detailParser.activeCommentPage)/\(detailParser.totalPages) 页")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        
        if detailParser.activeCommentPage > 1 {
            HStack {
                Label("当前定位在第 \(detailParser.activeCommentPage) 页评论", systemImage: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    onReturnFirstPage?()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption2)
                        Text("返回第 1 页")
                            .font(.caption.weight(.medium))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.7))
            .cornerRadius(8)
        }
        
        if detailParser.isJumpingPage {
            HStack(spacing: 8) {
                Spacer()
                ProgressView()
                Text("正在加载第 \(detailParser.activeCommentPage) 页评论...")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 32)
        } else {
            ForEach(detailParser.replies.indices, id: \.self) { index in
                if index < detailParser.replies.count {
                    let replyItem = detailParser.replies[index]
                    let floorNum = replyItem.floorNumber
                    ReplyItemView(
                        detailParser: detailParser,
                        reply: $detailParser.replies[index],
                        isHighlighted: highlightedFloor == floorNum
                    )
                    .id("reply_floor_\(floorNum)")
                    .onAppear {
                        if index == detailParser.replies.count - 1 {
                            detailParser.loadMore()
                        }
                    }
                }
            }
            if detailParser.isLoading && !detailParser.replies.isEmpty {
                HStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                    Text("正在加载回复...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if !detailParser.hasMore {
                HStack {
                    Spacer()
                    Text(NoMoreDataTitle.homeList)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 15)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 回复
struct ReplyItemView: View {
    @ObservedObject var detailParser: PostDetailParser
    @Binding var reply: Reply
    var isHighlighted: Bool = false
    @State private var showActions = false
    @State private var isUserNameInfoViewActive = false
    @State private var isAvatarInfoViewActive = false
    @State private var showSafari = false
    @State private var showSystemCopy = false
    @State private var urlToOpen: URL?
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack(alignment: .bottomTrailing) {
                    KFImageView(reply.author.avatar)
                        .avatar()
                    
                    if reply.author.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 1.5))
                            .offset(x: 1, y: 1)
                    }
                }
                .onTapGesture {
                    isAvatarInfoViewActive = true
                }
                .navigationDestination(isPresented: $isAvatarInfoViewActive) {
                    UserInfoView(userId: reply.author.name)
                }
                VStack {
                    HStack(spacing: 4) {
                        Text(reply.author.displayName?.isEmpty == false ? reply.author.displayName! : reply.author.name)
                            .usernameFontStyle()
                        
                        if let level = reply.author.level, !level.isEmpty {
                            Text(level)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .stroke(Color.secondary.opacity(0.5), lineWidth: 0.7)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        isUserNameInfoViewActive = true
                    }
                    .navigationDestination(isPresented: $isUserNameInfoViewActive, destination: {
                        UserInfoView(userId: reply.author.name)
                    })
                    HStack {
                        Text(reply.time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer()
                Button {
                    showActions = true
                } label: {
                    Label("回复", systemImage: .reply)
                }
                .font(.caption)
                .onChange(of: showActions) { isPresented in
                    if isPresented {
                        let detailId = detailParser.postId ?? ""
                        let replyUser = "@" + reply.author.name + " \(reply.author.floor ?? "1") "
                        CommentInputManager.shared.showCommentInput(detailId: detailId, replyUser: replyUser, username: reply.author.name) {
                            showActions = false
                        }
                    }
                }
                let number  = reply.like
                let zanText = reply.isLiked ? "已赞 \(number)" : "赞 \(number)"
                Text(zanText)
                    .font(.caption)
                    .foregroundColor(reply.isLiked ? .accentColor : .secondary)
                    .disabled(reply.isLiked)
                    .tag(reply.likeLink)
                    .onTapGesture {
                        hapticFeedback()
                        if reply.isLiked {
                            return
                        }
                        Task {
                            do {
                                let model = await detailParser.fetchCollectionAction(link: reply.likeLink, voted: true)
                                if model?.success == 1 {
                                    DispatchQueue.main.async {
                                        reply.isLiked = true
                                        if let newCount = model?.count {
                                            reply.like = newCount
                                        } else {
                                            reply.like += 1
                                        }
                                        ToastView.successToast("点赞成功")
                                    }
                                } else {
                                    if model?.message?.contains("already_voted") == true {
                                        DispatchQueue.main.async {
                                            reply.isLiked = true
                                            ToastView.successToast("已点赞")
                                        }
                                    }
                                }
                            }
                        }
                    }
                
                Text(reply.floor)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            let content = "\(reply.content)" + commentStyle
            //纯文本解析
            HTMLContentView(content: content, fontSize: subTitleFontSize, showReport: true)
///                .dynamicContextMenu(userInfo: reply.content, report: true, showSafari: $showSafari, showSystemCopy: $showSystemCopy)
            if !reply.images.isEmpty {
                PostImagesView(images: reply.images)
            }
            
            Divider()
                .frame(maxWidth: .infinity)
        }
        .padding(isHighlighted ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        .sheet(isPresented: $showSafari) {
            if let url = urlToOpen {
                SafariView(url: url)
            }
        }
        .sheet(isPresented: $showSystemCopy) {
            CopyableTextSheet(isPresented: $showSystemCopy, text: $text)
                .presentationDetents([.height(200), .medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showSafari) { newValue in
            urlToOpen = reply.content.extractURLs.first
        }
        .onAppear() {
            text = reply.content
        }
    }
}

// MARK: - 图片预览
struct ImagePreview: Identifiable {
    let id = UUID()
    let imageUrl: String
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                KFImageView(imageUrl)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarItems(trailing: Button("关闭") {
                // 关闭预览
            })
        }
    }
}

// MARK: - 图片预览

struct BottomCommentView: View {
    
    var body: some View {
        HStack {
            Button {
                
            } label: {
                Text("写点什么")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
            }
            
            
            Button {
                
            } label: {
                SFSymbol.heartFill
            }
            
            Button {
                
            } label: {
                SFSymbol.share
            }
            
            Button {
                
            } label: {
                SFSymbol.topics
            }
            
        }
    }
}

// TODO: 大图优化
// MARK: - 帖子图片视图
struct PostImagesView: View {
    let images: [PostImage]
    @State private var selectedImage: String?
    
    var body: some View {
        let urls = images.map { $0.url }
        VStack(alignment: .leading, spacing: 12) {
            ForEach(urls, id: \.self) { imageUrl in
                OptimizedImageView(
                    urlString: imageUrl,
                    contentMode: .fit,
                    autoResize: true,
                    showPreview: true
                ).frame(height: 200)
            }
        }
    }
}
