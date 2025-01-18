

//
//import SwiftUI
//import UIKit
//import Atributika
//
//// MARK: - Atributika SwiftUI 包装器
//struct AtributikaView: UIViewRepresentable {
//    let text: String
//    let onTap: ((String, URL?) -> Void)?
//    
//    private var baseAttributes: [NSAttributedString.Key: Any] = [:]
//    private var tagAttributes: [String: [NSAttributedString.Key: Any]] = [:]
//    
//    init(text: String, onTap: ((String, URL?) -> Void)? = nil) {
//        self.text = text
//        self.onTap = onTap
//    }
//    
//    // 创建 UIView
//    func makeUIView(context: Context) -> AtributikaLabel {
//        let label = AtributikaLabel()
//        label.numberOfLines = 0
//        label.onClick = { label, detection in
//            onTap?(detection.text, detection.url)
//        }
//        return label
//    }
//    
//    // 更新 UIView
//    func updateUIView(_ label: AtributikaLabel, context: Context) {
//        let attributedText = text
//            .styleAll(baseAttributes)
//            .styleLinks(tagAttributes["a"] ?? [:])
//            .style(tags: tagAttributes)
//        
//        label.attributedText = attributedText
//    }
//    
//    // 设置基础属性
//    func baseAttributes(_ attributes: [NSAttributedString.Key: Any]) -> AtributikaView {
//        var view = self
//        view.baseAttributes = attributes
//        return view
//    }
//    
//    // 设置标签属性
//    func tagAttributes(_ attributes: [String: [NSAttributedString.Key: Any]]) -> AtributikaView {
//        var view = self
//        view.tagAttributes = attributes
//        return view
//    }
//}
//
//// MARK: - 富文本视图
//struct RichTextView: View {
//    let content: String
//    @Environment(\.openURL) private var openURL
//    
//    // 基础样式
//    private let baseAttributes: [NSAttributedString.Key: Any] = [
//        .font: UIFont.systemFont(ofSize: 16),
//        .foregroundColor: UIColor.label
//    ]
//    
//    // 链接样式
//    private let linkAttributes: [NSAttributedString.Key: Any] = [
//        .font: UIFont.systemFont(ofSize: 16),
//        .foregroundColor: UIColor.systemBlue,
//        .underlineStyle: NSUnderlineStyle.single.rawValue
//    ]
//    
//    // 用户标签样式
//    private let userAttributes: [NSAttributedString.Key: Any] = [
//        .font: UIFont.systemFont(ofSize: 16),
//        .foregroundColor: UIColor.systemBlue
//    ]
//    
//    // 话题标签样式
//    private let tagAttributes: [NSAttributedString.Key: Any] = [
//        .font: UIFont.systemFont(ofSize: 16),
//        .foregroundColor: UIColor.systemBlue
//    ]
//    
//    var body: some View {
//        let processedText = content
//            .replacingOccurrences(
//                of: "@([\\w\\-]+)",
//                with: "<user>@$1</user>",
//                options: .regularExpression
//            )
//            .replacingOccurrences(
//                of: "#([^#]+)#",
//                with: "<tag>#$1#</tag>",
//                options: .regularExpression
//            )
//        
//        AtributikaView(text: processedText) { detection in
//            handleTap(detection)
//        }
//        .baseAttributes(baseAttributes)
//        .tagAttributes([
//            "a": linkAttributes,
//            "user": userAttributes,
//            "tag": tagAttributes
//        ])
//    }
//    
//    private func handleTap(_ detection: Detection?) {
//        guard let detection = detection else { return }
//        
//        switch detection.type {
//        case .tag(let tag):
//            if tag == "user" {
//                let username = String(detection.text.dropFirst())
//                handleUserTap(username)
//            } else if tag == "tag" {
//                let tag = String(detection.text.dropFirst().dropLast())
//                handleTagTap(tag)
//            }
//            
//        case .link(let url):
//            handleLinkTap(url)
//            
//        default:
//            break
//        }
//    }
//    
//    private func handleUserTap(_ username: String) {
//        //NavigationUtil.push(UserProfileView(username: username))
//    }
//    
//    private func handleTagTap(_ tag: String) {
//        //NavigationUtil.push(TagDetailView(tag: tag))
//    }
//    
//    private func handleLinkTap(_ url: URL) {
//        let urlString = url.absoluteString
//        
//        if urlString.contains("/member/") {
//            let userId = url.lastPathComponent
//            handleUserTap(userId)
//        } else if urlString.contains("/t/") {
//            let postId = url.lastPathComponent
//            //NavigationUtil.push(PostDetailView(postId: postId))
//        } else if urlString.hasSuffix(".jpg") || urlString.hasSuffix(".png") {
//            //NavigationUtil.push(ImagePreviewView(url: urlString))
//        } else {
//            openURL(url)
//        }
//    }
//}
