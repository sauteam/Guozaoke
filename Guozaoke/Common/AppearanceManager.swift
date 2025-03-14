//
//  Guozaoke
//
//  Created by scy on 2025/2/10.
//

import SwiftUI

// MARK: - UserDefaultsKeys

let titleFontName = UserDefaultsKeys.settingFontName

let headFontSize = titleFontSize + 2
/// 推送字体大小
let subTitleFontSize = titleFontSize-2

/// 标题、回复字体大小
let titleFontSize = UserDefaultsKeys.settingFontSize

let usernameFontSize = 13.0
let menuFontSize     = 15.0

/// 推荐字体
enum RecommandFontOption: CaseIterable, Identifiable {
    case system
    case pingFangSCThin
    case pingFangSCLight
    case pingFangSCRegular
    case pingFangSCMedium

    var id: String {
        name
    }

    var name: String {
        switch self {
        case .system:
            return "系统默认"
        case .pingFangSCThin:
            return "PingFangSC-Thin"
        case .pingFangSCLight:
            return "PingFangSC-Light"
        case .pingFangSCRegular:
            return "PingFangSC-Regular"
        case .pingFangSCMedium:
            return "PingFangSC-Medium"
        }
    }

    var size: CGFloat {
        return UserDefaultsKeys.fontSize16
    }
}

struct UserDefaultsKeys {
    static let pushNotificationsEnabled = "pushNotificationsEnabled"
    static let hapticFeedbackEnabled    = "hapticFeedbackEnabled"
    static let homeListRefreshEnabled   = "homeListRefreshEnabled"
    static let hiddenTabView   = "hiddenTabView"
    static let fontSizeKey = "fontSizeKey"
    static let fontNameKey = "fontNameKey"
    /// 18
    static let fontSize16  = 18.0
    static let fontName    = UIFont.systemFont(ofSize: settingFontSize).fontName
    
    static var settingPushNotificationsEnabled: Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.pushNotificationsEnabled)
    }
    
    static var settingHapticFeedbackEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.hapticFeedbackEnabled)
    }
    
    static var homeListRefresh: Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.homeListRefreshEnabled)
    }
    
    static var tabViewHidden: Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.hiddenTabView)
    }
    
    static var settingFontSize: CGFloat {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.fontSizeKey) as? CGFloat ?? fontSize16
    }
    
    static var settingFontName: String {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.fontNameKey) as? String ?? fontName
    }
}

func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    guard UserDefaultsKeys.settingHapticFeedbackEnabled else { return }

    DispatchQueue.main.async {
        let impactGenerator = UIImpactFeedbackGenerator(style: style)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
    }
}


// MARK: -

class AppearanceManager: ObservableObject {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    func getCurrentModeDescription() -> String {
        let appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        switch appearanceMode {
        case "light":
            return "浅色模式"
        case "dark":
            return "深色模式"
        default:
            return "跟随系统"
        }
    }
    
    func updateAppearanceMode(_ mode: String) {
        appearanceMode = mode
   }
}
