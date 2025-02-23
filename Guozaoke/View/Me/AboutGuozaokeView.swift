//
//  AboutGuozaokeView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/8.
//

import SwiftUI
import MessageUI

struct AboutGuozaokeView: View {
    let feedbackEmail =  "isau@qq.com"
    let info = """
                   过早客「guozaoke.com」武汉互联网精神家园
               
                   所有数据均来自过早客「guozaoke.com」
               
                   感谢其提供数据，才可能有过早客App
               
                   enjoy，欢迎反馈 ━(*｀∀´*)ノ亻!~
               
                   在社区发帖或是邮件268144637@qq.com
               """
    
    @State private var showMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil

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
                .onTapGesture {
                    showMailView = true
                }
                .sheet(isPresented: $showMailView) {
                    MailView(subject: "过早客反馈", body: "写点什么...", recipient: feedbackEmail) { result in
                        self.mailResult = result
                    }
                }
            if let mailResult = mailResult {
                switch mailResult {
                case .success(let result):
                    let isSend = result.rawValue == 2
                    Text("邮件\(isSend ? "已发送": "去发送")")
                case .failure(let error):
                    Text("发送失败: \(error.localizedDescription)")
                }
            }
            Spacer()
        }
        .navigationTitle("关于过早客")
    }
}

#Preview {
    AboutGuozaokeView()
}
