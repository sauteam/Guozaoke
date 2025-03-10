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
                Section {
                    NavigationLink(destination: UserInfoView(userId: "isau")) {
                        Text("过早客iOS开发者：isau")
                            .titleFontStyle(weight: .thin)
                            .padding()
                            .foregroundColor(Color.primary)
                    }
                    
                    NavigationLink(destination: UserInfoView(userId: "Mario")) {
                        Text("网站管理大大：Mario")
                            .titleFontStyle(weight: .thin)
                            .padding()
                            .foregroundColor(Color.primary)
                    }

                    NavigationLink(destination: PostDetailView(postId: APIService.androidUpdateTopicInfo)) {
                        Text("mzlogin大大：mzlogin")
                            .titleFontStyle(weight: .thin)
                            .padding()
                            .foregroundColor(Color.primary)
                    }
                    
                    NavigationLink(destination: PostDetailView(postId: APIService.iosUpdateTopicInfo)) {
                        Text("更新说明")
                            .titleFontStyle(weight: .thin)
                            .padding()
                            .foregroundColor(Color.primary)
                    }
                }
                
                Section {
                    NavigationLink(destination: Base64View()) {
                        Text("Base64加密解密")
                            .titleFontStyle(weight: .thin)
                            .padding()
                            .foregroundColor(Color.primary)
                    }

                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitleStyle("更多")
    }
}



#Preview {
    MoreView()
}
