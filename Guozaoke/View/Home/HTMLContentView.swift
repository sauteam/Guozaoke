//
//  HTMLContentView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

// MARK: - 方案1: 使用 UIKit 的 NSAttributedString 处理
struct HTMLContentView: View {
    let content: String
    let fontSize: CGFloat
    
    init(content: String, fontSize: CGFloat = 16) {
        self.content = content
        self.fontSize = fontSize
    }
    
    var body: some View {
        if let attributedString = createAttributedString() {
            Text(AttributedString(attributedString))
                .textSelection(.enabled)
        } else {
            Text(content)
                .textSelection(.enabled)
                .font(.system(size: fontSize))
            Divider()
                .padding(.vertical, 3)
        }
    }
    
    private func createAttributedString() -> NSAttributedString? {
        // 添加基础样式的 HTML 包装
        let styledHTML = """
        <html>
        <head>
        <style>
        body {
            font-family: -apple-system;
            font-size: \(fontSize)px;
            line-height: 1.5;
            color: #000000;
        }
        a {
            color: #007AFF;
            text-decoration: none;
        }
        img {
            max-width: 100%;
            height: auto;
        }
        </style>
        </head>
        <body>
        \(content)
        </body>
        </html>
        """
        
        guard let data = styledHTML.data(using: .utf8) else { return nil }
        
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }
}

// MARK: - 方案2: 使用 WebKit 实现
import WebKit

struct HTMLContentView2: View {
    let content: String
    let fontSize: CGFloat
    
    init(content: String, fontSize: CGFloat = 16) {
        self.content = content
        self.fontSize = fontSize
    }
    
    var body: some View {
        WebView(content: content, fontSize: fontSize)
    }
}

struct WebView: UIViewRepresentable {
    let content: String
    let fontSize: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 添加基础样式的 HTML 包装
        let styledHTML = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        body {
            font-family: -apple-system;
            font-size: \(fontSize)px;
            line-height: 1.5;
            color: #000000;
            margin: 0;
            padding: 0;
            background-color: transparent;
        }
        a {
            color: #007AFF;
            text-decoration: none;
        }
        img {
            max-width: 100%;
            height: auto;
        }
        p {
            margin: 8px 0;
        }
        </style>
        </head>
        <body>
        \(content)
        </body>
        </html>
        """
        
        webView.loadHTMLString(styledHTML, baseURL: nil)
        
        // 注入 JavaScript 以获取内容高度
        webView.evaluateJavaScript("document.documentElement.scrollHeight") { height, _ in
            if let height = height as? CGFloat {
                webView.frame.size.height = height
            }
        }
    }
}
