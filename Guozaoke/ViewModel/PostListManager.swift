import Foundation

enum PostListType: String, CaseIterable, Codable {
    case hot       = "默认"
    case latest    = "最新"
    case elite     = "精华"
    case interest  = "兴趣"
    case follows   = "关注"
    case it        = "IT"
    case finance   = "金融"
    case creator   = "创客"
    case dating    = "相亲"
    case hand2     = "二手"
    case auto      = "汽车"
    case digital   = "数码"
    case education = "教育"
    case food      = "美食"
    case film      = "影视"

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


struct PostListItem: Codable, Identifiable {
    var id: PostListType { type }
    var type: PostListType
    var isVisible: Bool
}

class PostListViewModel: ObservableObject {
    @Published var postListItems: [PostListItem]
    private let saveFilePath: URL
    static let lastSelectedTypeKey = "LastSelectedPostListType"
    
    init() {
        self.saveFilePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("PostListItems.json")
        self.postListItems = PostListType.allCases.map { PostListItem(type: $0, isVisible: true) }
        load()
    }
    
    func movePostListItem(fromOffsets: IndexSet, toOffset: Int) {
        postListItems.move(fromOffsets: fromOffsets, toOffset: toOffset)
        save()
    }
    
    func setVisibility(forType type: PostListType, isVisible: Bool) {
        if let index = postListItems.firstIndex(where: { $0.type == type }) {
            postListItems[index].isVisible = isVisible
            save()
        }
    }
        
    var visibleItems: [PostListItem] {
        let visible = postListItems.filter { $0.isVisible }
        if visible.count < 2 {
            return Array(postListItems.prefix(6))
        }
        return visible
    }
    
    func saveLastSelectedType(_ type: PostListType) {
        UserDefaults.standard.set(type.rawValue, forKey: PostListViewModel.lastSelectedTypeKey)
    }
    
    func loadLastSelectedType() -> PostListType? {
        if let rawValue = UserDefaults.standard.string(forKey: PostListViewModel.lastSelectedTypeKey),
           let type = PostListType(rawValue: rawValue) {
            if postListItems.first(where: { $0.type == type && $0.isVisible }) != nil {
                return type
            }
        }
        return visibleItems.first?.type
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(postListItems)
            try data.write(to: saveFilePath)
        } catch {
            print("Failed to save post list items: \(error)")
        }
    }
    
    private func load() {
        do {
            let data = try Data(contentsOf: saveFilePath)
            postListItems = try JSONDecoder().decode([PostListItem].self, from: data)
        } catch {
            print("Failed to load post list items: \(error)")
        }
    }
}
