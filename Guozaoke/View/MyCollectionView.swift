//
//  MyCollectionView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import SwiftUI

struct MyCollectionView: View {
    @StateObject private var viewModel = UserInfoParser()
    let topicType : MyTopicEnum
    
    var body: some View {
        ZStack {
            if viewModel.topics.isEmpty, !viewModel.isLoading {
                HStack {
                    Spacer()
                    Text(NoMoreDataTitle.nodata)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 12)
            }
            
            List {
                ForEach(viewModel.topics) { post in
                    NavigationLink {
                        PostDetailView(postId: post.link)
                    } label: {
                        PostRowView(post: post)
                            .onAppear {
                                if post == viewModel.topics.last {
                                    Task { await viewModel.loadMyTopic(type: topicType, reset: false) }
                                }
                            }
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if !viewModel.hasMoreData, !viewModel.topics.isEmpty {
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
            .navigationTitle(topicType.title)
//            .refreshable {
//                viewModel.loadMyTopicRefresh(type: topicType)
//            }
            .onAppear() {
                if !AccountState.isLogin() {
                    return
                }
                if viewModel.topics.isEmpty {
                    Task { await viewModel.loadMyTopic(type: topicType, reset: true) }
                }
            }
        }
    }

}
