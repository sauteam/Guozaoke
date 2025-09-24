import Foundation
import AppIntents

// MARK: - Post Widget Data Manager
class PostWidgetData {
    
    // MARK: - Sample Data
    static let samplePosts: [PostWidgetItem] = [
        PostWidgetItem(
            id: "1",
            title: "iOS 18 新功能体验分享",
            author: "开发者小王",
            timeAgo: "2小时前",
            replyCount: 15,
            node: "iOS"
        ),
        PostWidgetItem(
            id: "2", 
            title: "SwiftUI 最佳实践讨论",
            author: "Swift爱好者",
            timeAgo: "4小时前",
            replyCount: 8,
            node: "Swift"
        ),
        PostWidgetItem(
            id: "3",
            title: "Xcode 15 调试技巧",
            author: "iOS工程师",
            timeAgo: "6小时前",
            replyCount: 23,
            node: "开发工具"
        ),
        PostWidgetItem(
            id: "4",
            title: "App Store 审核经验分享",
            author: "独立开发者",
            timeAgo: "8小时前",
            replyCount: 12,
            node: "App Store"
        ),
        PostWidgetItem(
            id: "5",
            title: "Swift 6.0 新特性预览",
            author: "语言专家",
            timeAgo: "10小时前",
            replyCount: 31,
            node: "Swift"
        )
    ]
    
    // MARK: - Fetch Latest Posts
    static func fetchLatestPosts() async -> [PostWidgetItem] {
        logger("[Widget] 开始获取最新帖子...")
        
        do {
            // 直接从API获取最新数据
            let posts = try await fetchFromAPI()
            logger("[Widget] API获取成功，获得 \(posts.count) 条帖子")
            
            // 保存到缓存
            WidgetDataManager.savePosts(posts)
            logger("[Widget] 数据已保存到缓存")
            
            return posts
        } catch {
            logger("[Widget] API获取失败: \(error)")
            
            // 如果API失败，尝试从缓存获取
            if let cachedPosts = loadCachedPosts(), !cachedPosts.isEmpty {
                logger("[Widget] 使用缓存数据，共 \(cachedPosts.count) 条")
                return cachedPosts
            }
            
            logger("[Widget] 无缓存数据，返回示例数据")
            // 最后返回示例数据
            return samplePosts
        }
    }
    
    // MARK: - Fetch Posts by Type
    static func fetchPosts(by type: PostListType) async -> [PostWidgetItem] {
        logger("[Widget] 开始获取 \(type.rawValue) 帖子...")
        
        // 同步VIP状态
        VIPManager.shared.syncVIPStatus()
        
        // 检查VIP权限
        if !VIPManager.shared.canAccessPostType(type) {
            logger("[Widget] 用户无VIP权限，返回最新帖子")
            return await fetchPosts(by: .latest)
        }
        
        do {
            let posts = try await WidgetAPIService.fetchPosts(for: type)
            
            logger("[Widget] \(type.rawValue) 帖子获取成功，共 \(posts.count) 条")
            
            // 保存到缓存（使用类型特定的键）
            savePostsToCache(posts, for: type)
            logger("[Widget] 数据已保存到缓存")
            
            return posts
        } catch {
            logger("[Widget] \(type.rawValue) 帖子获取失败: \(error)")
            
            // 如果API失败，尝试从缓存获取
            if let cachedPosts = loadCachedPosts(for: type), !cachedPosts.isEmpty {
                logger("[Widget] 使用缓存数据，共 \(cachedPosts.count) 条")
                return cachedPosts
            }
            
            logger("[Widget] 无缓存数据，返回示例数据")
            // 最后返回示例数据
            return samplePosts
        }
    }
    
    // MARK: - Load Cached Posts
    private static func loadCachedPosts() -> [PostWidgetItem]? {
        guard let userDefaults = UserDefaults(suiteName: "group.com.guozaoke.widget"),
              let data = userDefaults.data(forKey: "latest_posts") else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([PostWidgetItem].self, from: data)
        } catch {
            logger("Failed to decode cached posts: \(error)")
            return nil
        }
    }
    
    // MARK: - Type-specific Cache Methods
    private static func loadCachedPosts(for type: PostListType) -> [PostWidgetItem]? {
        let cacheKey = "posts_\(type.rawValue)"
        guard let userDefaults = UserDefaults(suiteName: "group.com.guozaoke.widget"),
              let data = userDefaults.data(forKey: cacheKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([PostWidgetItem].self, from: data)
        } catch {
            logger("Failed to decode cached posts for \(type.rawValue): \(error)")
            return nil
        }
    }
    
    private static func savePostsToCache(_ posts: [PostWidgetItem], for type: PostListType) {
        let cacheKey = "posts_\(type.rawValue)"
        guard let userDefaults = UserDefaults(suiteName: "group.com.guozaoke.widget") else { return }
        
        do {
            let data = try JSONEncoder().encode(posts)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: "\(cacheKey)_timestamp")
            logger("[Widget] 已保存 \(type.rawValue) 数据到缓存，键: \(cacheKey)")
        } catch {
            logger("Failed to save posts for \(type.rawValue): \(error)")
        }
    }
    
    // MARK: - Real API Integration
    static func fetchRealPosts() async -> [PostWidgetItem] {
        do {
            let posts = try await fetchFromAPI()
            return posts
        } catch {
            logger("Widget fetch posts error: \(error)")
            return samplePosts
        }
    }
    
    private static func fetchFromAPI() async throws -> [PostWidgetItem] {
        // 使用WidgetAPIService获取最新帖子
        return try await WidgetAPIService.fetchLatestPosts()
    }
}

// MARK: - Widget Data Persistence
class WidgetDataManager {
    private static let userDefaults = UserDefaults(suiteName: "group.com.guozaoke.widget")
    
    static func savePosts(_ posts: [PostWidgetItem]) {
        do {
            let data = try JSONEncoder().encode(posts)
            userDefaults?.set(data, forKey: "latest_posts")
            userDefaults?.set(Date(), forKey: "last_update")
        } catch {
            logger("Failed to save posts: \(error)")
        }
    }
    
    static func loadPosts() -> [PostWidgetItem] {
        guard let data = userDefaults?.data(forKey: "latest_posts") else {
            return PostWidgetData.samplePosts
        }
        
        do {
            return try JSONDecoder().decode([PostWidgetItem].self, from: data)
        } catch {
            logger("Failed to load posts: \(error)")
            return PostWidgetData.samplePosts
        }
    }
    
    static func clearPosts() {
        userDefaults?.removeObject(forKey: "latest_posts")
        userDefaults?.removeObject(forKey: "last_update")
    }
}
