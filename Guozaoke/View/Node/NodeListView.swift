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
    @State private var showUserInfo   = false
    @State private var username: String = ""
    @State private var selectedTopicLink: String? = nil
    @State private var selectedNode: Node? = nil

    var body: some View {
        GeometryReader { proxy in
            let isDual = GKDisplayMetrics.isDualColumnDisplay(size: proxy.size)
            
            if isDual {
                // 折叠屏展开横屏：Master-Detail 双窗格
                HStack(spacing: 0) {
                    // 左窗格：热议与节点列表
                    nodeContentList(isDual: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 中缝避让隔离 (32pt)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: GKDisplayMetrics.hingeExclusionRadius * 2)
                        .allowsHitTesting(false)
                    
                    // 右窗格：选中主题或节点详情 (右边距TabBar仅保留10pt，充盈饱满不空旷)
                    ZStack {
                        if let topicLink = selectedTopicLink, !topicLink.isEmpty {
                            PostDetailView(postId: topicLink)
                                .id(topicLink)
                        } else if let node = selectedNode {
                            NodeInfoView(node: node.title, nodeUrl: node.link)
                                .id(node.link)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.blue.opacity(0.6))
                                Text("选择热议主题或节点")
                                    .font(.title3.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("在展开屏幕上直接浏览节点详情")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, 10)
                }
                .environment(\.isGKDualColumn, true)
            } else {
                nodeContentList(isDual: false)
                    .environment(\.isGKDualColumn, false)
            }
        }
        .refreshable {
            viewModel.refreshPostList(type: .hot)
        }
        .navigationDestination(isPresented: $showUserInfo, destination: {
            if username.count > 0 {
                UserInfoView(userId: username)
            }
        })
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
    
    @ViewBuilder
    private func nodeContentList(isDual: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                SectionTitleView("今日热议")
                    .padding(.horizontal, 10)
                ForEach(viewModel.hotTodayTopic) { item in
                    if isDual {
                        HStack(spacing: 12) {
                            Button {
                                username = item.user
                                showUserInfo = true
                            } label: {
                                KFImageView(item.avatar)
                                    .avatar()
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                selectedTopicLink = item.link
                                selectedNode = nil
                            } label: {
                                Text(item.title)
                                    .greedyWidth(.leading)
                                    .titleFontStyle()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTopicLink == item.link ? Color.blue.opacity(0.12) : Color.clear)
                        )
                    } else {
                        HStack(spacing: 12) {
                            Button {
                                username = item.user
                                showUserInfo = true
                            } label: {
                                KFImageView(item.avatar)
                                    .avatar()
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink {
                                PostDetailView(postId: item.link)
                            } label: {
                                Text(item.title)
                                    .greedyWidth(.leading)
                                    .titleFontStyle()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                SectionTitleView("节点导航")
                ForEach(viewModel.hotNodes) {
                    NodeNavItemView(data: $0, isDual: isDual, selectedNode: $selectedNode, onSelectNode: { node in
                        selectedNode = node
                        selectedTopicLink = nil
                    })
                }

                ForEach(viewModel.nodes) {
                    NodeNavItemView(data: $0, isDual: isDual, selectedNode: $selectedNode, onSelectNode: { node in
                        selectedNode = node
                        selectedTopicLink = nil
                    })
                }
                
                SectionTitleView("运行状态")
                ForEach(viewModel.communityStatusList) { status in
                    Text("\(status.title)  \(status.value)")
                        .subTitleFontStyle()
                }
            }
            .buttonStyle(.plain)
            .listStyle(.plain)
        }
    }
}

struct NodeNavItemView: View {
    let data: NodeItem
    var isDual: Bool = false
    @Binding var selectedNode: Node?
    var onSelectNode: ((Node) -> Void)? = nil
    
    @State private var showNodeInfoView = false
    @State private var localSelectedNode: Node? = nil

    var body: some View {
        Group {
            if isDual {
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
                                (selectedNode?.link == node.link ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            )
                            .onTapGesture {
                                onSelectNode?(node)
                            }
                    }
                }
            } else {
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
                                    localSelectedNode = node
                                }
                        }
                    }
                    .navigationDestination(isPresented: $showNodeInfoView) {
                        if let node = localSelectedNode {
                            NodeInfoView(node: node.title, nodeUrl: node.link)
                        }
                    }
                }
            }
        }
    }
}


