//
//  VIPManager.swift
//  PostListWidget
//
//  Created by scy on 2025/9/22.
//

import Foundation

class VIPManager {
    static let shared = VIPManager()
    
    private let userDefaults: UserDefaults?
    private let vipKey = "is_vip_user"
    private let selectedPostTypeKey = "selected_post_type"
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: guozaokeGroup)
        // App Groups UserDefaults initialization
    }
    
    var isVIP: Bool {
        get {
            if let appGroupVIP = userDefaults?.bool(forKey: vipKey) {
                return appGroupVIP
            }
            let keychainVIP = checkVIPFromKeychain()
            userDefaults?.set(keychainVIP, forKey: vipKey)
            userDefaults?.synchronize()
            return keychainVIP
        }
        set {
            userDefaults?.set(newValue, forKey: vipKey)
            userDefaults?.synchronize()
        }
    }
    
    private func checkVIPFromKeychain() -> Bool {
        let purchaseKey = "purchaseGuozaokeKey"
        if let data = KeychainHelper.load(key: purchaseKey),
           let status = String(data: data, encoding: .utf8) {
            return status == "purchased"
        }
        let currentVersion = getAppVersion()
        let purchasedVersion = "1.5.3"
        var isPurchased = false
        if currentVersion < purchasedVersion {
            isPurchased =  true
        }
        return isPurchased
    }
    
    private func getAppVersion() -> String {
        if let version = userDefaults?.string(forKey: "app_version") {
            return version
        }
        return "1.5.5"
    }
    
    func canAccessPostType(_ type: PostListType) -> Bool {
        if type.isVIPOnly {
            return isVIP
        }
        return true
    }
    
    func getAvailablePostTypes() -> [PostListType] {
        if isVIP {
            return PostListType.allCases
        } else {
            return [.latest, .hot]
        }
    }
    
    // MARK: - 用户选择的帖子类型管理
    func saveSelectedPostType(_ type: PostListType) {
        if canAccessPostType(type) {
            userDefaults?.set(type.rawValue, forKey: selectedPostTypeKey)
            // Save selected post type
        } else {
            // User doesn't have permission to access this type
        }
    }
    
    func getSelectedPostType() -> PostListType {
        if let savedType = userDefaults?.string(forKey: selectedPostTypeKey),
           let postType = PostListType(rawValue: savedType) {
            if canAccessPostType(postType) {
                return postType
            }
        }
        if isVIP {
            return .hot
        } else {
            return .latest
        }
    }
    
    func clearSelectedPostType() {
        userDefaults?.removeObject(forKey: selectedPostTypeKey)
        // Clear selected post type
    }
    
    func syncVIPStatus() {
        if let appGroupVIP = userDefaults?.bool(forKey: vipKey) {
            return
        }
        let vipStatus = checkVIPFromKeychain()
        userDefaults?.set(vipStatus, forKey: vipKey)
        userDefaults?.synchronize()
    }
}

// MARK: - KeychainHelper for Widget
class KeychainHelper {
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        
        return nil
    }
}
