import SwiftUI

struct SearchListView: View {
    @StateObject private var viewModel = SearchListParser()
    @State private var searchQuery: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    private let inputText = "🔍 输入关键字搜索"
    private let changeKeyText = "🔍 换个关键字试试"
    var body: some View {
        NavigationStack {
            VStack {
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
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .onAppear {
                                viewModel.loadMore()
                            }
                        } else {
                            if viewModel.searchList.count > 10 {
                                HStack {
                                    Spacer()
                                    Text("已经到底了")
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    let tips = viewModel.errorMessage ?? (searchQuery.count > 0 ? (viewModel.searchList.count == 0 ? changeKeyText: inputText): inputText)
                    Text(tips)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitleStyle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .refreshable {
                viewModel.loadNews()
            }
            .onAppear {
                isFocused = true
            }
            .onDisappear {
                isFocused = false
            }
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    HStack {
                        TextField(inputText, text: $searchQuery, onCommit: {
                            viewModel.searchText(searchQuery)
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.search)
                        .focused($isFocused)
                    }
                    .frame(width: screenWidth-80, height: 50, alignment: .center)
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
