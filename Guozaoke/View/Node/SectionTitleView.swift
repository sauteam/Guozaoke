//
//  SectionTitleView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/16.
//

import SwiftUI

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
            .padding(.vertical, 8)
            .padding(.horizontal, style == .normal ? 2 : 8)
            .background {
                if style == .small {
                    HStack (spacing: 0) {
                        RoundedRectangle(cornerRadius: 99)
                            .foregroundColor(.primary)
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
