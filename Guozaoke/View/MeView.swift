//
//  MeView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import JDStatusBarNotification

struct MeView: View {
    //@State private var userId: String
    //@State private var isLoading = true
    @StateObject private var parser = UserInfoParser()
    @State private var showSettingView  = false

    var body: some View {
//        NavigationView {
            VStack() {
                MyProfileView()
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !AccountState.isLogin() {
                    LoginStateChecker.LoginStateHandle()
                    return
                }
                if !parser.hadData {
                    if AccountState.userName.isEmpty {
                        return
                    }
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
                if !AccountState.isLogin() {
                    LoginStateChecker.LoginStateHandle()
                }
                NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
            }
//        }
    }
}

struct MyProfileView: View {
    @State private var needLogin = false

    var body: some View {
        List {
            Section {
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
                }
                
                Section {
                    let username      = AccountState.userName
                    let collectionUrl = "/u/\(username)/favorites"
                    let topicUrl = "/u/\(username)/topics"
                    let relpyUrl = "/u/\(username)/replies"
                    NavigationLink(destination: MyCollectionView(linkUrl: collectionUrl, linkText: "我的收藏")) {
                        ProfileRow(icon: SFSymbol.heartFill.rawValue, title: "收藏") {
                            
                        }
                    }
                    
                    NavigationLink(destination: MyCollectionView(linkUrl: topicUrl, linkText: "我的主题"))  {
                        ProfileRow(icon: SFSymbol.topics.rawValue, title: "主题") {}
                    }
                    
                    NavigationLink(destination: MyReplyListView(linkUrl: relpyUrl, linkText: "我的回复"))  {
                        ProfileRow(icon: SFSymbol.coment.rawValue, title: "我的回复") {}
                    }
                    
                    NavigationLink(destination: DarkModeToggleView()) {
                        ProfileRow(icon: SFSymbol.moonphase.rawValue, title: "模式切换") {
                            
                        }
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

struct ProfileRow: View {
    let icon: String
    let title: String
    let showRightArrow: Bool? = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    //.foregroundColor(.black)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                if showRightArrow == true {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
