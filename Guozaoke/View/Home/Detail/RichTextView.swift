import MarkdownUI
import SwiftUI
import RichText

struct RichTextView: View {
    let content: String
    //let fontSize: CGFloat = UserDefaultsKeys.fontSize16
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
    @State private var formattedContent: String = ""
    @State private var isContentProcessed = false
    
    private struct SafariState {
        var url: URL
        var isPresented: Bool
    }
    @State private var safariState: SafariState?
    @State private var showSearchView: Bool = false

    var body: some View {
        NavigationStack {
            if isContentProcessed {
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
                    .placeholder {
                        ProgressView()
                    }
                    .transition(.easeOut)
//                    .onOpenURL { url in
//                        handleLink(url)
//                    }
                
                    .onAppear {
                        processContent(content)
                    }
            } else {
                ProgressView()
                    .onAppear {
                        processContent(content)
                    }
            }
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
        log("content url \(url)")
        switch url.scheme {
        case "https", "http":
            let urlString = url.absoluteString
            if urlString.contains(APIService.baseUrlString), urlString.contains("/t/") {
                topicId = urlString.replacingOccurrences(of: APIService.baseUrlString, with: "")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTopicInfo = true
                }
            } else {
                self.url = url
                log("content url \(url)")
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
            let phone = "mailto://"
            let phoneNumberFormatted = phone + email
            if let url = URL(string: phoneNumberFormatted) {
                UIApplication.shared.open(url)
            }
        case "tel":
            let number = url.absoluteString.replacingOccurrences(of: "tel:", with: "")
            onPhoneTap?(number)
            let phone = "tel://"
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
            print("[tag] 解码失败 \(searchText)")
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
        var processedContent = content
        processedContent = processedContent.replacingOccurrences(
            of: "@(\\w+)",
            with: "<a href=\"user://$1\">@$1</a>",
            options: .regularExpression
        )

        processedContent = processedContent.replacingOccurrences(
            of: "#([^#]+)#",
            with: "<a href=\"tag://$1\">#$1#</a>",
            options: .regularExpression
        )
                
        return processedContent
    }
}


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
        var processedContent = content
        // 转换 @用户
        processedContent = processedContent.replacingOccurrences(
            of: PatternEnum.atUser,
            with: "<a href=\"user://$1\">@$1</a>",
            options: .regularExpression
        )
        
        let emailPattern = PatternEnum.email
        processedContent = processedContent.replacingOccurrences(
            of: emailPattern,
            with: "<a href=\"mailto:$1\" class=\"email\">$1</a>",
            options: .regularExpression
        )
        
        let phonePattern = PatternEnum.phone
        processedContent = processedContent.replacingOccurrences(
            of: phonePattern,
            with: "<a href=\"tel:$1\" class=\"phone\">$1</a>",
            options: .regularExpression
        )

        // 转换 #标签#
        processedContent = processedContent.replacingOccurrences(
            of: PatternEnum.tagText,
            with: "<a href=\"tag://$1\">#$1#</a>",
            options: .regularExpression
        )

        return processedContent
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

