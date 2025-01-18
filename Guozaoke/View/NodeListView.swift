//
//  NodeListView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct NodeListView: View {
    @Environment(\.themeColor) private var themeColor: Color

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("节点详情")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        
                    }) {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(themeColor)
                }
            }
    }
}

#Preview {
    NodeListView()
}
