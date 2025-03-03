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
            RichTextView(content: viewModel.faqContent)
                .padding(.horizontal)
        }
        .onAppear() {
            if viewModel.faqContentValid() == false {
                Task { await viewModel.faqInfo() }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("faq")
    }
}

#Preview {
    FaqView()
}
