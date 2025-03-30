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
    @EnvironmentObject var purchaseAppState: PurchaseAppState
    @State var showPurchaseView: Bool = false
    var body: some View {
        VStack() {
            MyProfileView()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitleStyle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPurchaseView, content: {
            InAppPurchaseView(isPresented: $showPurchaseView, purchaseAppState: purchaseAppState)
        })
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    hapticFeedback()
                    showPurchaseView.toggle()
                }) {
                    SFSymbol.checkmarkSealFill
                }
            }
        }
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
                Task { await parser.fetchUserInfoAndData(AccountState.userName.userProfileUrl, reset: true) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loginSuccessNoti)) { notification in
            print("[login] me")
            if let userInfo = notification.userInfo,
               let user = userInfo as? Dictionary<String, Any> {
                let username  = user["userName"] as? String ?? ""
                Task { await parser.fetchUserInfoAndData(username.userProfileUrl, reset: true) }
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
                            .avatar(size: 60)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(AccountState.userName)
                                .titleFontStyle()
                            
                            Text("我的主页")
                                .titleFontStyle()
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
                    ProfileRow(icon: SFSymbol.heartFill.rawValue, title: "我的收藏")
                }
                
                NavigationLink(destination: MyCollectionView(linkUrl: topicUrl, linkText: "我的主题"))  {
                    ProfileRow(icon: SFSymbol.pencilCircleFill.rawValue, title: "我的主题")
                }
                
                NavigationLink(destination: MyReplyListView(linkUrl: replyUrl, linkText: "我的回复"))  {
                    ProfileRow(icon: SFSymbol.coment.rawValue, title: "我的回复")
                }
                
                NavigationLink(destination: BlockListView())  {
                    ProfileRow(icon: SFSymbol.block.rawValue, title: "屏蔽列表")
                }
            }
            
            Section {
                
                NavigationLink(destination: IntroductationView())  {
                    ProfileRow(icon: SFSymbol.topics.rawValue, title: "评论发帖")
                }
                
                NavigationLink(destination: FaqView()) {
                    ProfileRow(icon: SFSymbol.nosign.rawValue, title: "Faq")
                }
                
                NavigationLink(destination: AboutView())  {
                    ProfileRow(icon: SFSymbol.info.rawValue, title: "关于")
                }
                
                NavigationLink(destination: MoreView())  {
                    ProfileRow(icon: SFSymbol.more.rawValue, title: "更多")
                }
            }
            
            
            Section {
                
                NavigationLink(destination: SettingNodeListView()) {
                    ProfileRow(icon: SFSymbol.topics.rawValue, title: "节点顺序")
                }
                
                NavigationLink(destination: DarkModeToggleView()) {
                    ProfileRow(icon: SFSymbol.moonphase.rawValue, title: "模式切换")
                }
                
                NavigationLink(destination: FontSizePreviewView()) {
                    ProfileRow(icon: SFSymbol.textformatSize.rawValue, title: "字体大小")
                }
                
                NavigationLink(destination: SettingView()) {
                    ProfileRow(icon: SFSymbol.setting.rawValue, title: "设置")
                }
            }
            
            Section {
                
                Button {
                    AppInfo.toAppStore()
                } label: {
                    ProfileRow(icon: SFSymbol.app.rawValue, title: "最新版本")
                }
                
                Button {
                    AppInfo.toWriteReview()
                } label: {
                    ProfileRow(icon: SFSymbol.heartCircle.rawValue, title: "给我们鼓励")
                }
            }
            
            Section {
                Button {
                    AppInfo.appleEula.openURL()
                } label: {
                    ProfileRow(icon: SFSymbol.personCircle.rawValue, title: "使用条款「EULA」")
                }
                
                Button {
                    APIService.feedbackAllLink.openURL()
                } label: {
                    ProfileRow(icon: SFSymbol.handRaisedCircle.rawValue, title: "隐私协议")
                }
                
                Button {
                    AppInfo.guozaokeGithubUrl.openURL()
                } label: {
                    ProfileRow(icon: SFSymbol.share.rawValue, title: "开源地址")
                }
            }
            
            HStack {
                Spacer()
                Text(AppInfo.AppBeiAnText)
                    .subTitleFontStyle()
                    .onTapGesture {
                        hapticFeedback()
                        AppInfo.beianGovUrl.openURL()
                    }
                Spacer()
            }
            .listRowSeparator(.hidden)
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
        HStack {
            Image(systemName: icon)
                .frame(width: 25, height: 25)
                .foregroundColor(.primary)
            
            Text(title)
                .foregroundColor(.primary)
                .titleFontStyle()
            Spacer()
            //SFSymbol.rightIcon
                //.foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
//        Button(action: {
//            action?()
//        }) {
//        }
//        .buttonStyle(PlainButtonStyle())
    }
}
