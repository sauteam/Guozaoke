//
//  NodeListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct NodeListView: View {
    @StateObject private var viewModel  = PostListParser()
    @State private var showMembersView = false
    @State private var showSearchView  = false

    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            List {
                SectionTitleView("今日热议")
                    .padding(.horizontal, 10)
                ForEach(viewModel.hotTodayTopic) { item in
                    HStack(spacing: 12) {
                        KFImageView(item.avatar)
                            .avatar()
                        
                        Text(item.title)
                            .greedyWidth(.leading)
                            .titleFontStyle()

                    }
                    .to { PostDetailView(postId: item.link) }
                }
                
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
                        .subTitleFontStyle()

                }
            }
        }
        .buttonStyle(.plain)
        .listStyle(.plain)
        .navigationTitleStyle("节点")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    hapticFeedback()
                    showSearchView.toggle()
                }) {
                    SFSymbol.search
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button(action: {
                    hapticFeedback()
                    showMembersView.toggle()
                }) {
                    SFSymbol.person3
                }
            }
        }
        .navigationDestination(isPresented: $showSearchView, destination: {
            SearchListView()
        })
        .navigationDestination(isPresented: $showMembersView, destination: {
            MembersGridView()
        })
        .onAppear {
            if !viewModel.hadNodeItemData  {
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
                        .subTitleFontStyle()
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


