//
//  NodeListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct NodeListView: View {
    @StateObject private var viewModel  = PostListParser()

    var body: some View {
//        let hotTodayTopic =
//        VStack(alignment: .leading, spacing: 0) {
//            SectionTitleView("今日热议")
//                .padding(.horizontal, 10)
//            ForEach(viewModel.hotTodayTopic) { item in
//                HStack(spacing: 12) {
//                    KFImageView(item.avatar)
//                        .avatar()
//                    
//                    Text(item.title)
//                        .foregroundColor(.bodyText)
//                        .lineLimit(2)
//                        .greedyWidth(.leading)
//                }
//                .padding(.vertical, 12)
//                .padding(.horizontal, 10)
//                .background(Color.itemBg)
//                .divider()
//                .to { PostDetailView(postId: item.link) }
//            }
//        }
//        
//        let navNodesItem =
//        VStack(spacing: 0) {
//            SectionTitleView("节点导航")
//            ForEach(viewModel.nodes) {
//                NodeNavItemView(data: $0)
//            }
//        }
        
        VStack(alignment: .leading, spacing: 0) {
            List {
//                SectionTitleView("今日热议")
//                    .padding(.horizontal, 10)
//                ForEach(viewModel.hotTodayTopic) { item in
//                    HStack(spacing: 12) {
//                        KFImageView(item.avatar)
//                            .avatar()
//                        
//                        Text(item.title)
//                            .lineLimit(2)
//                            .greedyWidth(.leading)
//                    }
//                    .to { PostDetailView(postId: item.link) }
//                }
                
                SectionTitleView("节点导航")
                ForEach(viewModel.hotNodes) {
                    NodeNavItemView(data: $0)
                }

                ForEach(viewModel.nodes) {
                    NodeNavItemView(data: $0)
                }
                
                SectionTitleView("运行状态")
                ForEach(viewModel.communityStatusList) { status in
                    Text("\(status.title)  \(status.value)")
                }
            }
        }
        .buttonStyle(.plain)
        .listStyle(.plain)
        .navigationTitle("节点")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if !viewModel.hadNodeItemData  {
                log("节点请求")
                viewModel.refreshPostList(type: .hot)
            }
        }
    }
}

struct NodeNavItemView: View {
    let data: NodeItem
    @State private var showNodeInfoView = false
    @State private var selectedNode: Node? = nil

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitleView(data.category, style: .small)
                FlowStack(data: data.nodes) { node in
                    Text(node.title)
                        .font(.footnote)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Color.gray.opacity(0.2)
                                .cornerRadius(4)
                        )
                        .onTapGesture {
                            showNodeInfoView = true
                            selectedNode = node
                        }
                        
                }
            }
            .navigationDestination(isPresented: $showNodeInfoView) {
                if let node = selectedNode {
                    NodeInfoView(node: node.title, nodeUrl: node.link)
                }
            }
        }
    }
}



//    var body: some View {
//        VStack {
//            if viewModel.isLoading {
//                ProgressView()
//                    .frame(maxWidth: .infinity)
//                    .listRowSeparator(.hidden)
//            }
//
//            List (viewModel.nodes) { category in
//                Section(header: Text(category.category).font(.headline)) {
//                    ForEach(category.nodes, id: \.self) { node in
//                        NavigationLink(destination: NodeInfoView(node: node.title, nodeUrl: node.link)) {
//                            Text(node.title)
//                                .padding(.vertical, 4)
//                        }
//                    }
//                }
//            }
//        }
//        .navigationTitle("节点导航")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .onAppear {
//            if !viewModel.hadNodeItemData   {
//                viewModel.refreshPostList(type: .hot)
//            }
//        }
//    }


