//
//  CustomViewModifier.swift
//  Guozaoke
//
//  Created by scy on 2025/3/7.
//

import SwiftUI

enum ContextMenuItem: String, CaseIterable {
    case copy    = "拷贝内容"
    case link    = "拷贝链接"
    case share   = "分享"
    case delete  = "删除"
    case safari  = "浏览器打开"
    case report  = "举报"
    case comment = "评论"
    case topic   = "相关主题"

    var label: String {
        self.rawValue
    }
    
    var image: Image {
        switch self {
        case .copy:
            return SFSymbol.copy.image
        case .link:
            return SFSymbol.link.image
        case .share:
            return SFSymbol.share.image
        case .delete:
            return SFSymbol.trashSlash.image
        case .safari:
            return SFSymbol.safari.image
        case .report:
            return SFSymbol.report.image
        case .comment:
            return SFSymbol.coment.image
        case .topic:
            return SFSymbol.topics.image
        }
    }
}


struct CustomContextMenuModifier: ViewModifier {
    let menuItems: [ContextMenuItem]
    let onAction: (ContextMenuItem) -> Void
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                ForEach(menuItems, id: \.self) { item in
                    Button(action: {
                        onAction(item)
                    }) {
                        HStack {
                            item.image
                            Text(item.label)
                        }
                    }
                }
            }
    }
}

struct CustomToolbarTitle: ViewModifier {
    var title: String
    var fontName: String
    var fontSize: CGFloat
    var weight: Font.Weight? = .light
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.custom(fontName, size: fontSize))
                        .fontWeight(weight)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct CustomFontSettings: ViewModifier {
    var fontName: String
    var fontSize: CGFloat
    var weight: Font.Weight? = .light
    func body(content: Content) -> some View {
        content
            .font(.custom(fontName, size: fontSize))
    }
}

extension View {
    func dynamicTabBarToolbar(isHidden: Bool) -> some View {
        self.toolbar(isHidden ? .hidden : .visible, for: .tabBar)
    }
    
    func tabbarToolBar() -> some View {
        self.toolbar(UserDefaultsKeys.tabViewHidden ? .hidden : .visible, for: .tabBar)
    }

    func navigationTitleStyle(_ title: String, weight: Font.Weight? = .light)-> some View {
        customToolbarTitle(title, fontName: titleFontName, fontSize: titleFontSize, weight: weight)
    }
    
    func usernameFontStyle(weight: Font.Weight? = .light) -> some View {
        fontStyle(fontName: titleFontName, fontSize: usernameFontSize, weight: weight)
    }

    func subTitleFontStyle(weight: Font.Weight? = .light, fontSize: CGFloat = subTitleFontSize) -> some View {
        fontStyle(fontName: titleFontName, fontSize: fontSize, weight: weight)
    }
    
    func titleFontStyle(weight: Font.Weight? = .light) -> some View {
        fontStyle(fontName: titleFontName, fontSize: titleFontSize, weight: weight)
    }
    
    func menuFontStyle(weight: Font.Weight? = .light) -> some View {
        fontStyle(fontName: titleFontName, fontSize: menuFontSize, weight: weight)
    }
    
    func fontStyle(fontName: String, fontSize: CGFloat, weight: Font.Weight? = .light) -> some View {
        customFontSettings(fontName: fontName, fontSize: fontSize, weight: weight)
    }
    
    private func customFontSettings(fontName: String, fontSize: CGFloat, weight: Font.Weight? = .light) -> some View {
        self.modifier(CustomFontSettings(fontName: fontName, fontSize: fontSize, weight: weight))
    }
    
    private func customToolbarTitle(_ title: String, fontName: String, fontSize: CGFloat, weight: Font.Weight? = .light) -> some View {
        self.modifier(CustomToolbarTitle(title: title, fontName: fontName, fontSize: fontSize,  weight: weight))
    }
    
    func customContextMenu(menuItems: [ContextMenuItem], onAction: @escaping (ContextMenuItem) -> Void) -> some View {
        self.modifier(CustomContextMenuModifier(menuItems: menuItems, onAction: onAction))
    }
}

extension View {
    func dynamicContextMenu(userInfo: String, report: Bool? = false, showSafari: Binding<Bool>, showSystemCopy: Binding<Bool>) -> some View {
        self.contextMenu {
            DynamicContextMenuContent(userInfo: userInfo, report: report, showSafari: showSafari, showSystemCopy: showSystemCopy)
        }
    }
}


@ViewBuilder
func DynamicContextMenuContent(userInfo: String,  report: Bool? = false, showSafari: Binding<Bool>, showSystemCopy: Binding<Bool>) -> some View {
    
    Button {
        showSystemCopy.wrappedValue.toggle()
    } label: {
        Text("选择文本")
        SFSymbol.handPointLeft
    }

    Button(action: {
        userInfo.copyToClipboard()
    }) {
        Text("拷贝内容")
        SFSymbol.copy
    }
    
    if let url = userInfo.extractURLs.first, url.absoluteString.isEmpty == false {
        if url.absoluteString != userInfo {
            Button(action: {
                url.absoluteString.copyToClipboard()
            }) {
                Text("拷贝链接")
                SFSymbol.link
            }
        }
        
//        Button(action: {
//            showSafari.wrappedValue.toggle()
//        }) {
//            Text("浏览器查看")
//            SFSymbol.safari
//        }
    }
        
    if let email = userInfo.extractEmails.first, email.contains("@") {
        if email != userInfo {
            Button(action: {
                email.copyToClipboard()
            }) {
                Text("拷贝邮箱")
                SFSymbol.copy
            }
        }
        // 点击可以发送邮箱
//        Button(action: {
//            guard let url = URL(string: "mailto:\(email)") else {
//                return
//            }
//            if UIApplication.shared.canOpenURL(url) {
//                UIApplication.shared.open(url)
//            } else {
//                logger("No email client available")
//            }
//        }) {
//            Text("发送邮件")
//            SFSymbol.envelope
//        }
    }
    
    if let userTags = userInfo.extractUserTags.first, userTags.count > 0  {
        Button(action: {
            userInfo.userTagString.copyToClipboard()
        }) {
            Text("拷贝@用户")
            SFSymbol.copy
        }
    }
    
    if let userTags = userInfo.base64TextList.first, userTags.count > 0  {
        Button(action: {
            userTags.copyToClipboard(userTags)
        }) {
            Text("拷贝Base64解码")
            SFSymbol.documentViewfinderFill
        }
    }
    
    if report == true {
        Button {
            ToastView.reportToast()
        } label: {
            Text("举报")
            SFSymbol.report
        }
    }
}
