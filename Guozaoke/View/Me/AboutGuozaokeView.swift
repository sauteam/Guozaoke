//
//  AboutGuozaokeView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/8.
//

import SwiftUI

struct AboutGuozaokeView: View {
    let info = """
                   过早客「guozaoke.com」武汉互联网精神家园
               
                   所有数据均来自过早客「guozaoke.com」
               
                   感谢其提供数据，才可能有过早客App
               
                   enjoy，欢迎反馈 ━(*｀∀´*)ノ亻!~
               """
    var body: some View {
        VStack {
            Image("zaoIcon")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 80, maxHeight: 80)
                .padding()

            Text("\(GuozaokeAppInfo.appName) V \(GuozaokeAppInfo.appVersion) Build \(GuozaokeAppInfo.buildNumber)")
                .font(.body)
                .fontWeight(.thin)
                .padding()
                .foregroundColor(Color.primary)
                .onTapGesture {
                    GuozaokeAppInfo.toAppStore()
                }

            Text(info)
                .font(.body)
                .fontWeight(.thin)
                .padding()
                .foregroundColor(Color.primary)
            
            Spacer()
        }
        .navigationTitle("关于过早客")
    }
}

#Preview {
    AboutGuozaokeView()
}
