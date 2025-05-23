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

public func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if !loggable {
        return
    }
#if DEBUG
    print(items, separator, terminator)
#endif
}


public func isSimulator() -> Bool {
#if (arch(i386) || arch(x86_64)) && os(iOS)
    return true
#endif
    return false
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
