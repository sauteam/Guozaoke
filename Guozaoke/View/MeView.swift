//
//  MeView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

enum ModeTypeEnum: String, CaseIterable {
    case system
    case light
    case dark

    var name: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }
}

struct MeView: View {
    @StateObject private var parser = UserInfoParser()
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack() {
            MyProfileView()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !AccountState.isLogin() {
                LoginStateChecker.LoginStateHandle()
            }
                        
            NotificationCenter.default.addObserver(forName: .logoutSuccessNoti, object: nil, queue: .main) { _ in
                print("[logout] me")
            }

            if !parser.hadData {
                if AccountState.userName.isEmpty {
                    return
                }
                Task { await parser.fetchUserInfoAndData(AccountState.userName.userProfileUrl(), reset: true) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { notification in
            print("[login] me")
            if let userInfo = notification.userInfo,
               let user = userInfo as? Dictionary<String, Any> {
                let username  = user["userName"] as? String ?? ""
                Task { await parser.fetchUserInfoAndData(username.userProfileUrl(), reset: true) }
            }

        }
        .onDisappear {
            if !AccountState.isLogin() {
                LoginStateChecker.LoginStateHandle()
            }
            NotificationCenter.default.removeObserver(self, name: .loginSuccessNoti, object: nil)
            NotificationCenter.default.removeObserver(self, name: .logoutSuccessNoti, object: nil)
        }
    }
}

struct MyProfileView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = ModeTypeEnum.system.rawValue
    @State private var currentMode: ModeTypeEnum = .system
    //let parser: UserInfoParser
    //@EnvironmentObject var themeManager: ThemeManager
    var body: some View {
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
            }
            
            Section {
                let username      = AccountState.userName
                let collectionUrl = "/u/\(username)/favorites"
                let topicUrl = "/u/\(username)/topics"
                let replyUrl = "/u/\(username)/replies"
                
                NavigationLink(destination: MyCollectionView(linkUrl: collectionUrl, linkText: "我的收藏")) {
                    ProfileRow(icon: SFSymbol.heartFill.rawValue, title: "收藏")
                }
                
                NavigationLink(destination: MyCollectionView(linkUrl: topicUrl, linkText: "我的主题"))  {
                    ProfileRow(icon: SFSymbol.topics.rawValue, title: "主题")
                }
                
                NavigationLink(destination: MyReplyListView(linkUrl: replyUrl, linkText: "我的回复"))  {
                    ProfileRow(icon: SFSymbol.coment.rawValue, title: "我的回复")
                }
            }
        
            
             Section {
                 ProfileRow(icon: SFSymbol.app.rawValue, title: "App Store查看") {
                         GuozaokeAppInfo.toAppStore()
                     }
                 ProfileRow(icon: SFSymbol.heartCircle.rawValue, title: "给我们鼓励") {
                         GuozaokeAppInfo.toWriteReview()
                     }
             }
            
            Section {
                NavigationLink(destination: DarkModeToggleView()) {
                    ProfileRow(icon: SFSymbol.moonphase.rawValue, title: "模式切换")
                }
//                HStack {
//                    ProfileRow(icon: SFSymbol.moonphase.rawValue, title: "模式切换")
//                    Spacer()
//                    Picker("主题", selection: $appearanceMode) {
//                        ForEach(ModeTypeEnum.allCases, id: \.self) { mode in
//                            Text(mode.name)
//                                .tag(mode)
//                        }
//                    }
//                    .padding()
//                   .pickerStyle(DefaultPickerStyle())
//                   .onChange(of: currentMode) { newMode in
//                       appearanceMode = newMode.rawValue
//                       applyAppearanceMode(newMode)
//                   }
//                   .padding()
//                }
//                .onAppear {
//                    if let savedMode = ModeTypeEnum(rawValue: appearanceMode) {
//                        currentMode = savedMode
//                        applyAppearanceMode(currentMode)
//                    }
//                }
                NavigationLink(destination: SettingView()) {
                    ProfileRow(icon: SFSymbol.setting.rawValue, title: "设置")
                }
            }
         .listStyle(InsetGroupedListStyle())
        }
    }
    
    private func applyAppearanceMode(_ mode: ModeTypeEnum) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        switch mode {
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        default:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    var action: (() -> Void)?
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 25, height: 25)
                    .foregroundColor(.primary)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                //SFSymbol.rightIcon
                //    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
