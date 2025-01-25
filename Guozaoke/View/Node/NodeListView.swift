//
//  NodeListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct NodeListView: View {
    @StateObject private var viewModel = PostListParser()

    var body: some View {
//        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
                
                List (viewModel.nodes) { category in
                    Section(header: Text(category.category).font(.headline)) {
                        ForEach(category.nodes, id: \.self) { node in
                            NavigationLink(destination: NodeInfoView(node: node.title, nodeUrl: node.link)) {
                                Text(node.title)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("节点导航")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: {
//                        LoginStateChecker.clearUserInfo()
//                    }) {
//                        SFSymbol.search
//                    }
//                    
//                }
//            }
//        }
        .onAppear {
            if !viewModel.hadNodeItemData   {
                viewModel.refresh(type: .hot)
            }
        }
    }
}



//#Preview {
//    NodeListView()
//}
