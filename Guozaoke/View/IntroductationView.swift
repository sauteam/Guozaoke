//
//  IntroductationView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/24.
//

import SwiftUI

private let guozaokeText = "「过早客」guozaoke.com"
private let webManagerId = "Mario"
private let productInfo  = "t/117830"
private let deleteAccountTopic = "/t/116623"

struct IntroductationView: View {
    var body: some View {
        VStack {
            Form {
                Section {
                    Text("有时候发表评论或创建主题不成功，这里有可能受到\(guozaokeText)的相关限制，如果多次不成功你也可尝试退出后再评论或创建主题。")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                } header: {
                    Text("评论发帖说明")
                        .font(.subheadline)
                }
                
                Section {
                    Text("\(guozaokeText)修改或删除主题，可以自行到官网修改主题或联系管理员@Mario，后续也会考虑修改主题。")
                        .font(.body)

                        .onTapGesture {
                            webManagerId.userProfileUrl().openURL()
                        }
                } header: {
                    Text("删除主题")
                        .font(.subheadline)
                }
                
                Section {
                    Text("\(guozaokeText)删除账户可以自行到官网删除账户操作，删除账号后不能恢复，请确认后进行删除操作")
                        .font(.body)
                        .onTapGesture {
                            let url = APIService.baseUrlString + deleteAccountTopic
                            url.openURL()
                        }
                } header: {
                    Text("删除账号")
                        .font(.subheadline)
                }
                
                Section {
                    Text("后续会考虑支持图片上传以及创建主题预览等功能，希望大家多多使用，多多反馈。")
                        .font(.body)
                        .onTapGesture {
                            productInfo.postDetailUrl().openURL()
                        }
                        
                } header: {
                    Text("功能支持")
                        .font(.subheadline)
                }
                
                Section {
                    Text("感谢站长的支持与帮助，感谢马哥@mzlogin提供接口教程，感谢小伙伴的支持与关注。")
                        .font(.body)
                } header: {
                    Text("致谢")
                        .font(.subheadline)
                }
            }
            .navigationTitle("使用说明")
        }
    }
}

#Preview {
    IntroductationView()
}
