//
//  AboutGuozaokeView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/8.
//

import SwiftUI
import MessageUI

struct AboutView: View {
    let info = """
                   过早客「guozaoke.com」武汉互联网精神家园
               
                   所有数据均来自过早客「guozaoke.com」
               
                   感谢其提供数据，才可能有过早客App
               
                   enjoy，欢迎反馈 ━(*｀∀´*)ノ亻!~
               
                   在社区发帖或是邮件反馈
               """
    
    @State private var showMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil
    
    @EnvironmentObject var purchaseAppState: PurchaseAppState
    @State private var showSafari = false
    @State private var showSystemCopy = false

    var body: some View {
        VStack {
            Image("zaoIcon")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 80, maxHeight: 80)
                .padding()
                .contextMenu {
                    if AccountState.isSelf(userName: DeveloperInfo.username) {
                        Button {
                            purchaseAppState.clear()
                        } label: {
                            Text("清除内购")
                        }
                    
                        Button {
                            purchaseAppState.savePurchaseStatus(isPurchased: true)
                        } label: {
                            Text("保存状态")
                        }
                    }
                }

            Text("\(AppInfo.appName) V\(AppInfo.appVersion) Build \(AppInfo.buildNumber)")
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
                .contextMenu {
                    Button(action: {
                        DeveloperInfo.email.copyToClipboard()
                    }) {
                        Text("拷贝邮箱")
                        SFSymbol.copy
                    }
                    Button(action: {
                        if MFMailComposeViewController.canSendMail() {
                            showMailView.toggle()
                        } else {
                            DeveloperInfo.email.copyToClipboard()
                            ToastView.toastText("邮箱地址已拷贝")
                        }
                    }) {
                        Text("发送邮件")
                        SFSymbol.envelope
                    }
                }
                .sheet(isPresented: $showMailView) {
                    MailView(result: self.$mailResult, recipients: [DeveloperInfo.email])
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
        .tabbarToolBar()
        .navigationTitleStyle("关于过早客")
    }
}

#Preview {
    AboutView()
}
