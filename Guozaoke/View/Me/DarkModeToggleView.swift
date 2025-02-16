//
//  DarkModeToggleView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/21.
//

import SwiftUI

struct DarkModeToggleView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            List {
                modeButton(title: "浅色", mode: "light")
                modeButton(title: "深色", mode: "dark")
                modeButton(title: "跟随系统", mode: "system")
            }
            .buttonStyle(.borderless)
            .listStyle(.plain)
        }
        .navigationTitle("当前模式")
        .toolbar(.hidden, for: .tabBar)
        .padding()
        .onAppear {
            applyAppearanceMode(appearanceMode)
        }
    }
        
    private func modeButton(title: String, mode: String) -> some View {
        Button(action: {
            appearanceMode = mode
            applyAppearanceMode(mode)
        }) {
            HStack {
                Text(title)
                    //.foregroundColor(.gray)
                Spacer()
                if appearanceMode == mode {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
    
    private func applyAppearanceMode(_ mode: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        switch mode {
        case "light":
            window.overrideUserInterfaceStyle = .light
        case "dark":
            window.overrideUserInterfaceStyle = .dark
        default:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}
