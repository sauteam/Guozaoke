//
//  PostListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI

// MARK: - 帖子列表视图
struct PostListView: View {
    @State private var selectedTab: PostListType
    @State private var posts: [PostItem] = []
    @State private var isLoading = false
    @State private var showMembersView = false
    @State private var showAddPostView = false
    @State private var showSearchView  = false
    @State private var selectedTopic: Node? = nil
    @State private var selectedPostId: String? = nil
    @ObservedObject var viewModel: PostListViewModel

    init(viewModel: PostListViewModel) {
        self.viewModel = viewModel
        if let lastSelectedType = UserDefaults.standard.string(forKey: PostListViewModel.lastSelectedTypeKey),
           let type = PostListType(rawValue: lastSelectedType), viewModel.postListItems.contains(where: { $0.type == type && $0.isVisible }) {
          _selectedTab = State(initialValue: type)
      } else {
          _selectedTab = State(initialValue: .latest)
      }
    }

    var body: some View {
        GeometryReader { proxy in
            let isDual = GKDisplayMetrics.isDualColumnDisplay(size: proxy.size)
            
            if isDual {
                // 折叠屏展开横屏：Master-Detail 双窗格模式 (List-Detail Pattern)
                HStack(spacing: 0) {
                    // 左窗格：分类标签与帖子列表 (避让铰链左侧)
                    VStack(spacing: 0) {
                        categoryScrollView
                        Divider()
                        postTabsView(isDual: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 物理铰链避让区 (32pt 避让带)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: GKDisplayMetrics.hingeExclusionRadius * 2)
                        .allowsHitTesting(false)
                    
                    // 右窗格：选中主题详情与交互 (右边距TabBar仅保留10pt，充盈饱满不空旷)
                    ZStack {
                        if let postId = selectedPostId, !postId.isEmpty {
                            PostDetailView(postId: postId)
                                .id(postId)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "newspaper.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.blue.opacity(0.6))
                                Text("选择左侧主题查看详情")
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("在折叠屏展开态下边浏览边阅读")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, 10)
                }
                .environment(\.isGKDualColumn, true)
            } else {
                // 竖屏单列常规导航流
                VStack(spacing: 0) {
                    categoryScrollView
                    Divider()
                    postTabsView(isDual: false)
                }
                .environment(\.isGKDualColumn, false)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button(action: {
                    hapticFeedback()
                    if LoginStateChecker.isLogin {
                        showAddPostView.toggle()
                    } else {
                        LoginStateChecker.LoginStateHandle()
                    }
                }) {
                    SFSymbol.add
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    hapticFeedback()
                    showSearchView.toggle()
                }) {
                    SFSymbol.search
                }
            }
        }
        .navigationTitleStyle("过早客")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showSearchView, destination: {
            SearchListView()
        })
        .sheet(isPresented: $showAddPostView) {
            SendPostView(isPresented: $showAddPostView, selectedTopic: $selectedTopic, postDetail:nil) {
            }
            .presentationDetents([.height(isPadOrWideScreen ? screenHeight : screenHeight/2), .medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 10) {
                    ForEach(viewModel.visibleItems, id: \.type) { item in
                        Button(action: {
                            withAnimation {
                                selectedTab = item.type
                                viewModel.saveLastSelectedType(item.type)
                            }
                            proxy.scrollTo(item.type, anchor: .center)
                        }) {
                            VStack(spacing: 5) {
                                Text(item.type.rawValue)
                                    .foregroundColor(selectedTab == item.type ? .blue : .gray)
                                    .subTitleFontStyle()                                    
                                Rectangle()
                                    .fill(selectedTab == item.type ? Color.blue : Color.clear)
                                    .frame(height: 1.5)
                            }
                        }
                        .id(item.type)
                    }
                }
                .padding(.horizontal)
                .onChange(of: selectedTab) { newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                        viewModel.saveLastSelectedType(newValue)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func postTabsView(isDual: Bool) -> some View {
        TabView(selection: $selectedTab) {
            ForEach(viewModel.visibleItems, id: \.type) { item in
                PostListContentView(
                    type: item.type,
                    selectedPostId: $selectedPostId,
                    isDual: isDual
                )
                .tag(item.type)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .animation(.easeInOut, value: selectedTab)
    }
}
//

// MARK: - 帖子列表内容视图
struct PostListContentView: View {
    let type: PostListType
    @Binding var selectedPostId: String?
    var isDual: Bool = false
    
    @StateObject private var viewModel = PostListParser()
    @State private var showDetailView  = false
    @State private var showUserInfoView  = false
    @State private var selectedHotTodayTopic: HotTodayTopic? = nil

    var body: some View {
        ZStack {
            if viewModel.posts.isEmpty, !viewModel.isLoading {
                HStack {
                    Spacer()
                    Text(NoMoreDataTitle.nodata)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            if !LoginStateChecker.isLogin {
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
                    if isDual {
                        Button {
                            selectedPostId = post.link
                        } label: {
                            PostRowView(post: post)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedPostId == post.link ? Color.blue.opacity(0.12) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if post == viewModel.posts.last {
                                viewModel.loadMorePosts(type: type)
                                logger("2 type \(type)")
                            }
                        }
                    } else {
                        NavigationLink {
                            PostDetailView(postId: post.link)
                        } label: {
                            PostRowView(post: post)
                                .onAppear {
                                    if post == viewModel.posts.last {
                                        viewModel.loadMorePosts(type: type)
                                        logger("2 type \(type)")
                                    }
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
            .id(type)
            .refreshable {
                viewModel.refreshPostList(type: type)
            }
            .onChange(of: viewModel.posts) { newPosts in
                if isDual && (selectedPostId == nil || selectedPostId?.isEmpty == true) {
                    if let first = newPosts.first {
                        selectedPostId = first.link
                    }
                }
            }
            .navigationDestination(isPresented: $showUserInfoView, destination: {
                if let item = self.selectedHotTodayTopic {
                    UserInfoView(userId: item.user)
                }
            })
            .onAppear() {
                if viewModel.posts.isEmpty {
                    viewModel.refreshPostList(type: type)
                } else if isDual && (selectedPostId == nil || selectedPostId?.isEmpty == true) {
                    selectedPostId = viewModel.posts.first?.link
                }
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
    
    func loadNewData() {
        if UserDefaultsKeys.homeListRefresh {
            viewModel.refreshPostList(type: type)
        }
    }
}
