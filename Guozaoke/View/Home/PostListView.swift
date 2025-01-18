//
//  PostListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI

// MARK: - 帖子列表视图
struct PostListView: View {
    @State private var selectedTab: PostListType = .latest
    @State private var posts: [PostItem] = []
    @State private var isLoading = false
    @Environment(\.themeColor) private var themeColor: Color
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部分类按钮
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(PostListType.allCases, id: \.self) { type in
                            Button(action: {
                                selectedTab = type
                            }) {
                                VStack(spacing: 8) {
                                    Text(type.rawValue)
                                        .foregroundColor(selectedTab == type ? .blue : .gray)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Rectangle()
                                        .fill(selectedTab == type ? Color.blue : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 分割线
                Divider()
                
                // 帖子列表内容
                TabView(selection: $selectedTab) {
                    ForEach(PostListType.allCases, id: \.self) { type in
                        PostListContentView(type: type)
                            .tag(type)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    
                }) {
                    Image(systemName: "plus")
                }
                .foregroundColor(.brown)
            }
        }
    }
}

//

// MARK: - 帖子列表内容视图
struct PostListContentView: View {
    let type: PostListType
    @StateObject private var viewModel = PostListParser()

    var body: some View {
            List {
                ForEach(viewModel.posts) { post in
                    NavigationLink {
                        PostDetailView(postId: post.link)
                    } label: {
                        PostRowView(post: post)
                            .onAppear {
                                if post == viewModel.posts.last {
                                    viewModel.loadPosts(type: type)
                                    print("2 type \(type)")
                                }
                            }
                    }
                    
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if !viewModel.hasMore, !viewModel.posts.isEmpty {
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
                viewModel.refresh(type: type)
            }
            .id(type)
            .task {
                if viewModel.posts.isEmpty {
                    viewModel.refresh(type: type)
                }
                print("1 type \(type)")
            }
            .alert("错误", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.error ?? "")
            }            
    }
}


//// 预览
//struct PostRowView_Previews: PreviewProvider {
//    static var previews: some View {
//        List {
//            PostRowView(post: PostItem(
//                title: "全国各地的豪车都在赶往魔都武康路",
//                link: "/t/117529",
//                author: "FlyRen9",
//                avatar: "https://cdn.guozaoke.com//static/avatar/9/m_default.png",
//                category: "汤逊湖",
//                time: "2 分钟前",
//                replyCount: 6,
//                lastReplyUser: "abc_11"
//            ))
//
//            PostRowView(post: PostItem(
//                title: "武汉电信宽带大家都是多少钱办的",
//                link: "/t/117479",
//                author: "harvies",
//                avatar: "https://cdn.guozaoke.com//static/avatar/19/m_c2a54540-0567-11ef-a0b7-00163e134dca.png",
//                category: "硬件数码",
//                time: "1 小时前",
//                replyCount: 33,
//                lastReplyUser: "harvies"
//            ))
//        }
//    }
//}
