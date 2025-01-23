//
//  PostDetail.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

// MARK: - 帖子详情视图
struct PostDetailView: View {
    @StateObject private var detailParser = PostDetailParser()
    let postId: String
    @State private var showComentView  = false

    var body: some View {
        ScrollView {
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

                } label: {
                    SFSymbol.more
                }
            }
        }
        .sheet(isPresented: $showComentView) {
            SendCommentView(detailId: detailParser.postDetail?.detailId ?? "", replyUser: "", isPresented: $showComentView) {
                
            }
        }
        .onAppear() {
            if  detailParser.postDetail == nil {
                detailParser.loadNews(postId: postId)
            }
        }
    }
    
    func shareContent() {
        postId.postDetailUrl().copyToClipboard()
        let textToShare = detailParser.postDetail?.title
        let activityController = UIActivityViewController(activityItems: [textToShare!], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true, completion: nil)
        }
    }
}

// MARK: - 帖子详情内容视图
struct PostDetailContent: View {
    let detail: PostDetail
    let postId: String
    let detailParser: PostDetailParser
//    let quoteFont = Style.font(UIFont.systemFont(ofSize: 16))
//        .foregroundColor(.black)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let replay = detail.replies.last
            let post = PostItem(title: detail.title, link: postId, author: detail.author.name, avatar: detail.author.avatar, node: detail.author.node, nodeUrl: detail.nodeUrl, time: detail.author.joinDate ?? "", replyCount: detail.replies.count, lastReplyUser: replay?.author.name, rowEnum: .detailRow)

            PostRowView(post: post)
                .padding(.horizontal)
            
            // 帖子内容
            HTMLContentView(content: detail.content)
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

// MARK: - 帖子图片视图
struct PostImagesView: View {
    let images: [PostImage]
    @State private var selectedImage: String?
    
    var body: some View {
        let urls = images.map { $0.url }
        VStack(alignment: .leading, spacing: 12) {
            ForEach(urls, id: \.self) { imageUrl in
                KFImageView(imageUrl)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .sheet(item: Binding(
            get: { selectedImage.map { ImagePreview(imageUrl: $0) } },
            set: { _ in selectedImage = nil }
        )) { preview in
            
        }
    }
}

struct PostFooterView: View {
    var detail: PostDetail
    let detailParser: PostDetailParser
    let postId: String
    @State private var isLoading: Bool = false
    @State private var message: String?

    var body: some View {
                
        HStack {

            Button {
                Task {
                    do {
                        let model = await detailParser.fetchCollectionAction(link: detailParser.favUrl)
                        if model?.success == 1 {
                            hapticFeedback()
                            detailParser.loadNews(postId: postId)
                            DispatchQueue.main.async {
                                detailParser.isCollection.toggle()
                                log("isCollection \(detailParser.isCollection)")
                            }
                        }
                    }
                }
            } label: {
                ///Text(detailParser.colText)
                Text(detailParser.isCollection ? "取消收藏": "加入收藏")
            }
            .padding(.horizontal, 16)
            .font(.caption)
            .lineLimit(1)

            Button {
                Task {
                    do {
                        let model = await detailParser.fetchCollectionAction(link: detail.zanLink)
                        if model?.success == 1 {
                            detailParser.loadNews(postId: postId)
                            hapticFeedback()
                            DispatchQueue.main.async {
                                detailParser.isZan.toggle()
                                log("isZan \(detailParser.isZan)")
                            }
                        }
                    }
                }

            } label: {
                //Text(detailParser.zanText)
                Text(detailParser.isZan ? "已感谢":"感谢")
            }
            .font(.caption)
            .disabled(detailParser.isZan ? true: false)
            .padding(.horizontal, 5)
            .lineLimit(1)

            Button {
                
            } label: {
                Label("\(detail.collections)", systemImage: .collectionFill)
            }
            .padding(.horizontal, 10)
            .font(.caption)
            .disabled(true)
            .lineLimit(1)

            Button {
                
            } label: {
                Label("\(detail.zans)", systemImage: .zan)
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
    let detailParser: PostDetailParser
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
    let detailParser: PostDetailParser
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
                    .background {
                        NavigationLink(
                            destination: UserInfoView(userId: reply.author.name),
                                isActive: $isAvatarInfoViewActive
                            ) {
                                EmptyView()
                            }.hidden()
                    }
                
                if AccountState.isSelf(userName: reply.author.name) {
                    Text("楼主")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Text(reply.author.name)
                    .font(.subheadline)
                    .onTapGesture {
                        isUserNameInfoViewActive = true
                    }
                    .background {
                        NavigationLink(
                            destination: UserInfoView(userId: reply.author.name),
                                isActive: $isUserNameInfoViewActive
                            ) {
                                EmptyView()
                            }.hidden()
                    }
                
                Spacer()
                
                Button {
                    showActions = true
                } label: {
                    Label("回复", systemImage: .reply)
                }
                .font(.caption)
                .sheet(isPresented: $showActions) {
                    SendCommentView(detailId: detailParser.postId ?? "" , replyUser: reply.author.name, isPresented: $showActions) {
                        
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
            
            Text(reply.time)
                .font(.caption)
                .foregroundColor(.secondary)
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

//// MARK: - 帖子详情视图
//struct PostDetailView: View {
//    @StateObject private var detailParser = PostDetailParser()
//    let postId: String
//    @State private var showLoginSheet = false
//    //@Binding var hideTabBar: Bool
//
//    var body: some View {
//        ScrollView {
//            if let detail = detailParser.postDetail {
//                VStack(alignment: .leading, spacing: 16) {
//                    PostDetailContent(detail: detail, postId: postId)
//                }
//            } else if detailParser.isLoading {
//                ProgressView()
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
//        }
//        .refreshable {
//            detailParser.loadPostDetail(id: postId)
//        }
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationTitle("详情")
//        .sheet(isPresented: $detailParser.needLogin) {
//            LoginView(isPresented: $detailParser.needLogin) {
//                // 登录成功后重新加载
//                detailParser.loadPostDetail(id: postId)
//            }
//        }
//        .onAppear {
//            if !detailParser.isLoading  {
//                detailParser.loadPostDetail(id: postId)
//            }
//        }
//        
//        .onDisappear {
//            
//        }
//    }
//}
//
//// MARK: - 帖子详情内容视图
//struct PostDetailContent: View {
//    let detail: PostDetail
//    let postId: String
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            let replay = detail.replies.last
//            let post = PostItem(title: detail.content, link: postId, author: detail.author.name, avatar: detail.author.avatar, category: detail.author.node, time: detail.author.joinDate ?? "", replyCount: detail.replies.count, lastReplyUser: replay?.author.name)
//            PostRowView(post: post)
//                .padding(.horizontal)
//            // 帖子内容
//            HTMLContentView(content: detail.content)
//                .padding(.horizontal)
//            // 图片展示
//            if !detail.images.isEmpty {
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack {
////                        ForEach(detail.images, id: \.self) { imageUrl in
////                            AsyncImage(url: URL(string: imageUrl)) { image in
////                                image
////                                    .resizable()
////                                    .aspectRatio(contentMode: .fit)
////                            } placeholder: {
////                                Color.gray
////                            }
////                            .frame(height: 200)
////                        }
//                    }
//                }
//                .padding(.horizontal)
//            }
//            
//            Divider()
//            
//            // 回复列表
//            if !detail.replies.isEmpty {
//                Text("全部回复 (\(detail.replies.count))")
//                    .font(.headline)
//                    .padding(.horizontal)
//                
//                ForEach(detail.replies) { reply in
//                    ReplyItemView(reply: reply)
//                        .padding(.horizontal)
//                }
//            }
//        }
//    }
//}
//
//struct ReplyListView: View {
//    let replies: [Reply]
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            ForEach(replies) { reply in
//                ReplyItemView(reply: reply)
//            }
//        }
//    }
//}
//
//struct ReplyItemView: View {
//    let reply: Reply
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                AsyncImage(url: URL(string: reply.author.avatar)) { image in
//                    image.resizable()
//                } placeholder: {
//                    Color.gray
//                }
//                .frame(width: 32, height: 32)
//                .clipShape(Circle())
//                
//                Text(reply.author.name)
//                    .font(.subheadline)
//                
//                Spacer()
//                
//                Text("回复")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .onTapGesture {
//                        log("点击回复")
//                    }
//
//                Text(reply.like)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .onTapGesture {
//                        log("点击喜欢")
//                    }
//
//                Text(reply.floor)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .onTapGesture {
//                        log("点击楼层")
//                    }
//            }
//            
//            Text(reply.content)
//                .font(.body)
//            
////            ForEach(reply.images, id: \.self) { imageUrl in
////                AsyncImage(url: URL(string: imageUrl)) { image in
////                    image
////                        .resizable()
////                        .aspectRatio(contentMode: .fit)
////                } placeholder: {
////                    Color.gray
////                }
////            }
//            
//            Text(reply.time)
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//        .padding()
//        .background(Color(.systemGray6))
//        .cornerRadius(8)
//        .onLongPressGesture {
//            log("长按回复")
//        }
//    }
//}
