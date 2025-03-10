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

    var body: some View {
        NavigationStack {
            VStack {
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
                .frame(width: screenWidth-80, height: 40, alignment: .center)
                Spacer()

                
                if selectedTab == .user {
                    
                } else if selectedTab == .topicList {
                    if viewModel.isLoading && viewModel.searchList.isEmpty {
                        ProgressView("正在搜索中...")
                    } else if !viewModel.searchList.isEmpty {
                        List {
                            ForEach(viewModel.searchList) { post in
                                NavigationLink(destination: PostDetailView(postId: post.link)) {
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
                            if viewModel.hasMorePages {
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
                        let tips = viewModel.errorMessage ?? (searchQuery.count > 0 ? (viewModel.searchList.count == 0 ? changeKeyText: inputText): inputText)
                        HStack {
                            Text(tips)
                                .foregroundColor(.gray)
                        }
                        .listRowSeparator(.hidden)
                    }
                } else if selectedTab == .topicInfo {
                    
                }
                Spacer()
            }
            .navigationTitleStyle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .refreshable {
                if selectedTab == .topicList {
                    viewModel.loadNews()
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
    
    private var keywordHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.savedSearchKeywords) { keyword in
                    Text(keyword.keyword)
                        .padding(5)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(5)
                        .onTapGesture {
                            searchQuery = keyword.keyword
                            viewModel.searchText(searchQuery)
                        }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
    }
}
