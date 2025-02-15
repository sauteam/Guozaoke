//
//  ThemeManager.swift
//  Guozaoke
//
//  Created by scy on 2025/2/14.
//

import SwiftUI

enum ThemeColor: String, Hashable {
    case systemBlue = "System Blue"
    case coffeeBrown = "Coffee Brown"
    case red = "Red"

    var color: Color {
        switch self {
        case .systemBlue:
            return Color.blue
        case .coffeeBrown:
            return Color.brown
        case .red:
            return Color.red
        }
    }
}

struct Theme: Hashable {
    var primaryColor: ThemeColor
    var secondaryColor: ThemeColor

    var textColor: Color {
        switch primaryColor {
        case .systemBlue:
            return .white
        case .coffeeBrown:
            return .black
        case .red:
            return .white
        }
    }

    var imageTint: Color {
        switch secondaryColor {
        case .systemBlue:
            return .white
        case .coffeeBrown:
            return .black
        case .red:
            return .white
        }
    }

    // Conform to Hashable by implementing `hash(into:)`
    func hash(into hasher: inout Hasher) {
        hasher.combine(primaryColor)
        hasher.combine(secondaryColor)
    }

    // Conform to Equatable for comparing
    static func ==(lhs: Theme, rhs: Theme) -> Bool {
        return lhs.primaryColor == rhs.primaryColor && lhs.secondaryColor == rhs.secondaryColor
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme
    
    @Published var selectedColor: ThemeColor {
        didSet {
            switch selectedColor {
            case .systemBlue:
                setTheme(Theme(primaryColor: .systemBlue, secondaryColor: .red))
            case .coffeeBrown:
                setTheme(Theme(primaryColor: .coffeeBrown, secondaryColor: .systemBlue))
            case .red:
                setTheme(Theme(primaryColor: .red, secondaryColor: .systemBlue))
            }
        }
    }

    init(theme: Theme) {
        self.currentTheme  = theme
        self.selectedColor = theme.primaryColor
    }

    func setTheme(_ theme: Theme) {
        currentTheme = theme
    }
    
    func switchToTheme(_ themeColor: ThemeColor) {
        switch themeColor {
        case .systemBlue:
            setTheme(Theme(primaryColor: .systemBlue, secondaryColor: .red))
        case .coffeeBrown:
            setTheme(Theme(primaryColor: .coffeeBrown, secondaryColor: .systemBlue))
        case .red:
            setTheme(Theme(primaryColor: .red, secondaryColor: .systemBlue))
        }
    }
}


extension View {
    func themedText(using theme: Theme) -> some View {
        self.foregroundColor(theme.textColor)
            .font(.system(size: 18, weight: .bold))
    }

    func themedImage(using theme: Theme) -> some View {
        self.foregroundColor(theme.imageTint)
    }
}
