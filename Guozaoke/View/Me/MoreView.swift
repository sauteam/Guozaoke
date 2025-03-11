//
//  MoreView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/9.
//

import SwiftUI

struct MoreView: View {
    @State var showBase64View: Bool = false
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section {
                        NavigationLink(destination: UserInfoView(userId: "isau")) {
                            OneTextView(title: "过早客iOS开发者「非官方」")
                        }
                        
                        NavigationLink(destination: UserInfoView(userId: "Mario")) {
                            OneTextView(title: "网站管理大大：Mario")
                        }

                        NavigationLink(destination: PostDetailView(postId: APIService.androidUpdateTopicInfo)) {
                            OneTextView(title: "mzlogin大大：mzlogin")
                        }
                        
                        NavigationLink(destination: PostDetailView(postId: APIService.iosUpdateTopicInfo)) {
                            OneTextView(title: "更新说明")
                        }
                    }
                    
                    Section {
                        OneTextView(title: "Base64加密解密")
                            .onTapGesture {
                                showBase64View.toggle()
                            }
                    }
                }
                .sheet(isPresented: $showBase64View) {
                    Base64View(isPresented: $showBase64View)
                        .presentationDragIndicator(.visible)
                }
            }
            .navigationTitleStyle("更多")
        }
    }
}


struct OneTextView: View {
    let title: String
    var body: some View {
        Text(title)
            .titleFontStyle(weight: .thin)
            .padding()
            .foregroundColor(Color.primary)
    }
}


#Preview {
    MoreView()
}
