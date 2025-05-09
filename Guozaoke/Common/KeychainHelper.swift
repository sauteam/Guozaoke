//
//  KeychainHelper.swift
//  Guozaoke
//
//  Created by scy on 2025/3/12.
//

import Foundation
import Security

struct KeychainKeys {
    static let purchaseGuozaokeKey = "purchaseGuozaokeKey"
}

/// 1.5.3
let purchasedVersion = "1.5.3"

// MARK: - PurchaseAppState

class PurchaseAppState: ObservableObject {
    @Published var isPurchased: Bool = false
    
    private let purchaseKey = KeychainKeys.purchaseGuozaokeKey
    
    init() {
        checkAndSavePurchaseStatus()
    }
    
    func checkAndSavePurchaseStatus() {
        let currentVersion = AppInfo.appVersion
        if KeychainHelper.isPurchased == true {
            isPurchased = true
        } else if currentVersion < purchasedVersion {
            isPurchased = true
            savePurchaseStatus(isPurchased: isPurchased)
        } else {
            isPurchased = false
        }
        
        //log("[app][version][iap]1 currentVersion \(currentVersion) purchasedVersion \(purchasedVersion) isPurchased \(isPurchased)")
    }

    func savePurchaseStatus(isPurchased: Bool) {
        self.isPurchased = isPurchased
        let status = isPurchased ? "purchased" : "not_purchased"
        if let data = status.data(using: .utf8) {
            let success = KeychainHelper.save(key: purchaseKey, data: data)
            if success {
                log("[iap][purchase] Purchase status saved successfully")
            } else {
                log("[iap][purchase] Failed to save purchase status")
            }
        }
    }
    
    func clear() {
        isPurchased = false
        KeychainHelper.clearPurchaseStatus()
    }
}

// MARK: - KeychainHelper
class KeychainHelper {
    
    static func clearPurchaseStatus() {
        let clear = delete(key: KeychainKeys.purchaseGuozaokeKey)
        log("[iap][clear] \(clear)")
    }
    
    static var isPurchased: Bool {
        let savedStatus = KeychainHelper.retrieve(key: KeychainKeys.purchaseGuozaokeKey)
        return savedStatus == "purchased".data(using: .utf8)
    }

    static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve data from Keychain
    static func retrieve(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject? = nil
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        
        return nil
    }

    static func update(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        return status == errSecSuccess
    }

    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
