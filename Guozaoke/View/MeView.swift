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
                    Task { await parser.fetchUserInfoAndData(AccountState.userName.userProfileUrl(), reset: true) }
                }
                
                NotificationCenter.default.addObserver(forName: .loginSuccessNoti, object: nil, queue: .main) { notification in
                    if let userInfo = notification.userInfo,
                       let user = userInfo as? Dictionary<String, Any> {
                        let username  = user["userName"] as? String ?? ""
                        
                        Task { await parser.fetchUserInfoAndData(username.userProfileUrl(), reset: true) }
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
    let items: [(icon: String, title: String, destination: Any)]
    
    init() {
        items = [
            (SFSymbol.bookmarkFill.rawValue, "收藏", MyCollectionView(topicType: .collections)),
            (SFSymbol.collectionFill.rawValue, "关注", MyCollectionView(topicType: .follows)),
            (SFSymbol.clock.rawValue, "最近浏览", MyCollectionView(topicType: .browse)),
            (SFSymbol.moonphase.rawValue, "模式切换", DarkModeToggleView()),
            (SFSymbol.setting.rawValue, "设置", SettingView())
        ]
    }

    var body: some View {
        VStack {
            List {
                Section {
                    HStack {
                        NavigationLink(destination: UserInfoView(userId: AccountState.userName)) {
                            KFImageView(AccountState.avatarUrl)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(AccountState.userName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("我的主页")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: MyCollectionView(topicType: .collections)) {
                            ProfileRow(icon: SFSymbol.bookmarkFill.rawValue, title: "收藏") {
                                
                            }
                        }
                        
                        NavigationLink(destination: MyCollectionView(topicType: .follows))  {              ProfileRow(icon: SFSymbol.collectionFill.rawValue, title: "关注") {}
                        }
                                
                        NavigationLink(destination: MyCollectionView(topicType: .browse))  {              ProfileRow(icon: SFSymbol.collectionFill.rawValue, title: "浏览") {}
                        }
                        
                        NavigationLink(destination: DarkModeToggleView()) {
                            ProfileRow(icon: "circle.lefthalf.filled", title: "模式切换") {}
                        }
                        
                        NavigationLink(destination: SettingView()) {
                            ProfileRow(icon: SFSymbol.setting.rawValue, title: "设置") {}
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    
//    @ViewBuilder
//    private func viewForItem(_ item: Any) -> some View {
//        switch item {
//        case is MyCollectionView:
//            MyCollectionView(topicType: .collections)
//        case is MyCollectionView:
//            MyCollectionView(topicType: .follows)
//        case is MyCollectionView:
//            MyCollectionView(topicType: .browse)
//        case is DarkModeToggleView:
//            DarkModeToggleView()
//        case is SettingView:
//            SettingView()
//        default:
//            Text("未知页面")
//        }
//    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.black)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                //Image(systemName: "chevron.right")
                    //.foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
    }
}
