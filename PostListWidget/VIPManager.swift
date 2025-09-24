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
        self.userDefaults = UserDefaults(suiteName: "group.com.guozaoke.widget")
        if userDefaults == nil {
            logger("[VIPManager] 警告: 无法访问App Group UserDefaults")
        }
    }
    
    var isVIP: Bool {
        get {
            if let appGroupVIP = userDefaults?.bool(forKey: vipKey) {
                return appGroupVIP
            }
            return checkVIPFromKeychain()
        }
        set {
            userDefaults?.set(newValue, forKey: vipKey)
        }
    }
    
    private func checkVIPFromKeychain() -> Bool {
        // 检查Keychain中的购买状态
        let purchaseKey = "purchaseGuozaokeKey"
        
        // 尝试从Keychain读取购买状态
        if let data = KeychainHelper.load(key: purchaseKey),
           let status = String(data: data, encoding: .utf8) {
            return status == "purchased"
        }
        
        // 检查版本号（付费下载用户）
        let currentVersion = getAppVersion()
        let purchasedVersion = "1.5.3"
        
        if currentVersion < purchasedVersion {
            return true
        }
        
        return false
    }
    
    private func getAppVersion() -> String {
        // 从App Groups获取版本信息，如果没有则返回当前版本
        if let version = userDefaults?.string(forKey: "app_version") {
            return version
        }
        return "1.5.5" // 默认版本，假设当前版本高于付费版本
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
            // 非VIP用户可以访问"最新"和"默认"类型
            return [.latest, .hot]
        }
    }
    
    // MARK: - 用户选择的帖子类型管理
    func saveSelectedPostType(_ type: PostListType) {
        // 检查用户是否有权限访问该类型
        if canAccessPostType(type) {
            userDefaults?.set(type.rawValue, forKey: selectedPostTypeKey)
            logger("[VIPManager] 保存用户选择的帖子类型: \(type.rawValue)")
        } else {
            logger("[VIPManager] 警告: 用户无权限访问类型 \(type.rawValue)，保存被拒绝")
        }
    }
    
    func getSelectedPostType() -> PostListType {
        if let savedType = userDefaults?.string(forKey: selectedPostTypeKey),
           let postType = PostListType(rawValue: savedType) {
            // 检查用户是否有权限访问该类型
            if canAccessPostType(postType) {
                return postType
            }
        }
        // 根据用户权限返回默认类型
        if isVIP {
            return .hot // VIP用户默认返回"默认"
        } else {
            return .latest // 非VIP用户默认返回"最新"
        }
    }
    
    func clearSelectedPostType() {
        userDefaults?.removeObject(forKey: selectedPostTypeKey)
        logger("[VIPManager] 清除用户选择的帖子类型")
    }
    
    // 从主应用同步VIP状态
    func syncVIPStatus() {
        let vipStatus = checkVIPFromKeychain()
        userDefaults?.set(vipStatus, forKey: vipKey)
        logger("[VIPManager] 同步VIP状态: \(vipStatus)")
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
