import Foundation
import SwiftUI

struct AppIconConfig {
    static let icons: [AppIcon] = [
        AppIcon(iconName: "AppIcon", iconImage: "zao-white", displayName: "默认"),
        AppIcon(iconName: "AppIcon", iconImage: "zao-dark", displayName: "深色"),
        AppIcon(iconName: "ZaoDark", iconImage: "ZaoDark", displayName: "深色"),
        AppIcon(iconName: "ZaoRed", iconImage: "ZaoRed", displayName: "浅色"),
    ]
    
    static var currentIcon: String? {
        UIApplication.shared.alternateIconName
    }
}

struct AppIcon: Identifiable, Hashable {
    let id = UUID()
    let iconName: String
    let iconImage: String
    let displayName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppIcon, rhs: AppIcon) -> Bool {
        lhs.id == rhs.id
    }
}

