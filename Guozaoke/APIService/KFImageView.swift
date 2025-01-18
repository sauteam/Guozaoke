//
//  KFImageView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI
import Kingfisher

// MARK: - Kingfisher 图片加载视图

struct KFImageView: View {
    let url: String?
    var placeholder: AnyView
    
    init(
        _ url: String?,
        placeholder: AnyView = AnyView(Color.gray.opacity(0.3))
    ) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        KFImage(URL(string: url ?? ""))
            .placeholder { progress in
                placeholder
            }
            .fade(duration: 0.25)
            .resizable()
    }
}

// MARK: - 扩展
extension KFImageView {
    // 头像样式
    func avatar(size: CGFloat = 40) -> some View {
        self.frame(width: size, height: size)
            .clipShape(Circle())
    }
    
    // 缩略图样式
    func thumbnail(width: CGFloat, height: CGFloat) -> some View {
        self.frame(width: width, height: height)
            .cornerRadius(8)
    }
    
    // 自适应宽度，固定高度
    func adaptiveHeight(_ height: CGFloat) -> some View {
        self.frame(maxWidth: .infinity)
            .frame(height: height)
            .cornerRadius(8)
    }
}


//#Preview {
//    KFImageView()
//}
