//
//  Utils.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import Foundation
import Combine
import UIKit
import SwiftUI

let screenBounds = UIScreen.main.bounds
let screenSize   = screenBounds.size
let screenWidth  = screenSize.width
let screenHeight = screenSize.height


/// 1.5 秒
let toastDuration = 1.5

private let loggable: Bool = true

public func logger(_ items: Any..., separator: String = " ", terminator: String = "\n", tag: String = "", file: String = #file, function: String = #function, line: Int = #line) {
    if !loggable {
        return
    }
    
    // 获取当前时间
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    
    // 获取文件名（不包含路径）
    let fileName = (file as NSString).lastPathComponent
    
    // 构建日志前缀
    var logPrefix = "[\(timestamp)]"
    
    if !tag.isEmpty {
        logPrefix += "[\(tag)]"
    }
    
    logPrefix += "[\(fileName):\(line)]"
    logPrefix += "[\(function)]"
    
    // 输出日志
    debugPrint(logPrefix, items, separator, terminator)
}


public func isSimulator() -> Bool {
#if targetEnvironment(simulator)
    return true
#endif
    return false
}


// 扩展用于圆角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


/// Publisher to read keyboard changes.
protocol KeyboardReadable {
    var keyboardPublisher: AnyPublisher<Bool, Never> { get }
}


extension KeyboardReadable {
    var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .map { _ in true },
            
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in false }
        )
            .eraseToAnyPublisher()
    }
}


func randomElements<T>(from array: [T], count: Int) -> [T] {
    return Array(array.shuffled().prefix(count))
}


func runInMain(delay: Int = 0, execute work: @escaping @convention(block) () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .microseconds(delay), execute: work)
}


func parseQueryParam(from url: String, param: String) -> String? {
    var tmpUrl: String = url
    if !tmpUrl.starts(with: "http") {
        tmpUrl = APIService.baseUrlString.appending(tmpUrl)
    }
    guard let tmpUrl = URLComponents(string: tmpUrl) else { return nil }
    return tmpUrl.queryItems?.first(where: { $0.name == param })?.value
}

func notEmpty(_ strs: String?...) -> Bool {
    for str in strs {
        if let str = str {
            if str.isEmpty { return false }
        } else { return false }
    }
    return true
}

extension URL {
    init?(_ url: String) {
        self.init(string: url)
    }

    func openSafari() {
        UIApplication.shared.open(self)
    }
}

extension String {
    func openURL() {
        //self.copyToClipboard()
        URL(self)?.openSafari()
    }
}


extension UIApplication {
    /// 去设置 UIApplication.openSettingsURLString
    static func toSettingUrl() {
        openUrl(UIApplication.openSettingsURLString)
    }
    
    static func openUrl(_ string: String?) {
        guard let string = string else { return  }
        if let url = URL(string: string) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
