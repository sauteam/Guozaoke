//
//  MyCollectionView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import SwiftUI

struct MyCollectionView: View {
    @StateObject private var viewModel = UserInfoParser()
    let linkUrl : String
    let linkText : String

    var body: some View {
        VStack {
            
            List {
                ForEach(viewModel.topics) { post in
                    NavigationLink {
                        PostDetailView(postId: post.link)
                    } label: {
                        PostRowView(post: post)
                            .onAppear {
                                if post == viewModel.topics.last {
                                    Task { await viewModel.loadMyTopic(linkUrl: linkUrl, reset: false) }
                                }
                            }
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if !viewModel.hasMoreData {
                    let noData = viewModel.topics.count == 0
                    HStack {
                        Spacer()
                        Text(noData ? NoMoreDataTitle.nodata : NoMoreDataTitle.homeList)
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
                if viewModel.topics.isEmpty {
                    Task { await viewModel.loadMyTopic(linkUrl: linkUrl, reset: true) }
                }
            }
        }
    }
}
