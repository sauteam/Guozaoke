import Foundation
import AppIntents

// MARK: - Widget Compile Test
// 这个文件用于测试Widget代码是否能正常编译

class WidgetCompileTest {
    
    static func testBasicFunctionality() {
        // 测试基本数据结构
        let testPost = PostWidgetItem(
            id: "test",
            title: "测试标题",
            author: "测试作者",
            timeAgo: "1小时前",
            replyCount: 5,
            node: "iOS"
        )
        
        logger("测试帖子: \(testPost.title)")
        
        // 测试数据管理
        WidgetDataManager.savePosts([testPost])
        let loadedPosts = WidgetDataManager.loadPosts()
        logger("加载了 \(loadedPosts.count) 条帖子")
        
        // 测试帖子类型
        let postType: PostListType = .latest
        logger("帖子类型: \(postType.rawValue)")
    }
    
    static func testAPIService() async {
        do {
            let posts = try await WidgetAPIService.fetchLatestPosts()
            logger("API测试成功，获取到 \(posts.count) 条帖子")
        } catch {
            logger("API测试失败: \(error)")
        }
    }
    
    static func testHTMLParsing() {
        let sampleHTML = """
        <div class="cell item">
            <a href="/t/12345">测试帖子标题</a>
            <strong><a href="/member/username">作者名</a></strong>
            <span class="small fade">2小时前</span>
            <a href="/t/12345" class="count_livid">15</a>
        </div>
        """
        
        let posts = WidgetPostParser.parsePostsFromHTML(sampleHTML)
        logger("HTML解析测试: \(posts.count) 条帖子")
    }
}
