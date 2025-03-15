import SwiftUI

struct HTMLContentView: View {
    let content: String
    let fontSize: CGFloat
    var showReport: Bool = false
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
    
    @State private var showSystemCopy = false
    @State private var showSystemCopySafari = false
    @State private var showSearchView = false
    @State private var text = ""
    @State private var searchText = ""


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
                        .font(.custom(titleFontName, size: fontSize))
                        .foregroundColor(Color.primary)
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in
                            handleLink(url)
                        })
                }
            } else {
                Text(content)
                    .textSelection(.enabled)
                    .font(.custom(titleFontName, size: fontSize))
                    .foregroundColor(Color.primary)
            }
        }
        .navigationDestination(isPresented: $showUserInfo) {
            UserInfoView(userId: linkUserId)
        }
        .navigationDestination(isPresented: $showTopicInfo) {
            PostDetailView(postId: topicId)
        }
        .navigationDestination(isPresented: $showSearchView) {
            SearchListView(searchQuery: searchText)
        }
        .dynamicContextMenu(userInfo: content, report: showReport, showSafari: $showSystemCopySafari, showSystemCopy: $showSystemCopy)
        .sheet(isPresented: $showSystemCopy) {
            CopyableTextSheet(isPresented: $showSystemCopy, text: $text)
                .presentationDetents([.height(200), .medium, .large])
                .presentationDragIndicator(.visible)
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
        .onAppear {
            text = content
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
    
    // MARK: - createAttributedString
    private func createAttributedString() {
        let isDarkMode = colorScheme == .dark
        let textColor = isDarkMode ? "FFFFFF" : "000000"
        let linkColor = "#007AFF"
        //isDarkMode ? "1E90FF" : "007AFF"
        
        let processedContent = content.regexText
        
        //font-family: -apple-system;
        let styledHTML = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body {
            font-family: \(titleFontName);
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
    
    // MARK: - createAttributedStringFromHTML
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
    
    // MARK: - handleLink
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
            if var urlString  = url.absoluteString.removingPercentEncoding {
                urlString = urlString.replacingOccurrences(of: "tag://", with: "")
                if urlString.count > 0 {
                    searchText = urlString
                    showSearchView.toggle()
                }
            }
            print("[tag] 解码失败 \(searchText)")
            onTagTap?(url.host ?? "")
        case "mailto":
            if let urlString = url.absoluteString.removingPercentEncoding {
                let email = urlString.replacingOccurrences(of: "mailto:", with: "")
                onEmailTap?(email)
                let phone = "mailto:"
                let phoneNumberFormatted = phone + email
                if let url = URL(string: phoneNumberFormatted) {
                    UIApplication.shared.open(url)
                }
            }
        case "tel":
            let number = url.absoluteString.replacingOccurrences(of: "tel:", with: "")
            onPhoneTap?(number)
            let phone = "tel:"
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

