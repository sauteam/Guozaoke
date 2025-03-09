//
//  AboutGuozaokeView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/8.
//

import SwiftUI
import MessageUI

struct AboutView: View {
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

            Text("\(AppInfo.appName) V \(AppInfo.appVersion) Build \(AppInfo.buildNumber)")
                .titleFontStyle(weight: .thin)
                .padding()
                .foregroundColor(Color.primary)
                .onTapGesture {
                    AppInfo.toAppStore()
                }

            Text(info)
                .titleFontStyle(weight: .thin)
                .padding()
                .foregroundColor(Color.primary)
                .onLongPressGesture {
                    showMailView = true
                }
                .sheet(isPresented: $showMailView) {
                    if !isSimulator() {
                        MailView(subject: "过早客反馈", body: "", recipient: feedbackEmail) { result in
                            self.mailResult = result
                        }
                    }
                }
//            if let mailResult = mailResult {
//                switch mailResult {
//                case .success(let result):
//                    let isSend = result.rawValue == 2
//                case .failure(let error):
//                    log("发送失败: \(error.localizedDescription)")
//                }
//            }
            Spacer()
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitleStyle("关于过早客")
    }
}

#Preview {
    AboutView()
}
