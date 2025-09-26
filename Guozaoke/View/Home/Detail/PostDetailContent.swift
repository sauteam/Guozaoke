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
            let detailContent = "\(detail.contentHtml)" + devContent
            RichTextView(content: detailContent)
                .padding(.horizontal)
            // 帖子图片
            if !detail.images.isEmpty {
                //PostImagesView(images: detail.images)
                    //.padding(.horizontal)
            }
            
            PostFooterView(detail: detail, detailParser: detailParser, postId: postId)
            Divider()
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
            // 回复列表
            if !detail.replies.isEmpty {
                ReplyListView(detailParser: detailParser, replies: detailParser.replies)
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
                        let model = await detailParser.fetchCollectionAction(link: detail.zanLink)
                        if model?.success == 1 {
                        } else if model?.success == 0 {
                        }
                    }
                }

            } label: {
                Text(detailParser.postDetail?.zanString ?? "感谢")
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
        .sheet(isPresented: $showComentView) {
            
            let detailId = detailParser.postDetail?.detailId ?? ""
            SendCommentView(detailId: detailId, replyUser: "", username: detailParser.postDetail?.author.name ?? "", isPresented: $showComentView) {
                
            }
            .presentationDetents([.height(isiPad ? screenHeight: 200)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - 回复列表视图
struct ReplyListView: View {
    @ObservedObject var detailParser: PostDetailParser
    @State  var replies: [Reply]
    
    var body: some View {
        Text("全部回复 (\(replies.count))")
            .titleFontStyle()
        ForEach($replies) { $reply in
            ReplyItemView(detailParser: detailParser, reply: $reply)
                .onAppear {
                    if reply.id == replies.last?.id {
                        detailParser.loadMore()
                    }
                }
        }
        if !detailParser.hasMore {
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

// MARK: - 回复
struct ReplyItemView: View {
    @ObservedObject var detailParser: PostDetailParser
    @Binding var reply: Reply
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
                KFImageView(reply.author.avatar)
                    .avatar()
                    .onTapGesture {
                        isAvatarInfoViewActive = true
                    }
                    .navigationDestination(isPresented: $isAvatarInfoViewActive) {
                        UserInfoView(userId: reply.author.name)
                    }
                VStack {
                    Text(reply.author.name)
                        .usernameFontStyle()
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
                .sheet(isPresented: $showActions) {
                    SendCommentView(detailId: detailParser.postId ?? "" , replyUser: "@" + reply.author.name + " \(reply.author.floor ?? "1") ", username: reply.author.name, isPresented: $showActions) {
                        
                    }
                    .presentationDetents([.height(isiPad ? screenHeight: 200)])
                    .presentationDragIndicator(.visible)
                }
                let number  = reply.like
                let zanText = "赞 \(number)"
                Text(zanText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .disabled(reply.isLiked)
                    .tag(reply.likeLink)
                    .onTapGesture {
                        hapticFeedback()
                        if reply.isLiked {
                            return
                        }
                        Task {
                            do {
                                let model = await detailParser.fetchCollectionAction(link: reply.likeLink)
                                if model?.success == 1 {
                                    DispatchQueue.main.async {
                                        reply.isLiked = true
                                        reply.like += 1
                                    }
                                } else {
                                    if model?.message?.contains("already_voted") == true {
                                        reply.isLiked = true
                                        ToastView.successToast("已点赞")
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
                    .frame(width: screenWidth-100)
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
