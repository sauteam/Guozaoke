//
//  Guozaoke
//
//  Created by scy on 2025/2/27.
//

import SwiftUI

struct RelatedTopicView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: PostDetailParser
    @Environment(\.dismiss) var dismiss
    @State private var showDetailView = false
    @State private var postId: String? = ""
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    SectionTitleView("相关主题")
                        .padding(.horizontal, 10)
                    ForEach(viewModel.relatedTopics) { item in
                        HStack(spacing: 12) {
                            
                            NavigationLink {
                                PostDetailView(postId: item.tid ?? "")
                            } label: {
                                KFImageView(item.avatar)
                                    .avatar()
                                Text(item.topicTitle)
                                    .lineLimit(2)
                                    .greedyWidth(.leading)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .listStyle(.plain)
                .onAppear() {
                    if viewModel.relatedTopics.count == 0 {
                        viewModel.loadMore()
                    }
                }
            }
        }
    }
    
    private func closeView() {
        isPresented = false
        dismiss()
    }
}
