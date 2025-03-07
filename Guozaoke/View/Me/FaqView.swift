//
//  FaqView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/12.
//

import SwiftUI

struct FaqView: View {
    @StateObject private var viewModel = UserInfoParser()

    var body: some View {
        VStack {
            List {
                Text(faqText)
                    .subTitleFontStyle(weight: .thin)
            }
            .listStyle(.plain)
            .listRowSeparator(.hidden)
        }
        .contextMenu {
            Button {
                faqText.copyToClipboard()
            } label: {
                Label("拷贝", systemImage: .copy)
            }
        }
//        VStack {
//            RichTextView(content: viewModel.faqContent)
//                .padding(.horizontal)
//        }
//        .onAppear() {
//            if viewModel.faqContentValid() == false {
//                Task { await viewModel.faqInfo() }
//            }
//        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitleStyle("Faq")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//#Preview {
//    FaqView()
//}
