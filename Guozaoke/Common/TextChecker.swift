import SwiftUI
import Foundation

struct TextChecker {
    static func containsLink(_ text: String) -> Bool {
        let linkRegex = try! NSRegularExpression(pattern: "https?://[a-zA-Z0-9./]+", options: [])
        let matches = linkRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        return !matches.isEmpty
    }
    
    static func containsMention(_ text: String) -> Bool {
        let mentionRegex = try! NSRegularExpression(pattern: "@\\w+", options: [])
        let matches = mentionRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        return !matches.isEmpty
    }
    
    static func containsTag(_ text: String) -> Bool {
        let tagRegex = try! NSRegularExpression(pattern: "#\\w+", options: [])
        let matches = tagRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        return !matches.isEmpty
    }
    
    static func containsEmail(_ text: String) -> Bool {
        let emailRegex = try! NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", options: [])
        let matches = emailRegex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        return !matches.isEmpty
    }
    
    static func checkText(_ text: String) -> (hasLink: Bool, hasMention: Bool, hasTag: Bool, hasEmail: Bool) {
        let hasLink    = containsLink(text)
        let hasMention = containsMention(text)
        let hasTag     = containsTag(text)
        let hasEmail   = containsEmail(text)
        return (hasLink, hasMention, hasTag, hasEmail)
    }
}
