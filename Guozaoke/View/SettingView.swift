//
//  SettingView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI

struct SettingView: View {
    let items: [String] = ["用户协议", "帮助反馈", "关于", "退出登录"]
    var body: some View {
        VStack {
            List {
                ForEach(items, id: \.self) { text in
                    Text(text)
                        .onTapGesture {
                            tapTextEvent(text)
                        }
                }
                .padding(.vertical, 10) // 设置行高
            }
            .padding(.vertical, 5)
            .buttonStyle(.plain)
            .listStyle(.plain)
            .listStyle(PlainListStyle())
        }
        .navigationTitle("设置")
    }
    
    private func tapTextEvent(_ urlString: String) {
         if urlString == "logout" {
             print("退出登录")
         } else if let url = URL(string: APIService.baseUrlString) {
             UIApplication.shared.open(url)
         }
     }
}

//#Preview {
//    SettingView()
//}
