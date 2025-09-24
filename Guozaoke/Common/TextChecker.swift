import SwiftUI
import Foundation

enum PatternEnum: String {
    case link    = "(https?://[\\w\\d./-]+)"
    case email   = "(\\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\\b)"
    case atUser  = #"(?<!mailto:|\w)@(\w+)"#
    case tagText = "#([^#]+)#"
    case phoneNumber   = "(1[3-9]\\d{9})"
    case uid           = "uid=(\\d+)"
    case base64Pattern = "([A-Za-z0-9+/=]{4,})"
    
    var regText: String {
        return self.rawValue
    }
    
    var withText: String {
        switch self {
        case .link:
            return "<a href=\"$1\">$1</a>"
        case .email:
            return "<a href=\"mailto:$1\" class=\"email\">$1</a>"
        case .atUser:
            return "<a href=\"user://$1\" class=\"user\">@$1</a>"
        case .tagText:
            return "<a href=\"tag://$1\" class=\"tag\">#$1#</a>"
        case .phoneNumber:
            return "<a href=\"tel:$1\" class=\"phone\">$1</a>"
        case .uid:
            return "<a href=\"user://$1\">$0</a>"
        case .base64Pattern:
            return ""
        }
    }
}


extension String {
    
    /// 文本内容正则处理
    func regexText(_ richText: Bool? = false) -> String {
        var processedContent = self
        if let regex = try? NSRegularExpression(pattern: PatternEnum.uid.regText) {
            let range = NSRange(processedContent.startIndex..., in: processedContent)
            processedContent = regex.stringByReplacingMatches(
                in: processedContent,
                range: range,
                withTemplate: PatternEnum.uid.withText
            )
        }
        
        if !processedContent.contains("<a") {
            if richText == false {
                processedContent = processedContent.replacingOccurrences(
                    of: PatternEnum.link.regText,
                    with: PatternEnum.link.withText,
                    options: .regularExpression
                )
            }
            
            processedContent = processedContent.replacingOccurrences(
                of: PatternEnum.phoneNumber.regText,
                with: PatternEnum.phoneNumber.withText,
                options: .regularExpression
            )
        }
        processedContent = processedContent.replacingOccurrences(
            of: PatternEnum.atUser.regText,
            with: PatternEnum.atUser.withText,
            options: .regularExpression
        )

        if richText == false {
            processedContent = processedContent.replacingOccurrences(
                of: PatternEnum.email.regText,
                with: PatternEnum.email.withText,
                options: .regularExpression
            )
        }
        
        processedContent = processedContent.replacingOccurrences(
            of: PatternEnum.tagText.regText,
            with: PatternEnum.tagText.withText,
            options: .regularExpression
        )
        
        return processedContent
    }
    
    var base64Encoded: String? {
        return self.data(using: .utf8)?.base64EncodedString()
    }
    
    var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
        
    var base64TextList: [String] {
        var decodedStrings = [String]()
        do {
            let regex = try NSRegularExpression(pattern: PatternEnum.base64Pattern.regText, options: [])
            let nsString = self as NSString
            let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in results {
                if let range = Range(match.range, in: self) {
                    let base64String = String(self[range])
                    if let decodedString = base64String.base64Decoded {
                        decodedStrings.append(decodedString)
                    }
                }
            }
        } catch let error {
            logger("[base64]无效的正则表达式: \(error.localizedDescription)")
        }
        return decodedStrings
    }
        
    var extractURLs: [URL] {
        var urls: [URL] = []
        if containsLink {
            let types = NSTextCheckingResult.CheckingType.link.rawValue
            guard let detector = try? NSDataDetector(types: types) else {
                return urls
            }
            let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
            
            for match in matches {
                if match.resultType == .link, let url = match.url {
                    urls.append(url)
                }
            }
        }
        return urls
    }
    
    var extractEmails: [String] {
        var emails: [String] = []
        let emailPattern = PatternEnum.email.regText
        guard let regex = try? NSRegularExpression(pattern: emailPattern, options: []) else {
            return emails
        }
        let textRange = NSRange(location: 0, length: self.utf16.count)
        let matches = regex.matches(in: self, options: [], range: textRange)
        for match in matches {
            if let emailRange = Range(match.range, in: self) {
                let email = String(self[emailRange])
                emails.append(email)
            }
        }
        return emails
    }
    
    var extractUserTags: [String] {
        var tags: [String] = []
        if containsMention {
            let regex = try! NSRegularExpression(pattern: PatternEnum.atUser.regText, options: [])
            let textRange = NSRange(location: 0, length: self.utf16.count)
            let matches = regex.matches(in: self, options: [], range: textRange)
            for match in matches {
                if let tagRange = Range(match.range, in: self) {
                    let tag = String(self[tagRange])
                    tags.append(tag)
                }
            }
        }
        return tags
    }
    
    var userTagString: String {
        return extractUserTags.joined(separator: " ")
    }

    var containsLink: Bool {
        let linkRegex = try! NSRegularExpression(pattern: PatternEnum.link.regText, options: [])
        let matches = linkRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        return !matches.isEmpty
    }
        
    var containsMention: Bool {
        let mentionRegex = try! NSRegularExpression(pattern: PatternEnum.atUser.regText, options: [])
        let matches = mentionRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        return !matches.isEmpty
    }
    
    var containsTag: Bool {
        let tagRegex = try! NSRegularExpression(pattern: PatternEnum.tagText.regText, options: [])
        let matches = tagRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        return !matches.isEmpty
    }
    
    var containsEmail: Bool {
        let emailRegex = try! NSRegularExpression(pattern: PatternEnum.email.regText, options: [])
        let matches = emailRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        return !matches.isEmpty
    }

    
    var checkText: (hasLink: Bool, hasMention: Bool, hasTag: Bool, hasEmail: Bool) {
        let hasLink    = self.containsLink
        let hasMention = self.containsMention
        let hasTag     = self.containsTag
        let hasEmail   = self.containsEmail
        return (hasLink, hasMention, hasTag, hasEmail)
    }

}

struct TextChecker {}
