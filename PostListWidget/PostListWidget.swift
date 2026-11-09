//
//  PostListWidget.swift
//  PostListWidget
//
//  Created by scy on 2025/9/22.
//

import WidgetKit
import SwiftUI
import AppIntents
// MARK: - Post Widget Data Model
struct PostWidgetItem: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let timeAgo: String
    let replyCount: Int
    let node: String
    let url: String?
    
    init(id: String, title: String, author: String, timeAgo: String, replyCount: Int = 0, node: String = "", url: String? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.timeAgo = timeAgo
        self.replyCount = replyCount
        self.node = node
        self.url = url
    }
}

// MARK: - Timeline Provider
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), posts: [], postType: .latest)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        VIPManager.shared.syncVIPStatus()
        
        // Widget snapshot
        let postType = VIPManager.shared.canAccessPostType(configuration.postType) ? configuration.postType : .latest
        
        let posts = await PostWidgetData.fetchPosts(by: postType)
        return SimpleEntry(date: Date(), posts: posts, postType: postType)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        
        // 同步VIP状态并检查权限
        VIPManager.shared.syncVIPStatus()
        
        // 确定要使用的帖子类型
        let postType: PostListType
        
        logger("[Widget] 用户选择的类型: \(configuration.postType.rawValue)")
        // Check VIP status and permissions
        
        // 如果用户选择了新类型且用户有权限访问，则保存并使用新类型
        if VIPManager.shared.canAccessPostType(configuration.postType) {
            VIPManager.shared.saveSelectedPostType(configuration.postType)
            postType = configuration.postType
            logger("[Widget] 使用用户选择的类型: \(postType.rawValue)")
        } else {
            // 如果用户没有权限访问选择的类型，使用用户之前保存的类型
            let savedType = VIPManager.shared.getSelectedPostType()
            logger("[Widget] 用户之前保存的类型: \(savedType.rawValue)")
            if VIPManager.shared.canAccessPostType(savedType) {
                postType = savedType
                logger("[Widget] 使用之前保存的类型: \(postType.rawValue)")
            } else {
                // 如果保存的类型也没有权限，使用默认类型
                postType = VIPManager.shared.isVIP ? .hot : .latest
                logger("[Widget] 使用默认类型: \(postType.rawValue)")
            }
        }
        
        let posts = await PostWidgetData.fetchPosts(by: postType)
        let entry = SimpleEntry(date: currentDate, posts: posts, postType: postType)
        
        // 1小时后刷新
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let posts: [PostWidgetItem]
    let postType: PostListType
}

struct PostListWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(posts: entry.posts, postType: entry.postType)
        case .systemMedium:
            MediumWidgetView(posts: entry.posts, postType: entry.postType)
        case .systemLarge:
            LargeWidgetView(posts: entry.posts, postType: entry.postType)
        case .systemExtraLarge:
            ExtraLargeWidgetView(posts: entry.posts, postType: entry.postType)
        default:
            SmallWidgetView(posts: entry.posts, postType: entry.postType)
        }
//        if #available(iOS 27.0, *), family == .systemExtraLargePortrait {
//            ExtraLargePortraitWidgetView(posts: entry.posts, postType: entry.postType)
//        } else {
//            switch family {
//            case .systemSmall:
//                SmallWidgetView(posts: entry.posts, postType: entry.postType)
//            case .systemMedium:
//                MediumWidgetView(posts: entry.posts, postType: entry.postType)
//            case .systemLarge:
//                LargeWidgetView(posts: entry.posts, postType: entry.postType)
//            case .systemExtraLarge:
//                ExtraLargeWidgetView(posts: entry.posts, postType: entry.postType)
//            default:
//                SmallWidgetView(posts: entry.posts, postType: entry.postType)
//            }
//        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let posts: [PostWidgetItem]
    let postType: PostListType
    
    private var displayPosts: [PostWidgetItem] {
        let maxCount = min(3, posts.count) 
        return Array(posts.prefix(maxCount))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 类型标签
            HStack {
                Text(postType.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
            
            // 帖子列表 - 根据数据量显示1-2条
            if displayPosts.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 3) {
                    ForEach(Array(displayPosts.enumerated()), id: \.offset) { index, post in
                        Link(destination: {
                            if let postUrl = post.url, !postUrl.isEmpty {
                                let encodedUrl = postUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? postUrl
                                return URL(string: "\(guozaokeSchemeText):///t?id=\(encodedUrl)") ?? URL(string: "\(guozaokeSchemeText)://")!
                            } else {
                                return URL(string: "\(guozaokeSchemeText)://")!
                            }
                        }()) {
                            HStack(spacing: 6) {
                                // 序号
                                Text("\(index + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.blue)
                                    .frame(width: 14, alignment: .center)
                                
                                // 帖子标题
                                Text(post.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onTapGesture {
                            WidgetNavigationManager.shared.saveNavigationInfo(postId: post.url ?? "", postTitle: post.title)
                        }
                    }
                }
            }
        }
        .padding(8)
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let posts: [PostWidgetItem]
    let postType: PostListType
    
    private var displayPosts: [PostWidgetItem] {
        let maxCount = min(4, posts.count)
        return Array(posts.prefix(maxCount))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 标题栏
            HStack {
//                Image(systemName: "newspaper.fill")
//                    .foregroundColor(.blue)
//                    .font(.system(size: 15, weight: .semibold))
                Text(postType.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 3)
            
            // 帖子列表 - 根据数据量显示最多5条
            if displayPosts.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 5) {
                    ForEach(Array(displayPosts.enumerated()), id: \.offset) { index, post in
                        Link(destination: {
                            if let postUrl = post.url, !postUrl.isEmpty {
                                let encodedUrl = postUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? postUrl
                                return URL(string: "\(guozaokeSchemeText):///t?id=\(encodedUrl)") ?? URL(string: "\(guozaokeSchemeText)://")!
                            } else {
                                return URL(string: "\(guozaokeSchemeText)://")!
                            }
                        }()) {
                            HStack(spacing: 8) {
                                // 序号
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.blue)
                                    .frame(width: 16, alignment: .center)
                                
                                // 帖子信息
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text(post.author)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                        
                                        if !post.node.isEmpty {
                                            Text("· \(post.node)")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if post.replyCount > 0 {
                                            Text("· 评论\(post.replyCount)条")
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onTapGesture {
                            WidgetNavigationManager.shared.saveNavigationInfo(postId: post.url ?? "", postTitle: post.title)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Reusable Widget Post Row View
struct WidgetPostRowView: View {
    let index: Int
    let post: PostWidgetItem
    var isCompact: Bool = false
    
    var body: some View {
        Link(destination: postUrl) {
            HStack(spacing: isCompact ? 6 : 8) {
                // 序号
                Text("\(index + 1)")
                    .font(.system(size: isCompact ? 10 : 11, weight: .bold))
                    .foregroundColor(index < 3 ? .blue : .secondary)
                    .frame(width: isCompact ? 16 : 18, alignment: .center)
                
                // 帖子标题与副信息
                VStack(alignment: .leading, spacing: isCompact ? 1 : 2) {
                    Text(post.title)
                        .font(.system(size: isCompact ? 11 : 12, weight: .medium))
                        .lineLimit(isCompact ? 1 : 2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(post.author)
                            .font(.system(size: isCompact ? 8 : 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if !post.node.isEmpty {
                            Text("· \(post.node)")
                                .font(.system(size: isCompact ? 8 : 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if post.replyCount > 0 {
                            Text("· \(post.replyCount)评")
                                .font(.system(size: isCompact ? 8 : 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, isCompact ? 1 : 2)
        }
        .onTapGesture {
            WidgetNavigationManager.shared.saveNavigationInfo(postId: post.url ?? "", postTitle: post.title)
        }
    }
    
    private var postUrl: URL {
        if let postUrl = post.url, !postUrl.isEmpty {
            let encodedUrl = postUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? postUrl
            return URL(string: "\(guozaokeSchemeText):///t?id=\(encodedUrl)") ?? URL(string: "\(guozaokeSchemeText)://")!
        } else {
            return URL(string: "\(guozaokeSchemeText)://")!
        }
    }
}

// MARK: - Large Widget View (自适应单列/双列：大屏及 Duo 展开态双列避折，外屏及小屏单列自适应)
struct LargeWidgetView: View {
    let posts: [PostWidgetItem]
    let postType: PostListType
    
    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 360
            
            VStack(alignment: .leading, spacing: 6) {
                // 标题栏
                headerView
                
                if posts.isEmpty {
                    emptyView
                } else if isWide {
                    // 宽屏/展开态：左右双列并排 (最多展示 10 条，避免纵向溢出)
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(posts.prefix(5).enumerated()), id: \.offset) { index, post in
                                WidgetPostRowView(index: index, post: post, isCompact: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .padding(.vertical, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if posts.count > 5 {
                                ForEach(Array(posts.dropFirst(5).prefix(5).enumerated()), id: \.offset) { index, post in
                                    WidgetPostRowView(index: index + 5, post: post, isCompact: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    // 标准单列模式 (展示最多 6 条，配合 Spacer 弹性间距，彻底解决底部截断问题)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(posts.prefix(6).enumerated()), id: \.offset) { index, post in
                            WidgetPostRowView(index: index, post: post, isCompact: false)
                            if index < min(posts.count, 6) - 1 {
                                Spacer(minLength: 2)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .padding(4)
    }
    
    private var headerView: some View {
        HStack {
            Text(postType.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(4)
            
            Text("过早客")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if VIPManager.shared.isVIP {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text("VIP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.yellow)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("暂无内容")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Extra Large Widget View (超大号组件：适配 Duo 展开横屏，中央预留 28pt 间距避开折痕区)
struct ExtraLargeWidgetView: View {
    let posts: [PostWidgetItem]
    let postType: PostListType
    
    var body: some View {
        // 中间预留 28pt 避让带，与 iPhone Duo 铰链折痕完全对齐
        HStack(spacing: 28) {
            // 左窗格：精选热议列表 (1 ~ 6)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    Text(postType.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("· 精选热议")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
                
                if posts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("暂无数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(posts.prefix(6).enumerated()), id: \.offset) { index, post in
                            WidgetPostRowView(index: index, post: post, isCompact: false)
                            if index < min(posts.count, 6) - 1 {
                                Spacer(minLength: 4)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // 右窗格：更多讨论列表 (7 ~ 12)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("近期讨论")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    if VIPManager.shared.isVIP {
                        HStack(spacing: 2) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("VIP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(6)
                
                if posts.count <= 6 {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("进入应用浏览更多内容")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(posts.dropFirst(6).prefix(6).enumerated()), id: \.offset) { index, post in
                            WidgetPostRowView(index: index + 6, post: post, isCompact: false)
                            if index < min(posts.count - 6, 6) - 1 {
                                Spacer(minLength: 4)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(8)
    }
}

// MARK: - Extra Large Portrait Widget View (iOS 27+ 竖向最大号/台面姿态专用：上下双区避让)
struct ExtraLargePortraitWidgetView: View {
    let posts: [PostWidgetItem]
    let postType: PostListType
    
    var body: some View {
        // 上下双区布局，中间留出 20pt 避开水平折痕区
        VStack(alignment: .leading, spacing: 18) {
            // 上半区：精选热榜
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(postType.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                    Text("精选热榜")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ForEach(Array(posts.prefix(4).enumerated()), id: \.offset) { index, post in
                    WidgetPostRowView(index: index, post: post, isCompact: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // 下半区：最新动态
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("最新动态")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                ForEach(Array(posts.dropFirst(4).prefix(4).enumerated()), id: \.offset) { index, post in
                    WidgetPostRowView(index: index + 4, post: post, isCompact: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(6)
    }
}

// MARK: - Widget Family Extension (仅支持小号与中号组件；大号及超大号组件先注销不展示)
extension WidgetFamily {
    static var allSupportedFamilies: [WidgetFamily] {
        return [
            .systemSmall,
            .systemMedium
            // .systemLarge // Duo 最大的小组件先注销掉不展示，目前布局展示不太好
        ]
    }
}

struct PostListWidget: Widget {
    let kind: String = "PostListWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            PostListWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("过早客小组件")
        .description("最新、热门主题一览，VIP用户可选择更多类型。")
        .supportedFamilies(WidgetFamily.allSupportedFamilies)
    }
}

// MARK: - Preview
@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    PostListWidget()
} timeline: {
    SimpleEntry(date: .now, posts: [], postType: .latest)
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    PostListWidget()
} timeline: {
    SimpleEntry(date: .now, posts: [], postType: .latest)
}

// 最大的大号及超大号组件预览暂先注释
/*
@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    PostListWidget()
} timeline: {
    SimpleEntry(date: .now, posts: [], postType: .latest)
}

@available(iOS 17.0, *)
#Preview(as: .systemExtraLarge) {
    PostListWidget()
} timeline: {
    SimpleEntry(date: .now, posts: [], postType: .latest)
}

@available(iOS 27.0, *)
#Preview(as: .systemExtraLargePortrait) {
    PostListWidget()
} timeline: {
    SimpleEntry(date: .now, posts: [], postType: .latest)
}
*/
