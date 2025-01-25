//
//  SFSymbol.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI

enum SFSymbol: String {
    /// 􀅼
    case add = "plus"
    case edit = "pencil"
    /// 􀊫
    case search = "magnifyingglass"
    /// 􀉁
    case copy  = "document.on.document"
    /// 􀉌
    case reply = "arrowshape.turn.up.left"
    /// 􀇾
    case report = "exclamationmark.triangle"
    /// 􀅴
    case info = "info.circle"
    /// 􀋭
    case see = "eye.circle.fill"
    /// 􀋭
    case unblock = "eye"
    /// 􀋯
    case block = "eye.slash"
    /// 􀊴
    case collection = "heart"
    /// 􀊵
    case collectionFill = "heart.fill"
    /// 􀊴
    case zan = "hand.thumbsup"
    /// 􀊵
    case unzan = "hand.thumbsup.fill"
    /// 􀎬
    case safari = "safari"
    /// 􀎬
    case safariFill = "safari.fill"
    /// 􀈂
    case share = "square.and.arrow.up"
    /// 􀍟
    case setting = "gear"
    /// ellipsis
    case more = "ellipsis"
    /// clock
    case clock = "clock"
    /// bookmark
    case bookmark = "bookmark"
    case bookmarkFill = "bookmark.fill"
    case moonphase = "circle.lefthalf.filled"
    case coment = "ellipsis.message"
    case topics = "paperplane"
}

extension SFSymbol: View {
    var body: Image {
        Image(systemName: rawValue)
    }
    
    func resizable() -> Image {
        self.body.resizable()
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ text: String, systemImage: SFSymbol) {
        self.init(text, systemImage: systemImage.rawValue)
    }
}
