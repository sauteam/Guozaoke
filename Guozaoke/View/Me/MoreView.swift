//
//  MoreView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/9.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        VStack {
            List {
                NavigationLink(destination: UserInfoView(userId: "isau")) {
                    Text("过早客iOS开发者：isau")
                        .font(.callout)
                        .fontWeight(.thin)
                        .padding()
                        .foregroundColor(Color.primary)
                }
                
                NavigationLink(destination: UserInfoView(userId: "Mario")) {
                    Text("网站管理大大：Mario")
                        .font(.callout)
                        .fontWeight(.thin)
                        .padding()
                        .foregroundColor(Color.primary)
                }

                NavigationLink(destination: PostDetailView(postId: APIService.androidUpdateTopicInfo)) {
                    Text("Android更新说明")
                        .font(.callout)
                        .fontWeight(.thin)
                        .padding()
                        .foregroundColor(Color.primary)
                }
                
                NavigationLink(destination: PostDetailView(postId: APIService.iosUpdateTopicInfo)) {
                    Text("iOS更新说明")
                        .font(.callout)
                        .fontWeight(.thin)
                        .padding()
                        .foregroundColor(Color.primary)
                }
            }
        }
        .navigationTitle("期待更多")
    }
}



#Preview {
    MoreView()
}
