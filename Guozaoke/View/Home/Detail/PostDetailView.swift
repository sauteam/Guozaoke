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

    @State private var showSendView    = false
    @State private var showRelateTopic = false
    @State private var selectedTopic: Node? = nil

    var body: some View {
        ScrollView {
            LazyVStack {
                if let detail = detailParser.postDetail {
                    PostDetailContent(detail: detail, postId: postId, detailParser: detailParser)
                } else if detailParser.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
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
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("主题详情")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let userIsMe = AccountState.isSelf(userName: detailParser.postDetail?.author.name ?? "")
                Menu {
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
                        postId.postDetailUrl().copyToClipboard()
                    } label: {
                        Label("拷贝链接", systemImage: .copy)
                    }

                   
                    Button {
                        postId.postDetailUrl().openURL()
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
        }
        .sheet(isPresented: $showComentView) {
            
            let detailId = detailParser.postDetail?.detailId ?? ""
            SendCommentView(detailId: detailId, replyUser: "", username: detailParser.postDetail?.author.name ?? "", isPresented: $showComentView) {
                
            }
            .presentationDetents([.height(160)])
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
        let link = postId.postDetailUrl()
        let textToShare = (detailParser.postDetail?.title ?? "")
        let activityController = UIActivityViewController(activityItems: [textToShare, link], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true, completion: nil)
        }
    }
}

