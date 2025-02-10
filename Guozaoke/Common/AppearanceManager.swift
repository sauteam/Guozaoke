//
//  AppearanceManager.swift
//  Guozaoke
//
//  Created by scy on 2025/2/10.
//

import SwiftUI

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
