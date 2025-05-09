//
//  SFSymbol.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI

enum SFSymbol: String {
    /// 􀓣
    case personCircle = "person.circle"
    /// 􀷊
    case handRaisedCircle = "hand.raised.circle"
    case checkmarkSealFill = "checkmark.seal.fill"
    case circle = "circle"
    case checkmarkCircleFill = "checkmark.circle.fill"
    case lockFill = "lock.fill"
    case documentViewfinderFill = "document.viewfinder.fill"
    case link = "link"
    case handPointLeft = "hand.point.up.left"
    case trashSlash = "trash.slash"
    case envelope = "envelope"
    /// 􀻷
    case person3 = "person.3.sequence"
    ///􀻸
    case person3fill = "person.3.sequence.fill"
    /// 􀅼
    case add = "plus"
    case edit = "pencil"
    /// 􀊫
    case search = "magnifyingglass"
    /// 􀉁
    case copy  = "document.on.document"
    /// 􀉌
    case reply = "arrowshape.turn.up.left"
    /// nosign 􁝊
    case nosign = "nosign.app"
    /// 􀌬
    case report = "exclamationmark.bubble"
    /// 􀅴
    case info = "info.circle"
    /// 􀋭
    case unblock = "eye"
    /// 􀋯
    case block = "eye.slash"
    /// 􀊵
    case heartFill = "heart.fill"
    /// 􀊷
    case heartSlashFill = "heart.slash.fill"
    /// 􀉿
    case zan = "hand.thumbsup"
    /// 􀊀
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
    case rightIcon = "chevron.right"
    case helper = "questionmark.circle"
    case pencilCircle = "pencil.circle"
    case pencilCircleFill = "pencil.circle.fill"
    case exit = "iphone.and.arrow.forward.outward"
    case remove = "iphone.slash"
    case notice = "list.bullet.clipboard"
    case app = "app"
    case appFill = "app.fill"
    case textformatSize = "textformat.size"

    /// 􀊸
    case heartCircle = "heart.circle"
}

extension SFSymbol: View {
    var body: Image {
        Image(systemName: rawValue)
    }
    
    var image: Image {
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
