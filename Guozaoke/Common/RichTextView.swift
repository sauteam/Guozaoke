import SwiftUI
import Atributika
import AtributikaViews

// MARK: - 富文本视图
//struct RichTextView: UIViewRepresentable {
//    let content: String
//    var onLinkTap: ((URL) -> Void)?
//    var onUserTap: ((String) -> Void)?
//    var onTagTap: ((String) -> Void)?
//    
//    func makeUIView(context: Context) -> UILabel {
//        let label = UILabel()
//        label.numberOfLines = 0
//        label.isUserInteractionEnabled = true
//        
//        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
//        label.addGestureRecognizer(tap)
//        
//        return label
//    }
//    
//    func updateUIView(_ label: UILabel, context: Context) {
//        // 处理文本
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
//        // 基础样式
//        let baseAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 16),
//            .foregroundColor: UIColor.label
//        ]
//        
//        // 链接样式
//        let linkAttributes: [NSAttributedString.Key: Any] = [
//            .foregroundColor: UIColor.systemBlue,
//            .underlineStyle: NSUnderlineStyle.single.rawValue
//        ]
//        
//        // 用户名样式
//        let userAttributes: [NSAttributedString.Key: Any] = [
//            .foregroundColor: UIColor.systemBlue,
//            .font: UIFont.systemFont(ofSize: 16)
//        ]
//        
//        // 标签样式
//        let tagAttributes: [NSAttributedString.Key: Any] = [
//            .foregroundColor: UIColor.systemBlue,
//            .font: UIFont.systemFont(ofSize: 16)
//        ]
//        
//        // 创建富文本
//        let attributedText = processedText.attributedString(
//            with: baseAttributes,
//            linkAttributes: linkAttributes,
//            tagAttributes: [
//                "user": userAttributes,
//                "tag": tagAttributes
//            ]
//        )
//        
//        label.attributedText = attributedText
//        context.coordinator.label = label
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    // MARK: - Coordinator
//    class Coordinator: NSObject {
//        var parent: RichTextView
//        weak var label: UILabel?
//        
//        init(_ parent: RichTextView) {
//            self.parent = parent
//        }
//        
//        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
//            guard let label = label,
//                  let attributedText = label.attributedText else { return }
//            
//            let point = gesture.location(in: label)
//            
//            let textStorage = NSTextStorage(attributedString: attributedText)
//            let layoutManager = NSLayoutManager()
//            let textContainer = NSTextContainer(size: label.bounds.size)
//            
//            layoutManager.addTextContainer(textContainer)
//            textStorage.addLayoutManager(layoutManager)
//            
//            let index = layoutManager.characterIndex(
//                for: point,
//                in: textContainer,
//                fractionOfDistanceBetweenInsertionPoints: nil
//            )
//            
//            if index < textStorage.length {
//                let attributes = textStorage.attributes(at: index, effectiveRange: nil)
//                let range = textStorage.mutableString.paragraphRange(for: NSRange(location: index, length: 0))
//                let text = textStorage.mutableString.substring(with: range)
//                
//                // 处理链接点击
//                if let url = attributes[.link] as? URL {
//                    parent.onLinkTap?(url)
//                    return
//                }
//                
//                // 处理@用户点击
//                if text.hasPrefix("@") {
//                    let username = String(text.dropFirst())
//                    parent.onUserTap?(username)
//                    return
//                }
//                
//                // 处理#标签#点击
//                if text.hasPrefix("#") && text.hasSuffix("#") {
//                    let tag = String(text.dropFirst().dropLast())
//                    parent.onTagTap?(tag)
//                    return
//                }
//            }
//        }
//    }
//}
//
//// MARK: - String 扩展
//extension String {
//    func attributedString(
//        with baseAttributes: [NSAttributedString.Key: Any],
//        linkAttributes: [NSAttributedString.Key: Any],
//        tagAttributes: [String: [NSAttributedString.Key: Any]]
//    ) -> NSAttributedString {
//        let attributed = NSMutableAttributedString(string: self, attributes: baseAttributes)
//        
//        // 处理链接
//        if let regex = try? NSRegularExpression(pattern: "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>") {
//            let matches = regex.matches(in: self, range: NSRange(location: 0, length: self.count))
//            for match in matches.reversed() {
//                if let urlRange = Range(match.range(at: 1), in: self),
//                   let textRange = Range(match.range(at: 2), in: self) {
//                    let url = String(self[urlRange])
//                    let text = String(self[textRange])
//                    
//                    var attributes = linkAttributes
//                    attributes[.link] = URL(string: url)
//                    
//                    let attributedString = NSAttributedString(string: text, attributes: attributes)
//                    attributed.replaceCharacters(in: match.range, with: attributedString)
//                }
//            }
//        }
//        
//        // 处理标签
//        for (tag, attributes) in tagAttributes {
//            if let regex = try? NSRegularExpression(pattern: "<\(tag)>([^<]+)</\(tag)>") {
//                let matches = regex.matches(in: self, range: NSRange(location: 0, length: self.count))
//                for match in matches.reversed() {
//                    if let textRange = Range(match.range(at: 1), in: self) {
//                        let text = String(self[textRange])
//                        let attributedString = NSAttributedString(string: text, attributes: attributes)
//                        attributed.replaceCharacters(in: match.range, with: attributedString)
//                    }
//                }
//            }
//        }
//        
//        return attributed
//    }
//}


import SwiftUI
import UIKit

// MARK: - 富文本视图
struct RichTextView: UIViewRepresentable {
    let content: String
    var onLinkTap: ((URL) -> Void)?
    var onUserTap: ((String) -> Void)?
    var onTagTap: ((String) -> Void)?
    
    // MARK: - Coordinator
    class Coordinator {
        var parent: RichTextView
        weak var label: UILabel?
        
        init(parent: RichTextView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let label = label,
                  let attributedText = label.attributedText else { return }
            
            let point = gesture.location(in: label)
            
            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: label.bounds.size)
            
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            
            let index = layoutManager.characterIndex(
                for: point,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            
            if index < textStorage.length {
                let attributes = textStorage.attributes(at: index, effectiveRange: nil)
                let range = NSRange(location: index, length: 0)
                let text = attributedText.string as NSString
                let lineRange = text.paragraphRange(for: range)
                let lineText = text.substring(with: lineRange)
                
                // 处理链接点击
                if let url = attributes[.link] as? URL {
                    parent.onLinkTap?(url)
                    return
                }
                
                // 处理@用户点击
                if lineText.hasPrefix("@") {
                    let username = String(lineText.dropFirst())
                    parent.onUserTap?(username)
                    return
                }
                
                // 处理#标签#点击
                if lineText.hasPrefix("#") && lineText.hasSuffix("#") {
                    let tag = String(lineText.dropFirst().dropLast())
                    parent.onTagTap?(tag)
                    return
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = false
        label.lineBreakMode = .byWordWrapping
        label.isUserInteractionEnabled = true
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        label.addGestureRecognizer(tap)
        
        context.coordinator.label = label
        return label
    }
    
    func updateUIView(_ label: UILabel, context: Context) {
        // 处理文本
        let processedText = content
            .replacingOccurrences(
                of: "@([\\w\\-]+)",
                with: "<user>@$1</user>",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "#([^#]+)#",
                with: "<tag>#$1#</tag>",
                options: .regularExpression
            )
        
        // 创建富文本
        let attributedString = NSMutableAttributedString(string: processedText)
        
        // 基础样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.alignment = .left
        
        let wholeRange = NSRange(location: 0, length: attributedString.length)
        
        // 应用基础样式
        attributedString.addAttributes([
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ], range: wholeRange)
        
        // 处理用户名
        if let regex = try? NSRegularExpression(pattern: "<user>@([^<]+)</user>") {
            let matches = regex.matches(in: processedText, range: wholeRange)
            for match in matches.reversed() {
                let userRange = match.range(at: 0)
                if let range = Range(match.range(at: 1), in: processedText) {
                    let username = String(processedText[range])
                    let userText = "@\(username)"
                    
                    attributedString.replaceCharacters(in: userRange, with: userText)
                    attributedString.addAttributes([
                        .foregroundColor: UIColor.systemBlue,
                        .font: UIFont.systemFont(ofSize: 16)
                    ], range: NSRange(location: userRange.location, length: userText.count))
                }
            }
        }
        
        // 处理标签
        if let regex = try? NSRegularExpression(pattern: "<tag>#([^<]+)#</tag>") {
            let matches = regex.matches(in: processedText, range: wholeRange)
            for match in matches.reversed() {
                let tagRange = match.range(at: 0)
                if let range = Range(match.range(at: 1), in: processedText) {
                    let tag = String(processedText[range])
                    let tagText = "#\(tag)#"
                    
                    attributedString.replaceCharacters(in: tagRange, with: tagText)
                    attributedString.addAttributes([
                        .foregroundColor: UIColor.systemBlue,
                        .font: UIFont.systemFont(ofSize: 16)
                    ], range: NSRange(location: tagRange.location, length: tagText.count))
                }
            }
        }
        
        // 处理链接
        if let regex = try? NSRegularExpression(pattern: "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>") {
            let matches = regex.matches(in: processedText, range: wholeRange)
            for match in matches.reversed() {
                let linkRange = match.range(at: 0)
                if let urlRange = Range(match.range(at: 1), in: processedText),
                   let textRange = Range(match.range(at: 2), in: processedText) {
                    let url = String(processedText[urlRange])
                    let text = String(processedText[textRange])
                    
                    attributedString.replaceCharacters(in: linkRange, with: text)
                    attributedString.addAttributes([
                        .foregroundColor: UIColor.systemBlue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: URL(string: url) ?? ""
                    ], range: NSRange(location: linkRange.location, length: text.count))
                }
            }
        }
        
        label.attributedText = attributedString
        context.coordinator.label = label
    }
}

// MARK: - SwiftUI 包装视图
struct RichTextContainer: View {
    let content: String
    var onLinkTap: ((URL) -> Void)?
    var onUserTap: ((String) -> Void)?
    var onTagTap: ((String) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            RichTextView(
                content: content,
                onLinkTap: onLinkTap,
                onUserTap: onUserTap,
                onTagTap: onTagTap
            )
            .frame(maxWidth: geometry.size.width)
        }
    }
}

// MARK: - 使用示例
struct ContentView: View {
    var body: some View {
        ScrollView {
            RichTextContainer(
                content: """
                    Hello @user! 
                    Check out this #SwiftUI# tag.
                    Here's a <a href="https://example.com">link</a> 
                    这是一段很长的文本，用来测试自动换行。这是一段很长的文本，用来测试自动换行。
                    这是一段很长的文本，用来测试自动换行。这是一段很长的文本，用来测试自动换行。
                    """,
                onLinkTap: { url in
                    print("Link tapped: \(url)")
                },
                onUserTap: { username in
                    print("User tapped: \(username)")
                },
                onTagTap: { tag in
                    print("Tag tapped: \(tag)")
                }
            )
            .padding()
        }
    }
}
