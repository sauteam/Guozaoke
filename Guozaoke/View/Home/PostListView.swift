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
    @State private var showAddPostView = false
    @State private var showSearchView  = false
    @State private var selectedTopic: Node? = nil
//    @Environment(\.themeColor) private var themeColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 10) {
                        ForEach(PostListType.allCases, id: \.self) { type in
                            Button(action: {
                                withAnimation {
                                    selectedTab = type
                                }
                                proxy.scrollTo(type, anchor: .center)
                            }) {
                                VStack(spacing: 5) {
                                    Text(type.rawValue)
                                        .foregroundColor(selectedTab == type ? .blue : .gray)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Rectangle()
                                        .fill(selectedTab == type ? Color.blue : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .id(type)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Divider()
            
            TabView(selection: $selectedTab) {
                ForEach(PostListType.allCases, id: \.self) { type in
                    PostListContentView(type: type)
                        .tag(type)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: selectedTab) { newValue in
                
            }
            .animation(.easeInOut, value: selectedTab)
            
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddPostView = true
                    }) {
                        SFSymbol.add
                    }
                }
            }
            .navigationTitle("过早客")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showAddPostView) {
                if LoginStateChecker.isLogin() {
                    SendPostView(isPresented: $showAddPostView, selectedTopic: $selectedTopic) {
                        
                    }
                } else {
                    LoginView(isPresented: $showAddPostView) {
                        
                    }
                }
            }
        }
    }
}

//

// MARK: - 帖子列表内容视图
struct PostListContentView: View {
    let type: PostListType
    @StateObject private var viewModel = PostListParser()
    @State private var showDetailView  = false

    var body: some View {
        ZStack {
            if viewModel.posts.isEmpty, !viewModel.isLoading {
                HStack {
                    Spacer()
                    Text(NoMoreDataTitle.nodata)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            if !LoginStateChecker.isLogin() {
                                LoginStateChecker.LoginStateHandle()
                            }
                        }
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 12)
            }
            List {
                ForEach(viewModel.posts) { post in                    
                    NavigationLink {
                        PostDetailView(postId: post.link)
                    } label: {
                        PostRowView(post: post)
                            .onAppear {
                                if post == viewModel.posts.last {
                                    viewModel.loadMorePosts(type: type)
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
                viewModel.refreshPostList(type: type)
            }
            .id(type)
            .onAppear() {

                if viewModel.posts.isEmpty {
                    viewModel.refreshPostList(type: type)
                }
                print("1 type \(type)")
            }
            .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { _ in
                viewModel.refreshPostList(type: type)
            }
            .onDisappear() {
                NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
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
}
