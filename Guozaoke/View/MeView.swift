//
//  MeView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct MeView: View {
    //@State private var userId: String
    //@State private var isLoading = true
    @StateObject private var parser = UserInfoParser()
    @State private var showSettingView  = false

    var body: some View {
        NavigationView {
            VStack() {
                MyProfileView()
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !parser.hadData {
                    Task { await parser.fetchUserInfoAndData(AccountState.userName, reset: true) }
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
}

struct MyProfileView: View {
    @Environment(\.colorScheme) var colorScheme  // 检测当前系统模式
    
    let items: [(icon: String, title: String, destination: Any)]
    
    init() {
        items = [
            (SFSymbol.bookmarkFill.rawValue, "收藏", MyCollectionView(topic: .collections)),
            (SFSymbol.collectionFill.rawValue, "关注", MyCollectionView(topic: .follows)),
            (SFSymbol.clock.rawValue, "最近浏览", MyCollectionView(topic: .browse)),
            (SFSymbol.moonphase.rawValue, "模式切换", DarkModeToggleView()),
            (SFSymbol.setting.rawValue, "设置", SettingView())
        ]
    }

    var body: some View {
        VStack {
            // 用户信息部分
            HStack {
                NavigationLink(destination: UserInfoView(userId: AccountState.userName)) {
                    KFImageView(AccountState.avatarUrl)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    NavigationLink(destination: UserInfoView(userId: AccountState.userName)) {
                        Text("sauchye")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    NavigationLink(destination: UserInfoView(userId: AccountState.userName)) {
                        Text("我的主页")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            .padding()
            
            Divider()

            List {
                ForEach(0..<items.count, id: \.self) { index in
                    NavigationLink(destination: viewForItem(items[index].destination), label: {
                        HStack {
                            Image(systemName: items[index].icon)
                                //.foregroundColor(.blue)
                                .frame(width: 30)
                            Text(items[index].title)
                                .font(.headline)
                            Spacer()
                        }
                    })
                    .padding(.vertical, 8)
                }
            }
            .listStyle(PlainListStyle())
            Divider()
        }
    }
    
    @ViewBuilder
    private func viewForItem(_ item: Any) -> some View {
        switch item {
        case is MyCollectionView:
            MyCollectionView(topic: .collections)
        case is MyCollectionView:
            MyCollectionView(topic: .follows)
        case is MyCollectionView:
            MyCollectionView(topic: .browse)
        case is DarkModeToggleView:
            DarkModeToggleView()
        case is SettingView:
            SettingView()
        default:
            Text("未知页面")
        }
    }
}
