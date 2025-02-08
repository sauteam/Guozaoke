//
//  NodeInfoView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/15.
//

import SwiftUI

struct NodeInfoView: View {
    let node: String
    let nodeUrl: String
    @StateObject private var viewModel = PostListParser()
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
            
            if viewModel.posts.isEmpty, !viewModel.isLoading {
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
                ForEach(viewModel.posts) { post in
                    NavigationLink {
                        PostDetailView(postId: post.link)
                    } label: {
                        PostRowView(post: post)
                        .onAppear {
                            if post == viewModel.posts.last {
                                viewModel.loadNodeInfo(nodeUrl)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .listStyle(.plain)
            .refreshable {
                viewModel.loadNodeInfoLastst(nodeUrl)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(node)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                }) {
//                    Menu {
//                        Button {
//                            
//                        } label: {
//                            
//                            Label("关注", systemImage: .collection)
//                        }
//                        
//                        Button {
//                            
//                        } label: {
//                            
//                            Label("创建新主题", systemImage: .add)
//                        }
//
//                    } label: {
//                        SFSymbol.more
//                    }
//                }
//            }
//        }
        .onAppear {
            if viewModel.posts.isEmpty {
                viewModel.loadNodeInfoLastst(nodeUrl)
            }
            NotificationCenter.default.addObserver(forName: .loginSuccessNoti, object: nil, queue: .main) { _
                in
                viewModel.loadNodeInfoLastst(nodeUrl)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { _ in
            viewModel.loadNodeInfoLastst(nodeUrl)
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
        }

        
    }
}

//#Preview {
//    NodeInfoView(node: "IT", nodeUrl: "/node/IT")
//}
