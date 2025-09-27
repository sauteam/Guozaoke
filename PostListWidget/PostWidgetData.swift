import Foundation
import AppIntents

class PostWidgetData {
    // MARK: - Fetch Latest Posts
    static func fetchLatestPosts() async -> [PostWidgetItem] {
        do {
            let posts = try await fetchFromAPI()
            logger("[Widget] API获取成功，获得 \(posts.count) 条帖子")
            WidgetDataManager.savePosts(posts)
            return posts
        } catch {
            logger("[Widget] API获取失败: \(error)")
            if let cachedPosts = loadCachedPosts(), !cachedPosts.isEmpty {
                logger("[Widget] 使用缓存数据，共 \(cachedPosts.count) 条")
                return cachedPosts
            }
            return []
        }
    }
    
    // MARK: - Fetch Posts by Type
    static func fetchPosts(by type: PostListType) async -> [PostWidgetItem] {
        VIPManager.shared.syncVIPStatus()
        if !VIPManager.shared.canAccessPostType(type) {
            return await fetchPosts(by: .latest)
        }
        
        do {
            let posts = try await WidgetAPIService.fetchPosts(for: type)
            logger("[Widget] \(type.rawValue) 帖子获取成功，共 \(posts.count) 条")
            savePostsToCache(posts, for: type)
            return posts
        } catch {
            if let cachedPosts = loadCachedPosts(for: type), !cachedPosts.isEmpty {
                return cachedPosts
            }
            return []
        }
    }
    
    // MARK: - Load Cached Posts
    private static func loadCachedPosts() -> [PostWidgetItem]? {
        guard let userDefaults = UserDefaults(suiteName: guozaokeGroup),
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
    
    private static func loadCachedPosts(for type: PostListType) -> [PostWidgetItem]? {
        let cacheKey = "posts_\(type.rawValue)"
        guard let userDefaults = UserDefaults(suiteName: guozaokeGroup),
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
        guard let userDefaults = UserDefaults(suiteName: guozaokeGroup) else { return }
        
        do {
            let data = try JSONEncoder().encode(posts)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: "\(cacheKey)_timestamp")
            logger("[Widget] 已保存 \(type.rawValue) 数据到缓存，键: \(cacheKey)")
        } catch {
            logger("Failed to save posts for \(type.rawValue): \(error)")
        }
    }
    
    static func fetchRealPosts() async -> [PostWidgetItem] {
        do {
            let posts = try await fetchFromAPI()
            return posts
        } catch {
            logger("Widget fetch posts error: \(error)")
            return []
        }
    }
    
    private static func fetchFromAPI() async throws -> [PostWidgetItem] {
        return try await WidgetAPIService.fetchLatestPosts()
    }
}

// MARK: - Widget Data Persistence
class WidgetDataManager {
    private static let userDefaults = UserDefaults(suiteName: guozaokeGroup)
    
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
            return []
        }
        
        do {
            return try JSONDecoder().decode([PostWidgetItem].self, from: data)
        } catch {
            logger("Failed to load posts: \(error)")
            return []
        }
    }
    
    static func clearPosts() {
        userDefaults?.removeObject(forKey: "latest_posts")
        userDefaults?.removeObject(forKey: "last_update")
    }
}
