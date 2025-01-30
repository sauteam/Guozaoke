//
//  Extentions.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import Foundation
import SwiftUI
import CryptoKit

let themeColor = UIColor(hex: 303030)


extension String {
    
    static let `default`: String = ""
    public static let empty = `default`
    
    
    var isBlank: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var int: Int {
        return Int(self) ?? 0
    }
    

    func segment(separatedBy separator: String, at index: Int = .last) -> String {
        guard self.contains(separator) else { return self }
        let segments = components(separatedBy: separator)
        let realIndex = min(index, segments.count - 1)
        return String(segments[realIndex])
    }

    func segment(from first: String) -> String {
        if var firstIndex = self.index(of: first) {
            firstIndex = self.index(firstIndex, offsetBy: 1)
            let subString = self[firstIndex..<self.endIndex]
            return String(subString)
        }
        return self
    }


    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func remove(_ seg: String) -> String {
        return replacingOccurrences(of: seg, with: "")
    }

    func notEmpty()-> Bool {
        return !isEmpty
    }
    
    func replace(segs: String..., with replacement: String) -> String {
        var result: String = self
        for seg in segs {
            guard result.contains(seg) else { continue }
            result = result.replacingOccurrences(of: seg, with: replacement)
        }
        return result
    }

    func extractDigits() -> String {
        guard !self.isEmpty else { return .default }
        return self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    func htmlUserId() -> String? {
        if let result = self.components(separatedBy: "user://").last {
            return result
        }
        return self
    }

    func urlEncoded()-> String {
        let result = self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return result ?? .empty
    }

    func urlDecode()-> String {
        self.removingPercentEncoding ?? .empty
    }

    /// 复制文本到剪贴板
    public func copyToClipboard() {
        guard self.count > 0 else {
            return
        }

        UIPasteboard.general.string = self
    }
    
    var md5: String {
        let computed = Insecure.MD5.hash(data: self.data(using: .utf8)!)
        return computed.map { String(format: "%02hhx", $0) }
            .joined()
    }
}

extension Optional where Wrapped == String {
    var isEmpty: Bool {
        return self?.isEmpty ?? true
    }

    var notEmpty: Bool {
        !isEmpty
    }

    var safe: String {
        return ifEmpty(.empty)
    }

    func ifEmpty(_ defaultValue: String) -> String {
        return isEmpty ? defaultValue : self!
    }
}

extension Binding {
    var raw: Value {
        return self.wrappedValue
    }

    //    subscript<T>(_ key: Int) -> Binding<T> where Value == [T] {
    //        .init(get: {
    //            self.wrappedValue[key]
    //        },
    //              set: {
    //            self.wrappedValue[key] = $0
    //        })
    //    }

    subscript<K, V>(_ key: K) -> Binding<V> where Value == [K:V], K: Hashable {
        .init(get: {
            self.wrappedValue[key]!
        },
              set: {
            self.wrappedValue[key] = $0
        })
    }
}

extension Int {
    static let `default`: Int = 0
    static let first: Int = 0
    static let last: Int = Int.max

    var string: String {
        return String(self)
    }
}

extension Collection where Indices.Iterator.Element == Index {
    public subscript(safe index: Index) -> Iterator.Element? {
        return (startIndex <= index && index < endIndex) ? self[index] : nil
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}


extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
              let range = self[startIndex...]
                .range(of: string, options: options) {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
            index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

extension Dictionary {
    mutating func merge(_ dict: [Key: Value]?){
        guard let dict = dict else {
            return
        }

        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}

extension Data {
    var string: String {
        return String(decoding: self, as: UTF8.self)
    }
}

extension Date {
    static var currentTimeStamp: Int64{
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}


extension UIFont {
    static func prfered(_ font: Font) -> UIFont {
        let uiFont: UIFont

        switch font {
            case .largeTitle:
                uiFont = UIFont.preferredFont(forTextStyle: .largeTitle)
            case .title:
                uiFont = UIFont.preferredFont(forTextStyle: .title1)
            case .title2:
                uiFont = UIFont.preferredFont(forTextStyle: .title2)
            case .title3:
                uiFont = UIFont.preferredFont(forTextStyle: .title3)
            case .headline:
                uiFont = UIFont.preferredFont(forTextStyle: .headline)
            case .subheadline:
                uiFont = UIFont.preferredFont(forTextStyle: .subheadline)
            case .callout:
                uiFont = UIFont.preferredFont(forTextStyle: .callout)
            case .caption:
                uiFont = UIFont.preferredFont(forTextStyle: .caption1)
            case .caption2:
                uiFont = UIFont.preferredFont(forTextStyle: .caption2)
            case .footnote:
                uiFont = UIFont.preferredFont(forTextStyle: .footnote)
            case .body:
                fallthrough
            default:
                uiFont = UIFont.preferredFont(forTextStyle: .body)
        }

        return uiFont
    }
}


extension Bundle {
    static func readString(name: String?, type: String?) -> String? {
        var result: String? = nil
        if let filepath = Bundle.main.path(forResource: name, ofType: type) {
            do {
                result = try String(contentsOfFile: filepath)
                log("----------> local resource: \(result ?? "") <------------")
            } catch {
                // contents could not be loaded
            }
        } else {
            // example.txt not found!
            log("----------> local resource \(name ?? ""): not found <------------")
        }
        return result
    }

}


extension URL {
    func params() -> [String : String] {
        var dict = [String : String]()

        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    dict[item.name] = item.value!
                }
            }
            return dict
        } else {
            return [ : ]
        }
    }
}


struct DeviceUtils {
    /// 获取安全区域的高度
    static func getSafeAreaInsets() -> UIEdgeInsets {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return .zero
        }
        return window.safeAreaInsets
    }

    /// 判断是否为刘海屏
    static func isNotchScreen() -> Bool {
        let safeAreaInsets = getSafeAreaInsets()
        return safeAreaInsets.top > 20 // 通常非刘海屏顶部 inset 为 20
    }
}


extension Color {
    /// 黑色 白色
    static let contentTextColor = Color("contentTextColor")

    private init(_ hex: Int, a: CGFloat = 1.0) {
        self.init(UIColor(hex: hex, alpha: a))
    }
    
    public static func hex(_ hex: Int, alpha: CGFloat = 1.0) -> Color {
        return Color(hex, a: alpha)
    }
    
    public static func shape(_ hex: Int, alpha: CGFloat = 1.0) -> some View {
        return Self.hex(hex, alpha: alpha).frame(width: .infinity)
    }
    
    public func shape() -> some View {
        self.frame(width: .infinity)
    }
    
    public static let border = hex(0xE8E8E8, alpha: 0.8)
    static let lightGray = hex(0xF5F5F5)
    static let almostClear = hex(0xFFFFFF, alpha: 0.000001)
    static let debugColor = hex(0xFF0000, alpha: 0.1)
//    static let bodyText = hex(0x555555)
    static let bodyText = hex(0x000000, alpha: 0.75)
    static let tintColor = hex(0x383838)
    static let bgColor = hex(0xE2E2E2, alpha: 0.8)
    static let itemBg: Color = .white
    static let dim = hex(0x000000, alpha: 0.6)
//    static let url = hex(0x60c2d4)
    static let url = hex(0x778087)

    public var uiColor: UIColor {
        return UIColor(self)
    }
}

extension UIColor {

    
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let components = (
            R: CGFloat((hex >> 16) & 0xff) / 255,
            G: CGFloat((hex >> 08) & 0xff) / 255,
            B: CGFloat((hex >> 00) & 0xff) / 255
        )
        self.init(red: components.R, green: components.G, blue: components.B, alpha: alpha)
    }
}
