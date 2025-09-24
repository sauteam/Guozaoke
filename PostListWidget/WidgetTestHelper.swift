import Foundation

// MARK: - Widget Test Helper
class WidgetTestHelper {
    
    // MARK: - Test HTML Parsing
    static func testHTMLParsing() {
        let sampleHTML = """
        <div class="cell item">
            <table cellpadding="0" cellspacing="0" border="0" width="100%">
                <tr>
                    <td width="48" valign="top" align="center">
                        <a href="/member/username">
                            <img src="avatar.jpg" class="avatar" border="0" align="default">
                        </a>
                    </td>
                    <td width="10"></td>
                    <td width="auto" valign="middle">
                        <span class="item_title">
                            <a href="/t/12345">这是一个测试帖子标题</a>
                        </span>
                        <div class="sep5"></div>
                        <span class="small fade">
                            <strong><a href="/member/username">作者名</a></strong>
                            <span class="chevron"> › </span>
                            <a href="/node/ios">iOS</a>
                            <span class="chevron"> › </span>
                            <a href="/t/12345">2小时前</a>
                        </span>
                    </td>
                    <td width="70" align="right" valign="top">
                        <a href="/t/12345" class="count_livid">15</a>
                    </td>
                </tr>
            </table>
        </div>
        """
        
        let posts = WidgetPostParser.parsePostsFromHTML(sampleHTML)
        logger("解析结果: \(posts.count) 条帖子")
        for post in posts {
            logger("标题: \(post.title)")
            logger("作者: \(post.author)")
            logger("回复数: \(post.replyCount)")
            logger("节点: \(post.node)")
            logger("---")
        }
    }
    
    // MARK: - Test API Call
    static func testAPICall() async {
        do {
            let posts = try await WidgetAPIService.fetchLatestPosts()
            logger("API调用成功，获取到 \(posts.count) 条帖子")
            for post in posts.prefix(3) {
                logger("标题: \(post.title)")
                logger("作者: \(post.author)")
                logger("---")
            }
        } catch {
            logger("API调用失败: \(error)")
        }
    }
    
    // MARK: - Test Data Persistence
    static func testDataPersistence() {
        let testPosts = [
            PostWidgetItem(
                id: "test1",
                title: "测试帖子1",
                author: "测试作者1",
                timeAgo: "1小时前",
                replyCount: 5,
                node: "iOS"
            ),
            PostWidgetItem(
                id: "test2",
                title: "测试帖子2",
                author: "测试作者2",
                timeAgo: "2小时前",
                replyCount: 10,
                node: "Swift"
            )
        ]
        
        // 保存数据
        WidgetDataManager.savePosts(testPosts)
        logger("数据已保存")
        
        // 读取数据
        let loadedPosts = WidgetDataManager.loadPosts()
        logger("读取到 \(loadedPosts.count) 条帖子")
        
        // 清理数据
        WidgetDataManager.clearPosts()
        logger("数据已清理")
    }
}
