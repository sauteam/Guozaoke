//
//  SearchListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI

enum SearchEnum: String, CaseIterable {
    case user = "用户"
    case topicList = "主题列表"
    case topicInfo = "主题详情"
    
    var text: String {
        return self.rawValue
    }
}

struct SearchListView: View {
    @StateObject private var viewModel = SearchListParser()
    @State private var searchQuery: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    @State private var selectedTab: SearchEnum = .topicList
    @State private var showUserInfo: Bool = false
    @State private var showDetailInfo: Bool = false
    @State private var targetUserId: String = ""
    @State private var targetPostId: String = ""

    init(searchQuery: String = "", selectedTab: SearchEnum = .topicList) {
        _searchQuery = State(initialValue: searchQuery)
        _selectedTab = State(initialValue: selectedTab)
    }
    
    private var placeholderText: String {
        switch selectedTab {
        case .user:
            return "输入用户名或成员数字号（如：1）"
        case .topicList:
            return "搜索主题正文或回复"
        case .topicInfo:
            return "输入帖子ID（如：134525）"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchTextField
                    .padding(.vertical, 8)
                
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitleStyle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .tabbarToolBar()
            .refreshable {
                if selectedTab == .topicList && !searchQuery.isEmpty {
                    viewModel.searchText(searchQuery)
                }
            }
            .onAppear {
                isFocused = true
                if selectedTab == .topicList && !searchQuery.isEmpty && viewModel.searchList.isEmpty {
                    viewModel.searchText(searchQuery)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    Picker("选择列表", selection: $selectedTab) {
                        ForEach(SearchEnum.allCases, id: \.text) { type in
                            Text(type.text)
                                .tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .onChange(of: selectedTab) { _ in
                        isFocused = true
                    }
                }
            }
            .navigationDestination(isPresented: $showUserInfo) {
                if !targetUserId.isEmpty {
                    UserInfoView(userId: targetUserId)
                }
            }
            .navigationDestination(isPresented: $showDetailInfo) {
                if !targetPostId.isEmpty {
                    PostDetailView(postId: targetPostId)
                }
            }
        }
    }
    
    private var searchTextField: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField(placeholderText, text: $searchQuery)
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            
            Button("搜索") {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: GKDisplayMetrics.comfortReadableWidth)
        .padding(.horizontal, 16)
    }
        
    private var contentView: some View {
        Group {
            switch selectedTab {
            case .user:
                userSearchPromptView
            case .topicList:
                topicListView
            case .topicInfo:
                topicInfoPromptView
            }
        }
    }
    
    private var userSearchPromptView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("输入用户名或社区号搜索用户主页")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("例如：1（站长）或具体用户名")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .padding()
    }
    
    private var topicInfoPromptView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("输入帖子ID直接进入主题详情")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("例如：119731")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .padding()
    }
    
    private var topicListView: some View {
        Group {
            if viewModel.isLoading && viewModel.searchList.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("正在进行站内搜索...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if !viewModel.searchList.isEmpty {
                List {
                    if let status = viewModel.statusText, !status.isEmpty {
                        Section {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ForEach(viewModel.searchList) { post in
                        NavigationLink(destination: PostDetailView(postId: post.url)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(post.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                if !post.description.isEmpty {
                                    Text(post.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                                
                                if !post.meta.isEmpty {
                                    Text(post.meta)
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
                            }
                            .padding(.vertical, 4)
                            .onAppear {
                                if post.id == viewModel.searchList.last?.id {
                                    viewModel.loadMore()
                                }
                            }
                        }
                    }
                    
                    if viewModel.hasMoreData {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("正在加载更多...")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                        .onAppear {
                            viewModel.loadMore()
                        }
                    } else if viewModel.searchList.count >= 10 {
                        HStack {
                            Spacer()
                            Text("已经到底了")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            } else if !searchQuery.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("未找到相关帖子")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("尝试使用更简短的关键词或换个词搜索")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("输入关键词开始站内搜索")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isFocused = false
        switch selectedTab {
        case .user:
            targetUserId = query
            showUserInfo = true
        case .topicList:
            viewModel.searchText(query)
        case .topicInfo:
            targetPostId = query
            showDetailInfo = true
        }
    }
}
