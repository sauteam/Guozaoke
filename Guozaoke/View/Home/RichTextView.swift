import MarkdownUI
import SwiftUI
import RichText

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

    @State private var showSafari = false
    @State private var url: URL?
    @State private var formattedContent: String = ""
    @State private var isContentProcessed = false

    var body: some View {
        NavigationStack {
            if isContentProcessed {
                RichText(html: formattedContent)
                    .lineHeight(170)
                    .colorScheme(.auto)
                    .imageRadius(0)
                    .fontType(.system)
                    .foregroundColor(light: Color.primary, dark: Color.white)
                    .linkColor(light: Color.blue, dark: Color.blue)
                    .colorPreference(forceColor: .onlyLinks)
                    .customCSS("")
                    .linkOpenType(.custom({ url in
                        handleLink(url)
                    }))
                    .placeholder {
                        ProgressView()
                    }
                    .transition(.easeOut)
                    .onOpenURL { url in
                        handleLink(url)
                    }
                
                    .navigationDestination(isPresented: $showUserInfo) {
                        UserInfoView(userId: linkUserId)
                    }
                
                    .navigationDestination(isPresented: $showTopicInfo) {
                        PostDetailView(postId: topicId)
                    }
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
        .sheet(isPresented: $showSafari) {
            if let url = url {
                SafariView(url: url)
            }
        }
    }

    private func handleLink(_ url: URL) {
        self.url = url
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
                if urlString.contains(".png") || urlString.contains(".jpg") || urlString.contains(".webp") || urlString.contains(".gif") {
                    return
                }
                self.showSafari = true
            }
            onLinkTap?(url)
        case "mailto":
            let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            onEmailTap?(email)
        case "tel":
            let phone = url.absoluteString.replacingOccurrences(of: "tel:", with: "")
            onPhoneTap?(phone)
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
        log("topicContent \n \(content)")
        // 转换 @用户
        processedContent = processedContent.replacingOccurrences(
            of: "@(\\w+)",
            with: "<a href=\"user://$1\">@$1</a>",
            options: .regularExpression
        )

        // 转换 #标签#
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

