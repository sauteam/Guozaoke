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
    @State private var showSafari = false
    @State private var url: URL?
    @State private var attributedContent: AttributedString?
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase 
    
    // 缓存不同主题下的富文本
    @State private var lightModeContent: AttributedString?
    @State private var darkModeContent: AttributedString?
    
    private struct SafariState {
        var url: URL
        var isPresented: Bool
    }
    @State private var safariState: SafariState?

    
    var body: some View {
        Group {
            if let attributedString = attributedContent {
                ScrollView {
                    Text(attributedString)
                        .font(.system(size: fontSize))
                        .foregroundColor(Color.primary)
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in
                            handleLink(url)
                        })
                        .navigationDestination(isPresented: $showUserInfo) {
                            UserInfoView(userId: linkUserId)
                        }
                        .navigationDestination(isPresented: $showTopicInfo) {
                            PostDetailView(postId: topicId)
                        }
                }
                
                .sheet(
                    isPresented: Binding(
                        get: { safariState != nil },
                        set: { if !$0 { safariState = nil } }
                    )
                ) {
                    if let state = safariState {
                        SafariView(url: state.url)
                    }
                }
            } else {
                Text(content)
                    .textSelection(.enabled)
                    .font(.system(size: fontSize))
                    .foregroundColor(Color.primary)
            }
        }
        .onAppear {
            createAttributedString()
        }
        .onChange(of: colorScheme) { newValue in
            // 切换主题时使用缓存的内容
            attributedContent = newValue == .dark ? darkModeContent : lightModeContent
            if attributedContent == nil {
                createAttributedString()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // 从后台恢复时重新加载内容
            if newPhase == .active {
                createAttributedString()
            }
        }
    }
    
    private func createAttributedString() {
        let isDarkMode = colorScheme == .dark
        let textColor = isDarkMode ? "FFFFFF" : "000000"
        let linkColor = "#007AFF"
        //isDarkMode ? "1E90FF" : "007AFF"
        
        var processedContent = content
            
        let userPattern = "uid=(\\d+)"
        if let regex = try? NSRegularExpression(pattern: userPattern) {
            let range = NSRange(processedContent.startIndex..., in: processedContent)
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                range: range,
                withTemplate: "<a href=\"user://$1\">$0</a>"
            )
        }
        
        if !content.contains("<a") {
            let urlPattern = "(https?://[\\w\\d./-]+)"
            processedContent = processedContent.replacingOccurrences(
                of: urlPattern,
                with: "<a href=\"$1\">$1</a>",
                options: .regularExpression
            )
            
            let emailPattern = "([\\w\\.-]+@[\\w\\.-]+\\.[\\w-]{2,})"
            processedContent = processedContent.replacingOccurrences(
                of: emailPattern,
                with: "<a href=\"mailto:$1\" class=\"email\">$1</a>",
                options: .regularExpression
            )
            
            let phonePattern = "(1[3-9]\\d{9})"
            processedContent = processedContent.replacingOccurrences(
                of: phonePattern,
                with: "<a href=\"tel:$1\" class=\"phone\">$1</a>",
                options: .regularExpression
            )
        }
        
        processedContent = processedContent.replacingOccurrences(
            of: "@([\\w\\-]+)",
            with: "<a href=\"user://$1\" class=\"user\">@$1</a>",
            options: .regularExpression
        )
        
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

        Task {
            do {
                let attributedString = try await createAttributedStringFromHTML(styledHTML)
                await MainActor.run {
                    // 缓存不同主题的内容
                    if isDarkMode {
                        darkModeContent = attributedString
                    } else {
                        lightModeContent = attributedString
                    }
                    attributedContent = attributedString
                }
            } catch {
                print("Error creating attributed string: \(error)")
                await MainActor.run {
                    attributedContent = nil
                }
            }
        }
    }
    
    private func createAttributedStringFromHTML(_ html: String) async throws -> AttributedString {
        try await withCheckedThrowingContinuation { continuation in
            guard let data = html.data(using: .utf8) else {
                continuation.resume(throwing: NSError(domain: "", code: -1))
                return
            }
            
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            do {
                let nsAttributedString = try NSAttributedString(
                    data: data,
                    options: options,
                    documentAttributes: nil
                )
                let attributedString = AttributedString(nsAttributedString)
                continuation.resume(returning: attributedString)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func handleLink(_ url: URL) -> OpenURLAction.Result {
        switch url.scheme {
        case "user":
            if let urlString = url.absoluteString.removingPercentEncoding {
                let userId = urlString.replacingOccurrences(of: "user://", with: "")
                log("[at] userId \(userId)")
                if !userId.isEmpty {
                    linkUserId = userId
                    log("linkUserId \(linkUserId)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showUserInfo = true
                    }
                }
                onUserTap?(userId)
            }
        case "tag":
            onTagTap?(url.host ?? "")
        case "mailto":
            if let urlString = url.absoluteString.removingPercentEncoding {
                let email = urlString.replacingOccurrences(of: "mailto:", with: "")
                onEmailTap?(email)
                let phone = "mailto://"
                let phoneNumberFormatted = phone + email
                if let url = URL(string: phoneNumberFormatted) {
                    UIApplication.shared.open(url)
                }
            }
        case "tel":
            let number = url.absoluteString.replacingOccurrences(of: "tel:", with: "")
            onPhoneTap?(number)
            let phone = "tel://"
            let phoneNumberFormatted = phone + number
            if let url = URL(string: phoneNumberFormatted) {
                UIApplication.shared.open(url)
            }
        default:
            onLinkTap?(url)
            let urlString = url.absoluteString
            log("[urlString] urlString \(urlString)")
            if urlString.contains(APIService.baseUrlString), urlString.contains("/t/") {
                topicId = urlString.replacingOccurrences(of: APIService.baseUrlString, with: "")
                log("topic \(topicId)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTopicInfo = true
                }
            } else {
                self.url = url
                withAnimation {
                    safariState = SafariState(url: url, isPresented: true)
                }
                showSafari = true
            }
        }
        return .handled
    }
}


////2025.02.15
//struct HTMLContentView: View {
//    let content: String
//    let fontSize: CGFloat
//    var onLinkTap: ((URL) -> Void)?
//    var onUserTap: ((String) -> Void)?
//    var onTagTap: ((String) -> Void)?
//    var onEmailTap: ((String) -> Void)?
//    var onPhoneTap: ((String) -> Void)?
//    
//    @State private var showTopicInfo = false
//    @State private var showUserInfo = false
//    @State private var linkUserId = ""
//    @State private var topicId = ""
//    @State private var showSafari = false
//    @State private var url: URL?
//    @State private var attributedContent: AttributedString?
//    @Environment(\.colorScheme) var colorScheme
//    @State private var lastColorScheme: ColorScheme?
//    
//    init(
//        content: String,
//        fontSize: CGFloat = 16,
//        onLinkTap: ((URL) -> Void)? = nil,
//        onUserTap: ((String) -> Void)? = nil,
//        onTagTap: ((String) -> Void)? = nil,
//        onEmailTap: ((String) -> Void)? = nil,
//        onPhoneTap: ((String) -> Void)? = nil
//    ) {
//        self.content = content
//        self.fontSize = fontSize
//        self.onLinkTap = onLinkTap
//        self.onUserTap = onUserTap
//        self.onTagTap = onTagTap
//        self.onEmailTap = onEmailTap
//        self.onPhoneTap = onPhoneTap
//    }
//    
//    var body: some View {
//        Group {
//            if let attributedString = attributedContent {
//                ScrollView {
//                    Text(attributedString)
//                        .font(.system(size: fontSize))
//                        .foregroundColor(Color.primary)
//                        .textSelection(.enabled)
//                        .environment(\.openURL, OpenURLAction { url in
//                            handleLink(url)
//                        })
//                        .navigationDestination(isPresented: $showUserInfo) {
//                            UserInfoView(userId: linkUserId)
//                        }
//                        .navigationDestination(isPresented: $showTopicInfo) {
//                            PostDetailView(postId: topicId)
//                        }
//                }
//                .sheet(isPresented: $showSafari) {
//                    if let url = url {
//                        SafariView(url: url)
//                    }
//                }
//                .onAppear {
//                    if attributedContent == nil || lastColorScheme != colorScheme {
//                        lastColorScheme = colorScheme
//                        createAttributedString()
//                    }
//                }
//            } else {
//                Text(content)
//                    .textSelection(.enabled)
//                    .font(.system(size: fontSize))
//                    .foregroundColor(Color.primary)
//                    .onAppear {
//                        if attributedContent == nil || lastColorScheme != colorScheme {
//                            lastColorScheme = colorScheme
//                            createAttributedString()
//                        }
//                    }
//            }
//        }
//        .onChange(of: colorScheme) { _ in
//            if lastColorScheme != colorScheme {
//                lastColorScheme = colorScheme
//                createAttributedString()
//            }
//        }
//    }
//    
//    private func createAttributedString() {
//        let isDarkMode = colorScheme == .dark
//        let textColor = isDarkMode ? "#FFFFFF" : "#000000"
//        let linkColor = isDarkMode ? "#1E90FF" : "#007AFF"
//        
//        var processedContent = content
//        // 处理用户链接
//        let userPattern = "uid=(\\d+)"
//        if let regex = try? NSRegularExpression(pattern: userPattern) {
//            let range = NSRange(processedContent.startIndex..., in: processedContent)
//            processedContent = regex.stringByReplacingMatches(
//                in: processedContent,
//                range: range,
//                withTemplate: "<a href=\"user://$1\">$0</a>"
//            )
//        }
//        
//        // 处理HTML格式链接
//        if !content.contains("<a") {
//            let urlPattern = "(https?://[\\w\\d./-]+)"
//            processedContent = processedContent.replacingOccurrences(
//                of: urlPattern,
//                with: "<a href=\"$1\">$1</a>",
//                options: .regularExpression
//            )
//            
//            let emailPattern = "([\\w\\.-]+@[\\w\\.-]+\\.[\\w-]{2,})"
//            processedContent = processedContent.replacingOccurrences(
//                of: emailPattern,
//                with: "<a href=\"mailto:$1\" class=\"email\">$1</a>",
//                options: .regularExpression
//            )
//            
//            let phonePattern = "(1[3-9]\\d{9})"
//            processedContent = processedContent.replacingOccurrences(
//                of: phonePattern,
//                with: "<a href=\"tel:$1\" class=\"phone\">$1</a>",
//                options: .regularExpression
//            )
//        }
//        
//        // 处理 @用户
//        processedContent = processedContent.replacingOccurrences(
//            of: "@([\\w\\-]+)",
//            with: "<a href=\"user://$1\" class=\"user\">@$1</a>",
//            options: .regularExpression
//        )
//        
//        // 处理 #标签#
//        processedContent = processedContent.replacingOccurrences(
//            of: "#([^#]+)#",
//            with: "<a href=\"tag://$1\" class=\"tag\">#$1#</a>",
//            options: .regularExpression
//        )
//        
//        let styledHTML = """
//        <html>
//        <head>
//        <meta name="viewport" content="width=device-width, initial-scale=1">
//        <style>
//        body {
//            font-family: -apple-system;
//            font-size: \(fontSize)px;
//            line-height: 1.5;
//            color: \(textColor);
//            margin: 0;
//            padding: 0;
//            word-wrap: break-word;
//        }
//        a {
//            color: \(linkColor);
//            text-decoration: none;
//        }
//        a.user {
//            color: \(linkColor);
//            font-weight: normal;
//        }
//        a.tag {
//            color: \(linkColor);
//            font-weight: normal;
//        }
//        a.email {
//            color: \(linkColor);
//            font-weight: normal;
//        }
//        a.phone {
//            color: \(linkColor);
//            font-weight: normal;
//        }
//        img {
//            max-width: 100%;
//            height: auto;
//            border-radius: 4px;
//        }
//        p {
//            margin: 8px 0;
//        }
//        </style>
//        </head>
//        <body>
//        \(processedContent)
//        </body>
//        </html>
//        """
//        
//        DispatchQueue.global(qos: .userInitiated).async {
//            guard let data = styledHTML.data(using: .utf8) else { return }
//            
//            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
//                .documentType: NSAttributedString.DocumentType.html,
//                .characterEncoding: String.Encoding.utf8.rawValue
//            ]
//            
//            do {
//                let nsAttributedString = try NSAttributedString(
//                    data: data,
//                    options: options,
//                    documentAttributes: nil
//                )
//                let attributedString = AttributedString(nsAttributedString)
//                
//                DispatchQueue.main.async {
//                    self.attributedContent = attributedString
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    print("Error creating attributed string: \(error)")
//                    self.attributedContent = nil
//                }
//            }
//        }
//    }
//    
//    private func handleLink(_ url: URL) -> OpenURLAction.Result {
//        switch url.scheme {
//        case "user":
//            if let urlString = url.absoluteString.removingPercentEncoding {
//                let userId = urlString.replacingOccurrences(of: "user://", with: "")
//                log("[at] userId \(userId)")
//                if !userId.isEmpty {
//                    linkUserId = userId
//                    log("linkUserId \(linkUserId)")
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                        showUserInfo = true
//                    }
//                }
//                onUserTap?(userId)
//            }
//        case "tag":
//            onTagTap?(url.host ?? "")
//        case "mailto":
//            onEmailTap?(url.absoluteString.replacingOccurrences(of: "mailto:", with: ""))
//        case "tel":
//            onPhoneTap?(url.absoluteString.replacingOccurrences(of: "tel:", with: ""))
//        default:
//            onLinkTap?(url)
//            let urlString = url.absoluteString
//            log("[urlString] urlString \(urlString)")
//            if urlString.contains(APIService.baseUrlString), urlString.contains("/t/") {
//                topicId = urlString.replacingOccurrences(of: APIService.baseUrlString, with: "")
//                log("topic \(topicId)")
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    showTopicInfo = true
//                }
//            } else {
//                self.url = url
//                showSafari = true
//            }
//        }
//        return .handled
//    }
//}
