//
//  SafariView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/27.
//

import SwiftUI
import SafariServices

// 1. 创建 SafariView 封装 UIKit 组件
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .systemBlue  // 设置导航栏颜色
        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // 不需要更新逻辑
    }
}

//#Preview {
//    SafariView()
//}
