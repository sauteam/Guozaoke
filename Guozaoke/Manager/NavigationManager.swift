//
//  NavigationManager.swift
//  Guozaoke
//
//  Created by scy on 2025/9/23.
//

import SwiftUI
import Combine
let guozaokeGroup = "group.com.guozaoke.widget"

// MARK: - 导航管理器
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var shouldNavigateToPostDetail = false
    @Published var postDetailId: String = ""
    @Published var shouldNavigateToUserDetail = false
    @Published var userDetailId: String = ""
    
    init() {}
    
    // MARK: - 导航到帖子详情
    func navigateToPostDetail(postId: String) {        
        DispatchQueue.main.async {
            self.postDetailId = postId
            self.shouldNavigateToPostDetail = true
            logger("[NavigationManager] 已设置导航状态: shouldNavigateToPostDetail = \(self.shouldNavigateToPostDetail), postDetailId = \(self.postDetailId)")
        }
    }
    
    // MARK: - 检查 App Groups 中的导航信息
    func checkWidgetNavigation() {
        let userDefaults = UserDefaults(suiteName: guozaokeGroup)
        
        if let shouldNavigate = userDefaults?.bool(forKey: "should_navigate"), shouldNavigate {
            if let postId = userDefaults?.string(forKey: "navigate_post_id"),
               let postTitle = userDefaults?.string(forKey: "navigate_post_title") {
                logger("[NavigationManager] 从 Widget 检测到导航请求: \(postId), \(postTitle)")
                
                // 立即清除导航标记，防止重复触发
                userDefaults?.set(false, forKey: "should_navigate")
                userDefaults?.synchronize()
                
                // 执行导航
                DispatchQueue.main.async {
                    self.postDetailId = postId
                    self.shouldNavigateToPostDetail = true
                    logger("[NavigationManager] 已设置导航状态: shouldNavigateToPostDetail = \(self.shouldNavigateToPostDetail), postDetailId = \(self.postDetailId)")
                }
            } else {
                logger("[NavigationManager] 检测到导航标记但缺少帖子信息")
                // 即使缺少信息也要清除标记
                userDefaults?.set(false, forKey: "should_navigate")
                userDefaults?.synchronize()
            }
        }
    }
    
    // MARK: - 导航到用户详情
    func navigateToUserDetail(userId: String) {
        logger("[NavigationManager] 准备导航到用户详情: \(userId)")
        
        DispatchQueue.main.async {
            self.userDetailId = userId
            self.shouldNavigateToUserDetail = true
        }
    }
    
    // MARK: - 重置导航状态
    func resetNavigationState() {
        shouldNavigateToPostDetail = false
        shouldNavigateToUserDetail = false
        postDetailId = ""
        userDetailId = ""
    }
}
