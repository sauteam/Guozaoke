//
//  Utils.swift
//  PostListWidgetExtension
//
//  Created by scy on 2025/9/24.
//

import Foundation

private let loggable: Bool = true

public func logger(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if !loggable {
        return
    }
    debugPrint("[log]", items, separator, terminator)
}
