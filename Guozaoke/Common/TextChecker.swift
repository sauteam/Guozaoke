import SwiftUI
import Foundation

struct PatternEnum {
    static let  link  = "(https?://[\\w\\d./-]+)"
    static let email  = "(\\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\\b)"
    static let atUser = "@([\\w\\-]+)"
    static let tagText = "#([^#]+)#"
    static let phone   = "(1[3-9]\\d{9})"
    static let number  = ""
    static let uid     = "uid=(\\d+)"
    static let base64Pattern = "([A-Za-z0-9+/=]{4,})"
}


extension String {
    
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
            let regex = try NSRegularExpression(pattern: PatternEnum.base64Pattern, options: [])
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
            print("[base64]无效的正则表达式: \(error.localizedDescription)")
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
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
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
            let regex = try! NSRegularExpression(pattern: "@\\w+", options: [])
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
        let linkRegex = try! NSRegularExpression(pattern: "https?://[a-zA-Z0-9./]+", options: [])
        let matches = linkRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        return !matches.isEmpty
    }
        
    var containsMention: Bool {
        let mentionRegex = try! NSRegularExpression(pattern: "@\\w+", options: [])
        let matches = mentionRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        return !matches.isEmpty
    }
    
    var containsTag: Bool {
        let tagRegex = try! NSRegularExpression(pattern: "#\\w+", options: [])
        let matches = tagRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        return !matches.isEmpty
    }
    
    var containsEmail: Bool {
        let emailRegex = try! NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", options: [])
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
