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
    
    @State private var showUserInfo = false
    @State private var linkUserId = ""
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
                .textSelection(.enabled)
                .environment(\.openURL, OpenURLAction { url in
                    switch url.scheme {
                    case "user":
                        if let urlString = url.absoluteString.removingPercentEncoding {
                            showUserInfo = true
                            let userId = urlString.replacingOccurrences(of: "user://", with: "")
                            linkUserId = userId
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
                        url.openSafari()
                    }
                    return .handled
                })
            
            NavigationLink(destination: UserInfoView(userId: linkUserId), isActive: $showUserInfo) {
                EmptyView()
            }

        } else {
            Text(content)
                .textSelection(.enabled)
                .font(.system(size: fontSize))
        }
    }
    
    private func createAttributedString() -> NSAttributedString? {
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
            color: #000000;
            margin: 0;
            padding: 0;
            word-wrap: break-word;
        }
        a {
            color: #007AFF;
            text-decoration: none;
        }
        a.user {
            color: #007AFF;
            font-weight: normal;
        }
        a.tag {
            color: #007AFF;
            font-weight: normal;
        }
        a.email {
            color: #007AFF;
            font-weight: normal;
        }
        a.phone {
            color: #007AFF;
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
        
        return try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        )
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
