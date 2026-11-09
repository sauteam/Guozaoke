import MarkdownUI
import SwiftUI
import RichText

/// 解析主题详情
struct RichTextView: View {
    let content: String
    var onLinkTap: ((URL) -> Void)?
    var onUserTap: ((String) -> Void)?
    var onTagTap: ((String) -> Void)?
    var onEmailTap: ((String) -> Void)?
    var onPhoneTap: ((String) -> Void)?

    @State private var showTopicInfo = false
    @State private var showUserInfo = false
    @State private var linkUserId = ""
    @State private var topicId = ""
    @State private var searchText = ""

    @State private var showSafari = false
    @State private var url: URL?
    @State private var formattedContent: String
    @State private var isContentProcessed: Bool
    @State private var contentHeight: CGFloat = 0
    
    private struct SafariState {
        var url: URL
        var isPresented: Bool
    }
    @State private var safariState: SafariState?
    @State private var showSearchView: Bool = false

    init(
        content: String,
        onLinkTap: ((URL) -> Void)? = nil,
        onUserTap: ((String) -> Void)? = nil,
        onTagTap: ((String) -> Void)? = nil,
        onEmailTap: ((String) -> Void)? = nil,
        onPhoneTap: ((String) -> Void)? = nil
    ) {
        self.content = content
        self.onLinkTap = onLinkTap
        self.onUserTap = onUserTap
        self.onTagTap = onTagTap
        self.onEmailTap = onEmailTap
        self.onPhoneTap = onPhoneTap
        let formatted = content.regexText(true)
        _formattedContent = State(initialValue: formatted)
        _isContentProcessed = State(initialValue: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                // 当富文本高度尚未测出时，展示带独立占位与安全间距的骨架，避免与下方“加入收藏”按钮粘连重叠
                if contentHeight == 0 {
                    RichTextPlaceholderView()
                        .padding(.bottom, 14)
                }
                
                RichText(html: formattedContent)
                    .lineHeight(170)
                    .colorScheme(.auto)
                    .imageRadius(0)
                    .fontType(.customName(titleFontName))
                    .foregroundColor(light: Color.primary, dark: Color.white)
                    .linkColor(light: Color.blue, dark: Color.blue)
                    .colorPreference(forceColor: .onlyLinks)
                    .customCSS(
                    """
                        body, p, span {
                           font-family: \(titleFontName); 
                           font-size: \(titleFontSize); 
                        }
                    """
                    )
                    .linkOpenType(.custom({ url in
                        handleLink(url)
                    }))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: RichTextHeightKey.self, value: geo.size.height)
                        }
                    )
            }
            .onPreferenceChange(RichTextHeightKey.self) { height in
                if height > 0 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.contentHeight = height
                    }
                }
            }
        }
        .onChange(of: content) { newContent in
            self.formattedContent = newContent.regexText(true)
        }
        .navigationDestination(isPresented: $showUserInfo, destination: {
            UserInfoView(userId: linkUserId)
        })
        .navigationDestination(isPresented: $showTopicInfo, destination: {
            PostDetailView(postId: topicId)
        })
        .navigationDestination(isPresented: $showSearchView, destination: {
            SearchListView(searchQuery: searchText)
        })
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
    }

    private func handleLink(_ url: URL) {
        logger("content url \(url)")
        switch url.scheme {
        case "https", "http":
            let urlString = url.absoluteString
            if urlString.contains("/u/") {
                if let range = urlString.range(of: "/u/") {
                    let afterU = String(urlString[range.upperBound...])
                    let cleanUserId = afterU.components(separatedBy: CharacterSet(charactersIn: "?#/ \t\n\"'")).first ?? ""
                    if !cleanUserId.isEmpty {
                        linkUserId = cleanUserId
                        logger("[at] RichText /u/ userId \(linkUserId)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showUserInfo = true
                        }
                        onUserTap?(cleanUserId)
                        return
                    }
                }
            } else if urlString.contains(APIService.baseUrlString), urlString.contains("/t/") {
                topicId = urlString.replacingOccurrences(of: APIService.baseUrlString, with: "")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTopicInfo = true
                }
            } else {
                self.url = url
                logger("content url \(url)")
                if urlString.contains(".png") || urlString.contains(".jpg") || urlString.contains(".webp") || urlString.contains(".gif") {
                    return
                }
                withAnimation {
                    safariState = SafariState(url: url, isPresented: true)
                }
                self.showSafari = true
            }
            onLinkTap?(url)
        case "mailto":
            let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            onEmailTap?(email)
            let phone = "mailto:"
            let phoneNumberFormatted = phone + email
            if let url = URL(string: phoneNumberFormatted) {
                UIApplication.shared.open(url)
            }
        case "tel":
            let number = url.absoluteString.replacingOccurrences(of: "tel:", with: "")
            onPhoneTap?(number)
            let phone = "tel:"
            let phoneNumberFormatted = phone + number
            if let url = URL(string: phoneNumberFormatted) {
                UIApplication.shared.open(url)
            }
        case "user":
            let userId = url.absoluteString.replacingOccurrences(of: "user://", with: "")
            if !userId.isEmpty {
                linkUserId = userId
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showUserInfo = true
                }
            }
            onUserTap?(userId)
        case "tag":
            let tag = url.absoluteString.replacingOccurrences(of: "tag://", with: "")
            if let decodedString = tag.removingPercentEncoding, decodedString.count > 0 {
                searchText = decodedString
            } else {
                searchText = tag
            }
            showSearchView.toggle()
            logger("[tag] 解码失败 \(searchText)")
            onTagTap?(tag)
        default:
            break
        }
    }

    private func processContent(_ content: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let processedContent = formatContent(content)
            DispatchQueue.main.async {
                self.formattedContent = processedContent
                self.isContentProcessed = true
            }
        }
    }

    private func formatContent(_ content: String) -> String {
        return content.regexText(true)
    }
}

// MARK: - RichText 段落骨架占位（避免正文渲染过程中的高度塌陷与菊花粘连）
struct RichTextPlaceholderView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(UIColor.secondarySystemFill))
                .frame(height: 16)
                .frame(maxWidth: .infinity)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(UIColor.secondarySystemFill))
                .frame(height: 16)
                .frame(maxWidth: .infinity)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(UIColor.secondarySystemFill))
                .frame(height: 16)
                .frame(width: 220)
        }
        .padding(.vertical, 8)
        .opacity(isAnimating ? 0.35 : 0.75)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 富文本高度偏好键（用于驱动真实排版占位与防遮挡）
struct RichTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - MarkdownTextView
struct MarkdownTextView: View {
    let content: String
    var body: some View {
        Markdown(content)
            .lineSpacing(6)
    }
}

struct CopyTextView: View {
    let content: String
    var body: some View {
        ScrollView {
            Text(formatContent(content))
                .font(.body)
                .contextMenu {
                    Button(action: {
                        content.copyToClipboard()
                    }) {
                        Text("拷贝内容")
                        SFSymbol.copy
                    }
                }
        }
    }

    private func formatContent(_ content: String) -> String {
        return content.regexText()
    }
}

// MARK: - AttributedTextView
struct AttributedTextView: UIViewRepresentable {
    let content: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.dataDetectorTypes = [.link]
        textView.backgroundColor = .clear
        textView.attributedText = convertHtmlToAttributedString(content)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = convertHtmlToAttributedString(content)
    }

    private func convertHtmlToAttributedString(_ html: String) -> NSAttributedString {
        guard let data = html.data(using: .utf8) else { return NSAttributedString() }
        return try! NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.html,
                                                 .characterEncoding: String.Encoding.utf8.rawValue],
                                       documentAttributes: nil)
    }
}
