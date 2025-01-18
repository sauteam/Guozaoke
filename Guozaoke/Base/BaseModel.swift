//
//  BaseModel.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftSoup

protocol HtmlParsable {
    init?(from html: Element?)
}

protocol HtmlItemModel: HtmlParsable, Identifiable {

}

protocol BaseModel: HtmlParsable {
    var rawData: String? { get set }

    func isValid() -> Bool
}

struct SimpleModel: BaseModel {
    init?(from html: Element?) { }

    func isValid() -> Bool {
        true
    }
}

extension BaseModel {
    var rawData: String? {
        get {
            return .empty
        }
        set {

        }
    }

    func isValid() -> Bool {
        return true
    }
}
