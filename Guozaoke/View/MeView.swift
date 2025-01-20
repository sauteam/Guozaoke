//
//  MeView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct MeView: View {
    let userId: String
    @State private var isLoading = true
    @StateObject private var parser = UserInfoParser()
    @State private var selectedTab = 0
    @State private var followText = "+关注"
    @State private var showSettingView  = false

    var body: some View {
        NavigationView {
            VStack() {
                if parser.isLoading && parser.userInfo == nil {
                    ProgressView("")
                } else if let errorMessage = parser.errorMessage {
                    Text("加载失败: \(errorMessage)")
                        .foregroundColor(.red)
                } else if let userInfo = parser.userInfo {
                    // Header Section
                    VStack(spacing: 10) {
                        KFImageView(userInfo.avatar)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        
                        Text(userInfo.username)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        let isMe = AccountState.isSelf(userName: userId)
                        if isMe {
                            Text("Email: \(userInfo.email)")
                                .font(.caption)
                                .bold()
                        } else {
                            Button(action: {
                                print("关注按钮点击")
                                Task {
                                    do {
                                        let (success, _) = await parser.followUserAction(userInfo.followLink) ?? (false, nil)
                                        if success == true {
                                            //followText = userInfo.followTextChange
                                            await parser.fetchUserInfoAndData(self.userId)
                                        }
                                    }
                                }
                                
                            }) {
                                Text(userInfo.followTextChange)
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        }
                        
                        Text("\(userInfo.number) \(userInfo.joinDate)")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    Picker("选择列表", selection: $selectedTab) {
                        Text("主题").tag(0)
                        Text("回复").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // List Section
                    if selectedTab == 0 {
                        List {
                            ForEach(parser.topics) { post in
                                NavigationLink {
                                    PostDetailView(postId: post.link)
                                } label: {
                                    PostRowView(post: post)
                                        .onAppear {
                                            if post == parser.topics.last {
                                                Task { await parser.fetchUserInfoAndData(userId, reset: false) }
                                            }
                                        }
                                }
                                
                            }
                            
                            if parser.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .listRowSeparator(.hidden)
                            } else if !parser.hasMoreData, !parser.topics.isEmpty {
                                
                                HStack {
                                    Spacer()
                                    Text(NoMoreDataTitle.homeList)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 12)
                            }
                        }
                        .buttonStyle(.plain)
                        .listStyle(.plain)
                        .refreshable {
                            Task { await parser.fetchUserInfoAndData(userId, reset: true) }
                        }
                    } else {
                        List {
                            ForEach(parser.replies) { post in
                                NavigationLink {
                                    PostDetailView(postId: post.titleLink)
                                } label: {
                                    MyReplyRowView(myReply: post, userId: userId)
                                        .onAppear {
                                            if post == parser.replies.last {
                                                Task { await parser.fetchUserInfoAndData(userId, reset: false) }
                                            }
                                        }
                                }
                            }
                            if parser.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .listRowSeparator(.hidden)
                            } else if !parser.hasMoreData, !parser.replies.isEmpty {
                                
                                HStack {
                                    Spacer()
                                    Text(NoMoreDataTitle.homeList)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 12)
                            }
                        }
                        .buttonStyle(.plain)
                        .listStyle(.plain)
                        .refreshable {
                            Task { await parser.fetchUserInfoAndData(userId, reset: true) }
                        }
                    }
                }
            }
            .navigationTitle(AccountState.isSelf(userName: userId) ? "我的主页" : parser.userInfo?.nickname ?? "个人主页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettingView = true
                    }) {
                        SFSymbol.setting
                    }
                }
            }
            .sheet(isPresented: $showSettingView) {
                SettingView(isPresented: $showSettingView)
            }
        }
        .onAppear {
            if !parser.hadData {
                Task { await parser.fetchUserInfoAndData(userId, reset: true) }
            }
            
            NotificationCenter.default.addObserver(forName: .loginSuccessNoti, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let user = userInfo as? Dictionary<String, Any> {
                    let username  = user["userName"] as? String ?? ""
                    Task { await parser.fetchUserInfoAndData(username, reset: true) }
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
        }
    }
}


//#Preview {
//    MeView()
//}
