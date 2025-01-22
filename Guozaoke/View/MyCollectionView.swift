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
//            .buttonStyle(.plain)
//            .listStyle(.plain)
//            .refreshable {
//                viewModel.loadMyTopicRefresh(type: topicType)
//            }
            .onAppear() {
                if viewModel.topics.isEmpty {
                    Task { await viewModel.loadMyTopic(type: topicType, reset: true) }
                }
            }
//            .onDisappear() {
//                NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
//            }
//            .alert("错误", isPresented: Binding(
//                get: { viewModel.error != nil },
//                set: { if !$0 { viewModel.error = nil } }
//            )) {
//                Button("确定", role: .cancel) {}
//            } message: {
//                Text(viewModel.error ?? "")
//            }
        }
    }

}
