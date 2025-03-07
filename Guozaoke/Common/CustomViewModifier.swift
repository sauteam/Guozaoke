//
//  CustomViewModifier.swift
//  Guozaoke
//
//  Created by scy on 2025/3/7.
//

import SwiftUI

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
    func navigationTitleStyle(_ title: String, weight: Font.Weight? = .light)-> some View {
        customToolbarTitle(title, fontName: titleFontName, fontSize: titleFontSize, weight: weight)
    }
    
    func usernameFontStyle(weight: Font.Weight? = .light) -> some View {
        fontStyle(fontName: titleFontName, fontSize: usernameFontSize, weight: weight)
    }

    func subTitleFontStyle(weight: Font.Weight? = .light) -> some View {
        fontStyle(fontName: titleFontName, fontSize: subTitleFontSize, weight: weight)
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
    
    func customToolbarTitle(_ title: String, fontName: String, fontSize: CGFloat, weight: Font.Weight? = .light) -> some View {
        self.modifier(CustomToolbarTitle(title: title, fontName: fontName, fontSize: fontSize,  weight: weight))
    }
}

