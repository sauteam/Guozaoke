//
//  IntroductationView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/24.
//

import SwiftUI

private let guozaokeText = "「过早客」guozaoke.com"
private let webManagerId = "Mario"

struct IntroductationView: View {
    var body: some View {
        VStack {
            Form {
                Section {
                    Text("有时候发表评论或创建主题不成功，可能返回403，有可能我们在网页或App都登录了\(guozaokeText)，导致校验问题，如果多次不成功你也可尝试退出后再评论或创建主题。")
                        .frame(maxWidth: .infinity)
                        .subTitleFontStyle()
                } header: {
                    Text("评论发帖说明")
                        .subTitleFontStyle()
                }
                
                Section {
                    NavigationLink(destination: PostDetailView(postId: APIService.deleteTopicUrl)) {
                        Text("\(guozaokeText)修改或删除主题，可以自行到官网修改主题或联系管理员@Mario，后续也会考虑修改主题。")
                            .subTitleFontStyle()
                    }

                } header: {
                    Text("删除主题")
                        .subTitleFontStyle()
                }
                
                Section {
                    NavigationLink(destination: PostDetailView(postId: APIService.deleteAccountUrl)) {
                        Text("\(guozaokeText)删除账户可以自行到官网删除账户操作，删除账号后不能恢复，请确认后进行删除操作")
                            .subTitleFontStyle()
                    }

                } header: {
                    Text("删除账号")
                        .subTitleFontStyle()
                }
                
                Section {
                    NavigationLink(destination: PostDetailView(postId: APIService.iosUpdateTopicInfo)) {
                        Text("后续会考虑支持图片上传以及创建主题预览等功能，希望大家多多使用，多多反馈。")
                            .subTitleFontStyle()
                    }
                        
                } header: {
                    Text("功能支持")
                        .subTitleFontStyle()
                }
                
                Section {
                    NavigationLink(destination: UserInfoView(userId: "mzlogin")) {
                        Text("感谢站长的支持与帮助，感谢马哥@mzlogin提供接口教程，感谢@caipod设计过早客logo，感谢小伙伴的支持与关注。")
                            .subTitleFontStyle()
                    }
                } header: {
                    Text("致谢")
                        .subTitleFontStyle()
                }
            }
            .navigationTitleStyle("评论发帖")
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

//#Preview {
//    IntroductationView()
//}
