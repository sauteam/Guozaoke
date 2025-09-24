//
//  WidgetNavigationManager.swift
//  PostListWidget
//
//  Created by scy on 2025/9/23.
//

import Foundation

// MARK: - Widget 导航管理器
class WidgetNavigationManager {
    static let shared = WidgetNavigationManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.guozaoke.widget")
    
    private init() {}
    
    // MARK: - 保存导航信息
    func saveNavigationInfo(postId: String, postTitle: String) {
        userDefaults?.set(postId, forKey: "navigate_post_id")
        userDefaults?.set(postTitle, forKey: "navigate_post_title")
        userDefaults?.set(Date().timeIntervalSince1970, forKey: "navigate_timestamp")
        userDefaults?.set(true, forKey: "should_navigate")
        
        logger("[WidgetNavigationManager] 保存导航信息: \(postId), \(postTitle)")
    }
    
    // MARK: - 检查是否需要导航
    func shouldNavigate() -> Bool {
        return userDefaults?.bool(forKey: "should_navigate") ?? false
    }
    
    // MARK: - 获取导航信息
    func getNavigationInfo() -> (postId: String?, postTitle: String?) {
        let postId = userDefaults?.string(forKey: "navigate_post_id")
        let postTitle = userDefaults?.string(forKey: "navigate_post_title")
        return (postId, postTitle)
    }
    
    // MARK: - 清除导航信息
    func clearNavigationInfo() {
        userDefaults?.removeObject(forKey: "navigate_post_id")
        userDefaults?.removeObject(forKey: "navigate_post_title")
        userDefaults?.removeObject(forKey: "navigate_timestamp")
        userDefaults?.set(false, forKey: "should_navigate")
        logger("[WidgetNavigationManager] 清除导航信息")
    }
}
