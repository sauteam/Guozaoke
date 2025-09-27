//
//  AppIntent.swift
//  PostListWidget
//
//  Created by scy on 2025/9/22.
//

import WidgetKit
import AppIntents
import UIKit

let guozaokeSchemeText = "guozaoke"
let guozaokeGroup = "group.com.guozaoke.widget"


enum PostListType: String, CaseIterable, AppEnum {
    case hot = "默认"
    case latest = "最新"
    case elite = "精华"
    case interest = "兴趣"
    case follows = "关注"
    case it = "IT"
    case finance = "金融"
    case creator = "创客"
    case job = "工作"
    case dating = "相亲"
    case hand2 = "二手"
    case auto = "汽车"
    case digital = "数码"
    case education = "教育"
    case food = "美食"
    case film = "影视"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "主题类型"
    }
    
    static var caseDisplayRepresentations: [PostListType: DisplayRepresentation] {
        [
            .hot: "默认",
            .latest: "最新",
            .elite: "精华 (VIP)",
            .interest: "兴趣 (VIP)",
            .follows: "关注 (VIP)",
            .it: "IT (VIP)",
            .finance: "金融 (VIP)",
            .creator: "创客 (VIP)",
            .job: "工作 (VIP)",
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
        case .elite, .interest, .follows, .it, .finance, .creator, .auto, .digital, .education, .food, .film, .job, .dating, .hand2:
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
        case .finance:
            return "/node/finance"
        case .creator:
            return "/node/startup"
        case .job:
            return "/node/job"
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
    static var title: LocalizedStringResource { "过早客" }
    static var description: IntentDescription { "主题列表" }

    @Parameter(title: "类型", default: .latest)
    var postType: PostListType
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Open Post Detail Intent
struct OpenPostDetailIntent: AppIntent {
    static var title: LocalizedStringResource { "打开主题详情" }
    static var description: IntentDescription { "在过早客App中打开主题详情页面" }
    
    @Parameter(title: "主题ID")
    var postId: String
    
    @Parameter(title: "主题标题")
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
        WidgetNavigationManager.shared.saveNavigationInfo(postId: postId, postTitle: postTitle)
        return .result()
    }
}
