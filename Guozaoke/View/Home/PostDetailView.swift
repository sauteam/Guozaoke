//
//  PostDetail.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import Kingfisher
import JDStatusBarNotification

// MARK: - 帖子详情视图
struct PostDetailView: View {
    @StateObject private var detailParser = PostDetailParser()
    let postId: String
    @State private var showComentView  = false

    var body: some View {
        ScrollView {
            LazyVStack {
                if let detail = detailParser.postDetail {
                    PostDetailContent(detail: detail, postId: postId, detailParser: detailParser)
                } else if detailParser.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !detailParser.hasMore {
                    HStack {
                        Spacer()
                        Text(NoMoreDataTitle.commentList)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            detailParser.loadNews(postId: postId)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("主题详情")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                
                Menu {
                    Button {
                        shareContent()
                    } label: {
                        
                        Label("分享", systemImage: .share)
                    }
                    
                    Button {
                        showComentView = true
                    } label: {
                        
                        Label("评论", systemImage: .coment)
                    }
                    
                    Button {
                        postId.postDetailUrl().openURL()
                    } label: {
                        Label("网页查看详情", systemImage: .safari)
                    }

                    if !AccountState.isSelf(userName: detailParser.postDetail?.author.name ?? "") {
                        Button {
                            NotificationPresenter.shared.present("谢谢反馈，我们已收到", includedStyle: .dark, duration: toastDuration)
                        } label: {
                            Label("举报", systemImage: .report)
                        }
                    }

                } label: {
                    SFSymbol.more
                }
            }
        }
        .sheet(isPresented: $showComentView) {
            let detailId = detailParser.postDetail?.detailId ?? ""
            SendCommentView(detailId: detailId, replyUser: "", isPresented: $showComentView) {
                
            }
        }
        .onAppear() {
            guard detailParser.postDetail == nil else { return }
            detailParser.loadNews(postId: postId)
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { _ in
            detailParser.loadNews(postId: postId)
        }
        .onDisappear() {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
        }
    }
    
    func shareContent() {
        postId.postDetailUrl().copyToClipboard()
        let textToShare = detailParser.postDetail?.title ?? ""
        let link = postId.postDetailUrl()
        let activityController = UIActivityViewController(activityItems: [textToShare, link], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true, completion: nil)
        }
    }
}

// MARK: - 帖子详情内容视图
struct PostDetailContent: View, Equatable {
    let detail: PostDetail
    let postId: String
    @ObservedObject var detailParser: PostDetailParser
    @State private var showUserInfo = false
    @State private var linkUserId = ""
    
    static func == (lhs: PostDetailContent, rhs: PostDetailContent) -> Bool {
        return lhs.detail.id == rhs.detail.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let replay = detail.replies.last
            let post = PostItem(title: detail.title, link: postId, author: detail.author.name, avatar: detail.author.avatar, node: detail.author.node, nodeUrl: detail.nodeUrl, time: detail.author.joinDate ?? "", replyCount: detail.replies.count, lastReplyUser: replay?.author.name, rowEnum: .detailRow)

            PostRowView(post: post)
                .padding(.horizontal)
            
            // 帖子内容
            HTMLContentView(
                content: detail.content,
                fontSize: 16
                
//                onLinkTap: { url in
//                    print("Link tapped: \(url)")
//                },
//                onUserTap: { userUrl in
//                    linkUserId = userUrl.htmlUserId() ?? ""
//                    showUserInfo = true
//                }
            )
            .id(UUID())
            
            ////RichTextView(content: detail.content)
                .padding(.horizontal)
            // 帖子图片
            if !detail.images.isEmpty {
                PostImagesView(images: detail.images)
                    .padding(.horizontal)
            }
            
            PostFooterView(detail: detail, detailParser: detailParser, postId: postId)
            Divider()
                .padding(.vertical, 2)
            // 回复列表
            if !detail.replies.isEmpty {
                ReplyListView(detailParser: detailParser, replies: detail.replies)
                    .padding(.horizontal)
                    
            }
        }
    }
}

// MARK: - 帖子头部视图
struct PostHeaderView: View {
    let detail: PostDetail
    let postId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                KFImageView(detail.author.avatar)
                    .avatar()
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.author.name)
                        .font(.headline)
                    Text(detail.author.joinDate ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(detail.node)
                .font(.subheadline)
                .foregroundColor(.blue)
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

struct PostFooterView: View {
    var detail: PostDetail
    @ObservedObject var detailParser: PostDetailParser
    let postId: String
    @State private var isLoading: Bool = false
    @State private var message: String?

    var body: some View {
                
        HStack {

            Button {
                Task {
                    do {
                        let model = await detailParser.fetchCollectionAction(link: detailParser.postDetail?.collectionsLink)
                        if model?.success == 1 {
                            hapticFeedback()
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
                Task {
                    do {
                        let model = await detailParser.fetchCollectionAction(link: detail.zanLink)
                        if model?.success == 1 {
                            hapticFeedback()
                        }
                    }
                }

            } label: {
                Text(detailParser.postDetail?.zanString ?? "感谢")
            }
            .font(.caption)
            .disabled(detailParser.isZan)
            .padding(.horizontal, 5)
            .lineLimit(1)

            Button {
                
            } label: {
                Text("\(detail.collections)")
            }
            .padding(.horizontal, 10)
            .font(.caption)
            .disabled(true)
            .lineLimit(1)

            Button {
                
            } label: {
                Text(detail.zans)
            }
            .font(.caption)
            .disabled(true)
            .lineLimit(1)

            Button {
                
            } label: {
                Text(detail.hits)
            }
            .font(.caption)
            .disabled(true)
            .lineLimit(1)
        }
    }
}

// MARK: - 回复列表视图
struct ReplyListView: View {
    @ObservedObject var detailParser: PostDetailParser
    let replies: [Reply]
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            Text("全部回复 (\(replies.count))")
                .font(.headline)
            ForEach(replies) { reply in
                ReplyItemView(detailParser: detailParser, reply: reply)
                    .onAppear {
                        if reply == replies.last {
                            detailParser.loadMore()
                        }
                    }
            }
        }
    }
}

// MARK: - 回复项视图
struct ReplyItemView: View {
    @ObservedObject var detailParser: PostDetailParser
    let reply: Reply
    @State private var showActions = false
    @State private var isUserNameInfoViewActive = false
    @State private var isAvatarInfoViewActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 回复头部
            HStack {
                KFImageView(reply.author.avatar)
                    .avatar()
                    .onTapGesture {
                        isAvatarInfoViewActive = true
                    }
                    .overlay {
                        NavigationLink(
                            destination: UserInfoView(userId: reply.author.name),
                                isActive: $isAvatarInfoViewActive
                            ) {
                                EmptyView()
                            }.hidden()
                    }
                
                VStack {
                    Text(reply.author.name)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            isUserNameInfoViewActive = true
                        }
                        .overlay {
                            NavigationLink(
                                destination: UserInfoView(userId: reply.author.name),
                                    isActive: $isUserNameInfoViewActive
                                ) {
                                    EmptyView()
                                }.hidden()
                        }
                    
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
                .sheet(isPresented: $showActions) {
                    SendCommentView(detailId: detailParser.postId ?? "" , replyUser: "@" + reply.author.name + " \(reply.author.floor ?? "1") ", isPresented: $showActions) {
                        
                    }
                }
                Text(reply.like)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        Task {
                            do {
                                let model = await detailParser.fetchCollectionAction(link: reply.likeLink)
                                if model?.success == 1 {
                                    hapticFeedback()
                                }
                            }
                        }
                    }
                
                Text(reply.floor)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 回复内容
            HTMLContentView(content: reply.content)
            
            // 回复图片
            if !reply.images.isEmpty {
                PostImagesView(images: reply.images)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .contextMenu {
            Button {
                reply.content.copyToClipboard()
            } label: {
                Label("拷贝内容", systemImage: .copy)
            }
                        
//            Button {
//                
//            } label: {
//                Label("回复", systemImage: .reply)
//            }
            
//            Button {
//                
//            } label: {
//                Label("举报", systemImage: .report)
//            }
           
        }
//        .actionSheet(isPresented: $showActions) {
//            ActionSheet(
//                title: Text("回复操作"),
//                buttons: [
//                    .default(Text("回复")) {
//                        
//                    },
//                    .default(Text("拷贝")) { },
//                    .destructive(Text("举报")) { },
//                    .cancel()
//                ]
//            )
//        }
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
