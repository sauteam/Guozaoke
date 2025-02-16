//
//  MembersGridView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/16.
//

let avatarUrl: String = "https://cdn.guozaoke.com//static/avatar/46/s_default.png"


import SwiftUI

struct MembersGridView: View {
    struct User: Identifiable {
        let id = UUID()
        let username: String
        let avatarName: String
        let link: String
    }
    
    let users: [User] = [
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
        User(username: "tx666", avatarName: avatarUrl, link: ""),
        User(username: "jincha", avatarName: avatarUrl, link: ""),
    ]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("活跃用户 \(users.count)")
                        .font(.body)
                        .padding(.horizontal, 20)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(users) { user in
                        VStack {
                            KFImageView(user.avatarName)
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                            
                            Text(user.username)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("成员")
    }
}

