//
//  SectionItemView.swift
//  V2er
//
//  Created by ghui on 2021/10/14.
//  Copyright © 2021 lessmore.io. All rights reserved.
//

import SwiftUI

fileprivate let paddingH: CGFloat = 15

struct SectionTitleView: View {
    var title: String = "Title"
    var style: Style
    enum Style {
        case normal
        case small
    }
    
    public init(_ title: String, style: Style = .normal) {
        self.title = title
        self.style = style
    }
    
    var body: some View {
        Text(title)
            .font(style == .normal ? .headline : .subheadline)
            .fontWeight(.heavy)
            .foregroundColor(.bodyText)
            .padding(.vertical, 8)
            .padding(.horizontal, style == .normal ? 2 : 8)
            .background {
                if style == .small {
                    HStack (spacing: 0) {
                        RoundedRectangle(cornerRadius: 99)
                            .foregroundColor(.tintColor.opacity(0.9))
                            .padding(.vertical, 8)
                            .frame(width: 3)
                        Spacer()
                    }
                }
            }
            .greedyWidth(.leading)
            .debug()
    }
}

//struct SectionTitleView_Previews: PreviewProvider {
//    static var previews: some View {
//        SectionTitleView("Title")
//    }
//}


struct SectionItemView: View {
    let title: String
    let icon: String
    var showDivider: Bool = true

    init(_ title: String,
         icon: String = .empty,
         showDivider: Bool = true) {
        self.title = title
        self.icon = icon
        self.showDivider = showDivider
    }

    var body: some View {
        SectionView(title, icon: icon, showDivider: showDivider) {
            Image(systemName: "chevron.right")
                .font(.body.weight(.regular))
                .foregroundColor(.gray)
                .padding(.trailing, paddingH)
        }
    }
}

struct SectionView<Content: View>: View {
    let content: Content
    let title: String
    var showDivider: Bool = true
    let icon: String

    init(_ title: String,
         icon: String = .empty,
         showDivider: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.showDivider = showDivider
        self.content = content()
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .padding(.leading, paddingH)
                .padding(.trailing, icon.isEmpty ? 0 : 5)
                .foregroundColor(.blue)
            HStack {
                Text(title)
                Spacer()
                content
                    .padding(.trailing, paddingH)
            }
            .padding(.vertical, 17)
            //.divider(showDivider ? 0.8 : 0.0)
        }
        .background(.white)
    }
}
