//
//  AppIntent.swift
//  PostListWidget
//
//  Created by scy on 2025/9/22.
//

import WidgetKit
import AppIntents
import UIKit

enum PostListType: String, CaseIterable, AppEnum {
    case hot = "默认"
    case latest = "最新"
    case elite = "精华"
    case interest = "兴趣"
    case follows = "关注"
    case it = "IT"
    case job = "工作"
    case finance = "金融"
    case creator = "创客"
    case dating = "相亲"
    case hand2 = "二手"
    case auto = "汽车"
    case digital = "数码"
    case education = "教育"
    case food = "美食"
    case film = "影视"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "帖子类型"
    }
    
    static var caseDisplayRepresentations: [PostListType: DisplayRepresentation] {
        [
            .hot: "默认",
            .latest: "最新",
            .elite: "精华 (VIP)",
            .interest: "兴趣 (VIP)",
            .follows: "关注 (VIP)",
            .it: "IT (VIP)",
            .job: "工作 (VIP)",
            .finance: "金融 (VIP)",
            .creator: "创客 (VIP)",
            .dating: "相亲 (VIP)",
            .hand2: "二手 (VIP)",
            .auto: "汽车 (VIP)",
            .digital: "数码 (VIP)",
            .education: "教育 (VIP)",
            .food: "美食 (VIP)",
            .film: "影视 (VIP)"
        ]
    }
    
    var isVIPOnly: Bool {
        switch self {
        case .latest, .hot:
            return false
        case .elite, .interest, .follows, .it, .job, .finance, .creator, .dating, .hand2, .auto, .digital, .education, .food, .film:
            return true
        }
    }
    
    var url: String {
        switch self {
        case .hot:
            return ""
        case .latest:
            return "/?tab=latest"
        case .elite:
            return "/?tab=elite"
        case .interest:
            return "/?tab=interest"
        case .follows:
            return "/?tab=follows"
        case .it:
            return "/node/IT"
        case .job:
            return "/node/job"
        case .finance:
            return "/node/finance"
        case .creator:
            return "/node/startup"
        case .dating:
            return "/node/date"
        case .hand2:
            return "/node/2ndhand"
        case .auto:
            return "/node/auto"
        case .digital:
            return "/node/digital"
        case .education:
            return "/node/education"
        case .food:
            return "/node/food"
        case .film:
            return "/node/movie"
        }
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "过早客讨论" }
    static var description: IntentDescription { "显示讨论列表" }

    @Parameter(title: "帖子类型", default: .latest)
    var postType: PostListType
    
    func perform() async throws -> some IntentResult {
        // Widget Configuration Intent 不需要实际执行操作
        return .result()
    }
}

// MARK: - Open Post Detail Intent
struct OpenPostDetailIntent: AppIntent {
    static var title: LocalizedStringResource { "打开帖子详情" }
    static var description: IntentDescription { "在过早客App中打开帖子详情页面" }
    
    @Parameter(title: "帖子ID")
    var postId: String
    
    @Parameter(title: "帖子标题")
    var postTitle: String
    
    init() {
        self.postId = ""
        self.postTitle = ""
    }
    
    init(postId: String, postTitle: String) {
        self.postId = postId
        self.postTitle = postTitle
    }
    
    func perform() async throws -> some IntentResult {
        logger("[OpenPostDetailIntent] 准备跳转到帖子详情: \(postId)")
        
        // 使用 App Groups 保存导航信息
        WidgetNavigationManager.shared.saveNavigationInfo(postId: postId, postTitle: postTitle)
        // 主应用会通过定时器或应用启动时检查这些信息
        logger("[OpenPostDetailIntent] 已保存导航信息到App Groups")
        return .result()
    }
}
