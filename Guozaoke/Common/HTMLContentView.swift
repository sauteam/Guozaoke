//
//  HTMLContentView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI

struct HTMLContentView: View {
    let content: String
    let fontSize: CGFloat
    var onLinkTap: ((URL) -> Void)?
    var onUserTap: ((String) -> Void)?
    var onTagTap: ((String) -> Void)?
    var onEmailTap: ((String) -> Void)?
    var onPhoneTap: ((String) -> Void)?
    
    @State private var showTopicInfo = false
    @State private var showUserInfo = false
    @State private var linkUserId = ""
    @State private var topicId = ""
    @Environment(\.colorScheme) var colorScheme

    init(
        content: String,
        fontSize: CGFloat = 16,
        onLinkTap: ((URL) -> Void)? = nil,
        onUserTap: ((String) -> Void)? = nil,
        onTagTap: ((String) -> Void)? = nil,
        onEmailTap: ((String) -> Void)? = nil,
        onPhoneTap: ((String) -> Void)? = nil
    ) {
        self.content = content
        self.fontSize = fontSize
        self.onLinkTap = onLinkTap
        self.onUserTap = onUserTap
        self.onTagTap = onTagTap
        self.onEmailTap = onEmailTap
        self.onPhoneTap = onPhoneTap
    }
        
    var body: some View {
        if let attributedString = createAttributedString() {
            Text(AttributedString(attributedString))
                .font(.system(size: fontSize))
                .foregroundColor(Color.primary)
                .textSelection(.enabled)
                .environment(\.openURL, OpenURLAction { url in
                    switch url.scheme {
                    case "user":
                        if let urlString = url.absoluteString.removingPercentEncoding {
                            let userId = urlString.replacingOccurrences(of: "user://", with: "")
                            log("[at] userId \(userId)")
                            if userId.isEmpty == false {
                                linkUserId = userId
                                log("linkUserId \(linkUserId)")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showUserInfo = true
                                }
                            }
                            onUserTap?(userId)
                        }
                    case "tag":
                        onTagTap?(url.host ?? "")
                    case "mailto":
                        onEmailTap?(url.absoluteString.replacingOccurrences(of: "mailto:", with: ""))
                    case "tel":
                        onPhoneTap?(url.absoluteString.replacingOccurrences(of: "tel:", with: ""))
                    default:
                        onLinkTap?(url)
                        let urlString = url.absoluteString
                        if urlString.contains(APIService.baseUrlString), urlString.contains("/t/") {
                            topicId = urlString.replacingOccurrences(of: APIService.baseUrlString, with: "")
                            log("topic \(topicId)")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showTopicInfo = true
                            }
                        } else {
                            url.openSafari()
                        }
                    }
                    return .handled
                })
            
            NavigationLink(destination: UserInfoView(userId: linkUserId), isActive: $showUserInfo) {
                EmptyView()
            }

            NavigationLink(destination: PostDetailView(postId: topicId), isActive: $showTopicInfo) {
                EmptyView()
            }
        } else {
            Text(content)
                .textSelection(.enabled)
                .font(.system(size: fontSize))
                .foregroundColor(Color.primary)
        }
    }
    
    private func createAttributedString() -> NSAttributedString? {
        let isDarkMode = colorScheme == .dark
        let textColor = isDarkMode ? "#FFFFFF" : "#000000" // 适配黑暗模式
        let linkColor = isDarkMode ? "#1E90FF" : "#007AFF" // 调整超链接颜色
        
        var processedContent = content
        // 处理用户链接
        let userPattern = "uid=(\\d+)"
        if let regex = try? NSRegularExpression(pattern: userPattern) {
            let range = NSRange(processedContent.startIndex..., in: processedContent)
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                range: range,
                withTemplate: "<a href=\"user://$1\">$0</a>"
            )
        }
        // 处理已经是HTML格式的链接
        if !content.contains("<a") {
            // 网址链接
            let urlPattern = "(https?://[\\w\\d./-]+)"
            processedContent = processedContent.replacingOccurrences(
                of: urlPattern,
                with: "<a href=\"$1\">$1</a>",
                options: .regularExpression
            )
            
            // 邮箱地址
            let emailPattern = "([\\w\\.-]+@[\\w\\.-]+\\.[\\w-]{2,})"
            processedContent = processedContent.replacingOccurrences(
                of: emailPattern,
                with: "<a href=\"mailto:$1\" class=\"email\">$1</a>",
                options: .regularExpression
            )
            
            // 手机号码（中国大陆格式）
            let phonePattern = "(1[3-9]\\d{9})"
            processedContent = processedContent.replacingOccurrences(
                of: phonePattern,
                with: "<a href=\"tel:$1\" class=\"phone\">$1</a>",
                options: .regularExpression
            )
        }
        
        // 处理 @用户
        processedContent = processedContent.replacingOccurrences(
            of: "@([\\w\\-]+)",
            with: "<a href=\"user://$1\" class=\"user\">@$1</a>",
            options: .regularExpression
        )
        
        // 处理 #标签#
        processedContent = processedContent.replacingOccurrences(
            of: "#([^#]+)#",
            with: "<a href=\"tag://$1\" class=\"tag\">#$1#</a>",
            options: .regularExpression
        )
        
        let styledHTML = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body {
            font-family: -apple-system;
            font-size: \(fontSize)px;
            line-height: 1.5;
            color: \(textColor);
            margin: 0;
            padding: 0;
            word-wrap: break-word;
        }
        a {
            color: \(linkColor);
            text-decoration: none;
        }
        a.user {
            color: \(linkColor);
            font-weight: normal;
        }
        a.tag {
            color: \(linkColor);
            font-weight: normal;
        }
        a.email {
            color: \(linkColor);
            font-weight: normal;
        }
        a.phone {
            color: \(linkColor);
            font-weight: normal;
        }
        img {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
        }
        p {
            margin: 8px 0;
        }
        </style>
        </head>
        <body>
        \(processedContent)
        </body>
        </html>
        """
        
        guard let data = styledHTML.data(using: .utf8) else { return nil }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        var attributedString: NSAttributedString?
            
            DispatchQueue.main.async {
                do {
                    attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
                } catch {
                    print("🚨 解析 HTML 失败: \(error)")
                }
            }
            return attributedString
    }
}

//// MARK: - 预览
//struct HTMLContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                // 测试所有功能
//                HTMLContentView(
//                    content: """
//                        联系方式：
//                        邮箱：example@email.com
//                        电话：13812345678
//                        网站：https://www.example.com
//                        社交：@user #SwiftUI#
//                        链接：<a href='https://apple.com'>Apple</a>
//                        """,
//                    fontSize: 16,
//                    onLinkTap: { url in
//                        print("Link tapped: \(url)")
//                    },
//                    onUserTap: { username in
//                        print("User tapped: \(username)")
//                    },
//                    onTagTap: { tag in
//                        print("Tag tapped: \(tag)")
//                    },
//                    onEmailTap: { email in
//                        print("Email tapped: \(email)")
//                    },
//                    onPhoneTap: { phone in
//                        print("Phone tapped: \(phone)")
//                    }
//                )
//            }
//            .padding()
//        }
//    }
//}


import WebKit

struct WebView: UIViewRepresentable {
    let htmlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(htmlString, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}



struct AttributedTextView: UIViewRepresentable {
    let htmlString: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.dataDetectorTypes = [.link] // 支持超链接
        textView.backgroundColor = .clear
        textView.attributedText = convertHtmlToAttributedString(htmlString)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = convertHtmlToAttributedString(htmlString)
    }

    private func convertHtmlToAttributedString(_ html: String) -> NSAttributedString {
        guard let data = html.data(using: .utf8) else { return NSAttributedString() }
        return try! NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.html,
                                                 .characterEncoding: String.Encoding.utf8.rawValue],
                                       documentAttributes: nil)
    }
}


