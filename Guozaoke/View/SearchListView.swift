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
    private let inputText = "🔍 关键字/用户名或数字号/帖子ID"
    private let changeKeyText = "🔍 换个关键字试试"
    @State private var selectedTab: SearchEnum  = .topicList
    @State private var showUserInfo: Bool = false
    @State private var showDetailInfo: Bool = false

    init(searchQuery: String = "", selectedTab: SearchEnum = .topicList) {
         _searchQuery = State(initialValue: searchQuery)
         _selectedTab = State(initialValue: selectedTab)
     }
    
    var body: some View {
        NavigationStack {
            VStack {
                searchTextField
                Spacer()
                contentView
                Spacer()
            }
            .navigationTitleStyle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .tabbarToolBar()
            .refreshable {
                if selectedTab == .topicList {
                    viewModel.searchText(self.searchQuery)
                }
            }
            .onAppear {
                isFocused = true
            }
            .onDisappear {
                isFocused = false
            }
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    VStack {
                        Picker("选择列表", selection: $selectedTab) {
                            ForEach(SearchEnum.allCases, id: \.text) { type in
                                Text(type.text)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                    }
                }
            }
        }
    }
    
    private var searchTextField: some View {
        HStack {
            TextField(inputText, text: $searchQuery, onCommit: {
                if selectedTab == .user {
                    showUserInfo.toggle()
                } else if selectedTab == .topicList {
                    viewModel.searchText(searchQuery)
                } else if selectedTab == .topicInfo {
                    showDetailInfo.toggle()
                }
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .submitLabel(.search)
            .focused($isFocused)
            .navigationDestination(isPresented: $showDetailInfo, destination: {
                if !searchQuery.isEmpty {
                    PostDetailView(postId: searchQuery)
                 }
            })
            .navigationDestination(isPresented: $showUserInfo, destination: {
                if !searchQuery.isEmpty {
                     UserInfoView(userId: searchQuery)
                 }
            })
        }
        .frame(maxWidth: GKDisplayMetrics.comfortReadableWidth)
        .frame(height: 40)
        .padding(.horizontal, 20)
    }
        
    private var contentView: some View {
        Group {
            switch selectedTab {
            case .user:
                HStack {
                    Text("🔍用户名或「过早客多少号成员：1」")
                        .foregroundColor(.gray)
                }
            case .topicList:
                topicListView
            case .topicInfo:
                HStack {
                    Text("🔍输入帖子ID，如：119731")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var topicListView: some View {
        Group {
            if viewModel.isLoading && viewModel.searchList.isEmpty {
                ProgressView("正在搜索中...")
            } else if !viewModel.searchList.isEmpty {
                List {
                    ForEach(viewModel.searchList) { post in
                        NavigationLink(destination: PostDetailView(postId: post.url)) {
                            VStack(alignment: .leading) {
                                Text(post.title)
                                    .font(.headline)
                                Text(post.description)
                                    .font(.subheadline)
                                    .lineLimit(3)
                            }
                            .padding(.vertical)
                            .onAppear {
                                if post.id == viewModel.searchList.last?.id {
                                    viewModel.loadMore()
                                }
                            }
                        }
                    }
                    if viewModel.hasMoreData {
                        HStack {
                            ProgressView()
                            Spacer()
                        }
                        .onAppear {
                            viewModel.loadMore()
                        }
                    } else {
                        if viewModel.searchList.count > 10 {
                            HStack {
                                Text("已经到底了")
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
            } else {
//                let tips = viewModel.errorMessage ?? (searchQuery.isEmpty ? inputText : changeKeyText)
//                Text(tips)
//                    .foregroundColor(.gray)
//                    .padding()
            }
        }
    }
    
    private func performSearch() {
        switch selectedTab {
        case .user:
            showUserInfo.toggle()
        case .topicList:
            viewModel.searchText(searchQuery)
        case .topicInfo:
            showDetailInfo.toggle()
        }
    }
    
//    private var keywordHeader: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 10) {
//                ForEach(viewModel.savedSearchKeywords) { keyword in
//                    Text(keyword.keyword)
//                        .padding(5)
//                        .background(Color.gray.opacity(0.2))
//                        .cornerRadius(5)
//                        .onTapGesture {
//                            searchQuery = keyword.keyword
//                            viewModel.searchText(searchQuery)
//                        }
//                }
//            }
//            .padding(.horizontal)
//        }
//        .frame(height: 40)
//    }
}
