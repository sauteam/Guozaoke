//
//  MyReplyListView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/10.
//

import SwiftUI

struct MyReplyListView: View {
    @StateObject private var viewModel = UserInfoParser()
    let linkUrl : String
    let linkText : String

    var body: some View {
        VStack {
//            if viewModel.replies.isEmpty, !viewModel.isLoading {
//                HStack {
//                    Spacer()
//                    Text(NoMoreDataTitle.nodata)
//                        .font(.callout)
//                        .foregroundColor(.secondary)
//                    Spacer()
//                }
//                .listRowSeparator(.hidden)
//                .padding(.vertical, 12)
//            }
            
            List {
                ForEach(viewModel.replies) { post in
                    NavigationLink {
                        PostDetailView(postId: post.titleLink)
                    } label: {
                        MyReplyRowView(myReply: post, userId: linkUrl)
                            .onAppear {
                                if post == viewModel.replies.last {
                                    Task { await viewModel.loadMyTopic(linkUrl: linkUrl, reset: false) }
                                }
                            }
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if !viewModel.hasMoreData, !viewModel.replies.isEmpty {
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
            .navigationTitle(linkText)
            .toolbar(.hidden, for: .tabBar)
            .refreshable {
                Task { await viewModel.loadMyTopic(linkUrl: linkUrl, reset: true) }
            }
            .onAppear() {
                if !AccountState.isLogin() {
                    return
                }
                if viewModel.replies.isEmpty {
                    Task { await viewModel.loadMyTopic(linkUrl: linkUrl, reset: true) }
                }
            }
        }
    }
}

//#Preview {
//    MyReplyListView()
//}
