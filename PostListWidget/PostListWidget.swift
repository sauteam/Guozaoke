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
        default:
            SmallWidgetView(posts: entry.posts, postType: entry.postType)
        }
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

// MARK: - Large Widget View
struct LargeWidgetView: View {
    let posts: [PostWidgetItem]
    let postType: PostListType
    @State private var isVIP = false
    
    init(posts: [PostWidgetItem], postType: PostListType) {
        self.posts = posts
        self.postType = postType
        self._isVIP = State(initialValue: VIPManager.shared.isVIP)
    }
    
    private var displayPosts: [PostWidgetItem] {
        let maxCount = min(8, posts.count)
        return Array(posts.prefix(maxCount))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题栏
            HStack {
                Text(postType.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
//                if isVIP {
//                    Image(systemName: "crown.fill")
//                        .foregroundColor(.yellow)
//                        .font(.system(size: 11))
//                }
//                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
            
            // 帖子列表 - 根据数据量显示最多10条
            if displayPosts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(Array(displayPosts.enumerated()), id: \.offset) { index, post in
                        Link(destination: {
                            if let postUrl = post.url, !postUrl.isEmpty {
                                let encodedUrl = postUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? postUrl
                                return URL(string: "\(guozaokeSchemeText):///t?id=\(encodedUrl)") ?? URL(string: "\(guozaokeSchemeText)://")!
                            } else {
                                return URL(string: "\(guozaokeSchemeText)://")!
                            }
                        }()) {
                            HStack(spacing: 10) {
                                // 序号
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                                    .frame(width: 18, alignment: .center)
                                
                                // 帖子信息
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(post.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text(post.author)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        
                                        if !post.node.isEmpty {
                                            Text("· \(post.node)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if post.replyCount > 0 {
                                            Text("· 评论\(post.replyCount)条")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .onTapGesture {
                            // 同时保存到App Groups作为备用方案
                            WidgetNavigationManager.shared.saveNavigationInfo(postId: post.url ?? "", postTitle: post.title)
                        }
                    }
                }
            }
        }
        .padding(14)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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

@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    PostListWidget()
} timeline: {
    SimpleEntry(date: .now, posts: [], postType: .latest)
}
