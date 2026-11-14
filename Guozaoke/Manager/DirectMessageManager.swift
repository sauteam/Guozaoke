//
//  DirectMessageManager.swift
//  Guozaoke
//
//  Created by scy on 2026/11/14.
//

import Foundation
import SwiftUI
import SwiftSoup
import Alamofire

// MARK: - 官方 /api/dm/ 数据契约模型
struct DMResponse<T: Codable>: Codable {
    let ok: Bool
    let message: String?
    let data: T?
}

struct DMSummaryData: Codable {
    let uid: Int?
    let unread: Int?
    let requests: Int?
    let policy: Int?
}

struct DMPeer: Codable {
    let id: Int?
    let uid: Int?
    let username: String?
    let display_name: String?
    let avatar: String?
    
    var resolvedId: String {
        if let u = uid, u > 0 { return String(u) }
        if let i = id, i > 0 { return String(i) }
        return username ?? ""
    }
}

struct DMConversationItem: Codable {
    let id: Int
    let peer: DMPeer?
    let preview: String?
    let unread: Int?
    let updated_at: String?
}

struct DMConversationsData: Codable {
    let items: [DMConversationItem]?
    let next_cursor: String?
}

struct DMMessageItem: Codable {
    let id: Int?
    let seq: Int?
    let sender: Int?
    let text: String?
    let created: String?
    let state: String?
    let mine: Bool?
}

struct DMMessagesData: Codable {
    let messages: [DMMessageItem]?
    let peer: DMPeer?
    let has_more: Bool?
    let state: String?
}

struct DMComposeData: Codable {
    let conversation_id: Int?
    let peer: DMPeer?
    let can_initiate: Bool?
    let qualification_message: String?
}

struct DMSendResult: Codable {
    let conversation_id: Int?
    let message: String?
}

// MARK: - 单条私信消息模型
struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var seq: Int?
    var senderId: Int?
    let senderUsername: String
    let senderNickname: String?
    let senderAvatar: String?
    let content: String
    let timestamp: Date
    var rawCreated: String?
    let isFromMe: Bool
    
    var timeFormatted: String {
        if let raw = rawCreated?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(timestamp) {
            formatter.dateFormat = "昨天 HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return formatter.string(from: timestamp)
    }
}

// MARK: - 会话列表项模型
struct DirectMessageThread: Identifiable, Codable, Equatable {
    var id: String { targetId }
    var conversationId: Int?      // 官方服务端对应的会话 ID (cid)
    var targetId: String          // 对方用户 ID（如 34）或用户名
    var targetUsername: String
    var targetNickname: String?
    var targetAvatar: String?
    var lastMessage: String
    var lastUpdated: Date
    var rawUpdated: String?
    var unreadCount: Int
    
    var displayName: String {
        if let nick = targetNickname, !nick.isEmpty {
            return nick
        }
        if !targetUsername.isEmpty {
            return targetUsername
        }
        return "社友 #\(targetId)"
    }
    
    var timeFormatted: String {
        if let raw = rawUpdated?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(lastUpdated) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(lastUpdated) {
            formatter.dateFormat = "昨天"
        } else {
            formatter.dateFormat = "MM-dd"
        }
        return formatter.string(from: lastUpdated)
    }
}

// MARK: - 私信会话与网络收发管理器
@MainActor
class DirectMessageManager: ObservableObject {
    static let shared = DirectMessageManager()
    
    @Published var threads: [DirectMessageThread] = []
    @Published var messages: [String: [ChatMessage]] = [:] // key: targetId
    @Published var isLoadingThreads: Bool = false
    @Published var isLoadingMessages: Bool = false
    @Published var isSending: Bool = false
    
    private let threadsKey = "com.guozaoke.ios.dm.threads"
    private let messagesKey = "com.guozaoke.ios.dm.messages"
    
    var hasUnread: Bool {
        threads.contains { $0.unreadCount > 0 }
    }
    
    var totalUnreadCount: Int {
        threads.reduce(0) { $0 + $1.unreadCount }
    }
    
    init() {
        loadLocalData()
        Task {
            await ensureMyAvatar()
        }
    }
    
    // MARK: - 会话去重与比对核心逻辑
    func isSameConversation(_ a: DirectMessageThread, _ b: DirectMessageThread) -> Bool {
        if let ca = a.conversationId, let cb = b.conversationId, ca > 0, cb > 0, ca == cb {
            return true
        }
        if !a.targetId.isEmpty && !b.targetId.isEmpty && a.targetId == b.targetId {
            return true
        }
        if !a.targetUsername.isEmpty && !b.targetUsername.isEmpty && a.targetUsername.caseInsensitiveCompare(b.targetUsername) == .orderedSame {
            return true
        }
        if (!a.targetId.isEmpty && a.targetId == b.targetUsername) || (!b.targetId.isEmpty && b.targetId == a.targetUsername) {
            return true
        }
        if let ca = a.conversationId, ca > 0, String(ca) == b.targetId {
            return true
        }
        if let cb = b.conversationId, cb > 0, String(cb) == a.targetId {
            return true
        }
        return false
    }
    
    func mergeOrAppendThread(_ newThread: DirectMessageThread, into list: inout [DirectMessageThread]) {
        if let idx = list.firstIndex(where: { isSameConversation($0, newThread) }) {
            var existing = list[idx]
            if existing.conversationId == nil && newThread.conversationId != nil {
                existing.conversationId = newThread.conversationId
            }
            if (existing.targetAvatar == nil || existing.targetAvatar?.isEmpty == true) && newThread.targetAvatar?.isEmpty == false {
                existing.targetAvatar = newThread.targetAvatar
            }
            if (existing.targetNickname == nil || existing.targetNickname?.isEmpty == true) && newThread.targetNickname?.isEmpty == false {
                existing.targetNickname = newThread.targetNickname
            }
            if existing.targetUsername.isEmpty && !newThread.targetUsername.isEmpty {
                existing.targetUsername = newThread.targetUsername
            }
            if newThread.lastUpdated > existing.lastUpdated {
                existing.lastMessage = newThread.lastMessage
                existing.lastUpdated = newThread.lastUpdated
            }
            existing.unreadCount = max(existing.unreadCount, newThread.unreadCount)
            list[idx] = existing
        } else {
            list.append(newThread)
        }
    }
    
    func deduplicateThreads(_ list: [DirectMessageThread]) -> [DirectMessageThread] {
        var result: [DirectMessageThread] = []
        for th in list {
            mergeOrAppendThread(th, into: &result)
        }
        return result
    }

    // MARK: - 本地持久化缓存
    private func loadLocalData() {
        if let threadData = UserDefaults.standard.data(forKey: threadsKey),
           let decodedThreads = try? JSONDecoder().decode([DirectMessageThread].self, from: threadData) {
            self.threads = deduplicateThreads(decodedThreads)
        }
        
        if let messageData = UserDefaults.standard.data(forKey: messagesKey),
           let decodedMessages = try? JSONDecoder().decode([String: [ChatMessage]].self, from: messageData) {
            self.messages = decodedMessages
        }
    }
    
    private func saveLocalData() {
        self.threads = deduplicateThreads(self.threads)
        if let encodedThreads = try? JSONEncoder().encode(threads) {
            UserDefaults.standard.set(encodedThreads, forKey: threadsKey)
        }
        if let encodedMessages = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encodedMessages, forKey: messagesKey)
        }
    }
    
    // MARK: - 确保登录用户的真实头像已缓存
    func ensureMyAvatar() async {
        guard AccountState.isLogin() else { return }
        let current = AccountState.avatarUrl
        if !current.isEmpty && current != "--" && !current.contains("s_default.png") {
            return
        }
        let myUsername = AccountState.userName
        guard !myUsername.isEmpty && myUsername != .default else { return }
        
        do {
            let url = "\(APIService.baseUrlString)/u/\(myUsername)"
            let html = try await NetworkManager.shared.get(url)
            let doc = try SwiftSoup.parse(html)
            
            let selectors = [
                ".ui-header a img",
                ".ui-header img",
                ".usercard img.avatar",
                ".gzk-avatar-menu summary img",
                ".gzk-menu-avatar",
                "img.avatar"
            ]
            for sel in selectors {
                if let img = try? doc.select(sel).first() {
                    let src = (try? img.attr("src")) ?? ""
                    if !src.isEmpty {
                        var finalSrc = src.trimmingCharacters(in: .whitespacesAndNewlines)
                        if finalSrc.hasPrefix("//") {
                            finalSrc = "https:" + finalSrc
                        } else if finalSrc.hasPrefix("/") {
                            finalSrc = APIService.baseUrlString + finalSrc
                        }
                        if var account = AccountState.getAccount() {
                            account.avatar = finalSrc
                            AccountState.saveAccount(account)
                            logger("[DirectMessage] 成功同步补全当前登录用户真实头像: \(finalSrc)")
                        }
                        break
                    }
                }
            }
        } catch {
            logger("[DirectMessage] 同步当前登录用户头像失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 会话查找与信息更新
    func findThread(targetId: String) -> DirectMessageThread? {
        let dummy = DirectMessageThread(
            conversationId: Int(targetId),
            targetId: targetId,
            targetUsername: targetId,
            lastMessage: "",
            lastUpdated: Date(),
            unreadCount: 0
        )
        return threads.first { isSameConversation($0, dummy) }
    }
    
    func updateThreadPeerInfo(conversationId: Int, peer: DMPeer) {
        let peerId = peer.resolvedId
        if let idx = threads.firstIndex(where: {
            ($0.conversationId != nil && $0.conversationId == conversationId) ||
            (!peerId.isEmpty && $0.targetId == peerId) ||
            (peer.username != nil && !peer.username!.isEmpty && $0.targetUsername == peer.username!)
        }) {
            var changed = false
            if let av = peer.avatar, !av.isEmpty, threads[idx].targetAvatar != av {
                threads[idx].targetAvatar = av
                changed = true
            }
            if let nick = peer.display_name, !nick.isEmpty, threads[idx].targetNickname != nick {
                threads[idx].targetNickname = nick
                changed = true
            }
            if let uname = peer.username, !uname.isEmpty, threads[idx].targetUsername != uname {
                threads[idx].targetUsername = uname
                changed = true
            }
            if threads[idx].conversationId == nil && conversationId > 0 {
                threads[idx].conversationId = conversationId
                changed = true
            }
            if changed {
                saveLocalData()
            }
        }
    }

    // MARK: - 日期解析助手
    static func parseDate(_ string: String?) -> Date? {
        guard let str = string?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else {
            return nil
        }
        if let ts = Double(str) {
            if ts > 10_000_000_000 {
                return Date(timeIntervalSince1970: ts / 1000.0)
            } else if ts > 1_000_000_000 {
                return Date(timeIntervalSince1970: ts)
            }
        }
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm:ss",
            "MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: str) {
                return d
            }
        }
        return nil
    }

    // MARK: - 标记已读（本地立即清零 + 向官方服务器发送已读同步）
    func markAsRead(targetId: String, maxSeq: Int? = nil) async {
        let dummy = DirectMessageThread(
            conversationId: Int(targetId),
            targetId: targetId,
            targetUsername: targetId,
            lastMessage: "",
            lastUpdated: Date(),
            unreadCount: 0
        )
        
        // 1. 本地立即清除所有匹配会话的未读数
        var changed = false
        for i in 0..<threads.count {
            if isSameConversation(threads[i], dummy) {
                if threads[i].unreadCount > 0 {
                    threads[i].unreadCount = 0
                    changed = true
                }
            }
        }
        if changed {
            saveLocalData()
        }
        
        guard AccountState.isLogin() else { return }
        
        // 2. 查找官方会话 ID 并同步已读状态: POST /api/dm/conversations/{cid}/read
        let thread = findThread(targetId: targetId)
        guard let cid = thread?.conversationId ?? Int(targetId), cid > 0 else { return }
        
        do {
            let readUrl = "\(APIService.baseUrlString)/api/dm/conversations/\(cid)/read"
            let token = AccountState.token()
            let headers: HTTPHeaders = [
                "Accept": "application/json",
                "Content-Type": "application/json",
                "Origin": APIService.baseUrlString,
                "Referer": "\(APIService.baseUrlString)/messages/\(cid)",
                "X-Xsrftoken": token
            ]
            
            let seq: Int = {
                if let s = maxSeq, s > 0 { return s }
                let msgs = getMessages(for: targetId)
                let incoming = msgs.filter { !$0.isFromMe }
                return incoming.compactMap { $0.seq }.max() ?? msgs.compactMap { $0.seq }.max() ?? 1000
            }()
            
            let payload: [String: Any] = ["seq": seq]
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            var urlRequest = try URLRequest(url: URL(string: readUrl)!, method: .post, headers: headers)
            urlRequest.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let resStr = String(data: data, encoding: .utf8) ?? ""
            logger("[DirectMessage] 向服务端同步已读成功 cid: \(cid), seq: \(seq), res: \(resStr)")
            
            // 3. 刷新未读概览数据
            await fetchSummary()
        } catch {
            logger("[DirectMessage] 向服务端同步已读失败: \(error.localizedDescription)")
        }
    }
    
    func getMessages(for targetId: String) -> [ChatMessage] {
        if let list = messages[targetId], !list.isEmpty {
            return list
        }
        if let thread = findThread(targetId: targetId) {
            if let list = messages[thread.targetId], !list.isEmpty {
                return list
            }
            if !thread.targetUsername.isEmpty, let list = messages[thread.targetUsername], !list.isEmpty {
                return list
            }
            if let cid = thread.conversationId, let list = messages[String(cid)], !list.isEmpty {
                return list
            }
        }
        return []
    }
    
    // MARK: - 抓取 /api/dm/summary 概览（红点同步）
    func fetchSummary() async {
        guard AccountState.isLogin() else { return }
        do {
            let url = "\(APIService.baseUrlString)/api/dm/summary"
            let headers: HTTPHeaders = [
                "Accept": "application/json",
                "X-Xsrftoken": AccountState.token()
            ]
            let jsonString = try await NetworkManager.shared.get(url, headers: headers)
            if let data = jsonString.data(using: .utf8),
               let resp = try? JSONDecoder().decode(DMResponse<DMSummaryData>.self, from: data),
               let summary = resp.data {
                let unread = (summary.unread ?? 0) + (summary.requests ?? 0)
                logger("[DirectMessage] 获取到官方未读总数: \(unread)")
            }
        } catch {
            logger("[DirectMessage] fetchSummary 失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 抓取 /api/dm/conversations 会话列表 (同时聚合 bucket 0 正常会话与 bucket 1 消息请求)
    func fetchThreads() async {
        guard AccountState.isLogin() else { return }
        
        self.isLoadingThreads = true
        do {
            var allThreads: [DirectMessageThread] = []
            let headers: HTTPHeaders = [
                "Accept": "application/json",
                "X-Xsrftoken": AccountState.token()
            ]
            
            // 1. 请求官方 API: /api/dm/conversations?bucket=0 (正式消息)
            let urlMessages = "\(APIService.baseUrlString)/api/dm/conversations?bucket=0"
            logger("[DirectMessage] 开始请求官方消息列表 API: \(urlMessages)")
            let res0 = try await NetworkManager.shared.get(urlMessages, headers: headers)
            if let data0 = res0.data(using: .utf8),
               let resp0 = try? JSONDecoder().decode(DMResponse<DMConversationsData>.self, from: data0),
               let items0 = resp0.data?.items {
                for item in items0 {
                    let peerId = item.peer?.resolvedId.isEmpty == false ? item.peer!.resolvedId : String(item.id)
                    let thread = DirectMessageThread(
                        conversationId: item.id,
                        targetId: peerId,
                        targetUsername: item.peer?.username ?? peerId,
                        targetNickname: item.peer?.display_name,
                        targetAvatar: item.peer?.avatar,
                        lastMessage: item.preview ?? "",
                        lastUpdated: DirectMessageManager.parseDate(item.updated_at) ?? Date(),
                        rawUpdated: item.updated_at,
                        unreadCount: item.unread ?? 0
                    )
                    mergeOrAppendThread(thread, into: &allThreads)
                }
            }
            
            // 2. 请求官方 API: /api/dm/conversations?bucket=1 (消息请求)
            let urlRequests = "\(APIService.baseUrlString)/api/dm/conversations?bucket=1"
            let res1 = try await NetworkManager.shared.get(urlRequests, headers: headers)
            if let data1 = res1.data(using: .utf8),
               let resp1 = try? JSONDecoder().decode(DMResponse<DMConversationsData>.self, from: data1),
               let items1 = resp1.data?.items {
                for item in items1 {
                    let peerId = item.peer?.resolvedId.isEmpty == false ? item.peer!.resolvedId : String(item.id)
                    let thread = DirectMessageThread(
                        conversationId: item.id,
                        targetId: peerId,
                        targetUsername: item.peer?.username ?? peerId,
                        targetNickname: item.peer?.display_name,
                        targetAvatar: item.peer?.avatar,
                        lastMessage: "[消息请求] \(item.preview ?? "")",
                        lastUpdated: DirectMessageManager.parseDate(item.updated_at) ?? Date(),
                        rawUpdated: item.updated_at,
                        unreadCount: item.unread ?? 1
                    )
                    mergeOrAppendThread(thread, into: &allThreads)
                }
            }
            
            // 3. 兜底保留本地已有但服务端可能处于待审核状态的会话（去重合并）
            for localThread in self.threads {
                mergeOrAppendThread(localThread, into: &allThreads)
            }
            
            self.threads = deduplicateThreads(allThreads)
            saveLocalData()
            self.isLoadingThreads = false
        } catch {
            logger("[DirectMessage] 获取官方私信列表失败: \(error.localizedDescription)")
            self.isLoadingThreads = false
        }
    }
    
    // MARK: - 抓取指定会话消息详情 /api/dm/conversations/{cid}/messages
    func fetchMessages(for targetId: String) async {
        guard AccountState.isLogin(), !targetId.isEmpty else { return }
        
        self.isLoadingMessages = true
        
        // 查找或定位 conversationId
        let thread = findThread(targetId: targetId)
        var cid = thread?.conversationId
        
        let headers: HTTPHeaders = [
            "Accept": "application/json",
            "X-Xsrftoken": AccountState.token()
        ]
        
        // 如果没有 cid，且 targetId 为纯数字或能提取出目标 UID，尝试先调用 /api/dm/compose?to={to} 获取会话 ID
        if cid == nil {
            let numericTo = Int(targetId.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined())
            if let to = numericTo, to > 0 {
                let composeUrl = "\(APIService.baseUrlString)/api/dm/compose?to=\(to)"
                if let composeRes = try? await NetworkManager.shared.get(composeUrl, headers: headers),
                   let cData = composeRes.data(using: .utf8),
                   let cResp = try? JSONDecoder().decode(DMResponse<DMComposeData>.self, from: cData),
                   let composeData = cResp.data {
                    if let newCid = composeData.conversation_id {
                        cid = newCid
                    }
                    if let peer = composeData.peer {
                        self.updateThreadPeerInfo(conversationId: composeData.conversation_id ?? 0, peer: peer)
                    }
                }
            }
        }
        
        do {
            var fetchedMessages: [ChatMessage] = []
            
            // 1. 如果已具备 conversationId，优先调用官方标准 API: /api/dm/conversations/{cid}/messages
            if let conversationId = cid {
                let url = "\(APIService.baseUrlString)/api/dm/conversations/\(conversationId)/messages"
                logger("[DirectMessage] 请求官方会话详情 API: \(url)")
                let jsonString = try await NetworkManager.shared.get(url, headers: headers)
                if let data = jsonString.data(using: .utf8),
                   let resp = try? JSONDecoder().decode(DMResponse<DMMessagesData>.self, from: data),
                   let msgItems = resp.data?.messages {
                    let peerAvatar = resp.data?.peer?.avatar ?? thread?.targetAvatar
                    let peerName = resp.data?.peer?.username ?? thread?.targetUsername ?? targetId
                    let peerNick = resp.data?.peer?.display_name ?? thread?.targetNickname
                    let myUsername = AccountState.userName
                    let myAvatar = AccountState.avatarUrl.isEmpty ? nil : AccountState.avatarUrl
                    
                    // 及时更新会话列表里的对方信息与头像
                    if let peer = resp.data?.peer {
                        self.updateThreadPeerInfo(conversationId: conversationId, peer: peer)
                    }
                    
                    for item in msgItems {
                        // 官方后端直接返回 mine 字段标识是否为当前登录用户发送
                        let isMe: Bool
                        if let m = item.mine {
                            isMe = m
                        } else if let sender = item.sender {
                            let peerUid = resp.data?.peer?.uid ?? resp.data?.peer?.id
                            isMe = (peerUid != nil ? (sender != peerUid) : false)
                        } else {
                            isMe = false
                        }
                        
                        let msg = ChatMessage(
                            seq: item.seq,
                            senderId: item.sender,
                            senderUsername: isMe ? myUsername : peerName,
                            senderNickname: isMe ? AccountState.displayName : peerNick,
                            senderAvatar: isMe ? myAvatar : peerAvatar,
                            content: item.text ?? "",
                            timestamp: DirectMessageManager.parseDate(item.created) ?? Date(),
                            rawCreated: item.created,
                            isFromMe: isMe
                        )
                        fetchedMessages.append(msg)
                    }
                }
            }
            
            // 2. 如果官方 API 暂无消息或无 cid，尝试直接从 /messages/{targetId} HTML 中解析
            if fetchedMessages.isEmpty {
                let url = "\(APIService.baseUrlString)/messages/\(targetId)"
                logger("[DirectMessage] 请求 /messages/\(targetId) HTML 进行兜底解析: \(url)")
                let html = try await NetworkManager.shared.get(url)
                let doc = try SwiftSoup.parse(html)
                let msgElements = try doc.select("#messages .dm-message, #messages .message, .dm-messages > div, .message-item")
                for elem in msgElements {
                    let text = try elem.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty && !text.contains("私信受社区保护") else { continue }
                    let isMe = elem.hasClass("from-me") || elem.hasClass("me") || elem.hasClass("self") || elem.hasClass("mine")
                    let msg = ChatMessage(
                        senderUsername: isMe ? AccountState.userName : targetId,
                        senderNickname: nil,
                        senderAvatar: isMe ? (AccountState.avatarUrl.isEmpty ? nil : AccountState.avatarUrl) : thread?.targetAvatar,
                        content: text,
                        timestamp: Date(),
                        rawCreated: nil,
                        isFromMe: isMe
                    )
                    fetchedMessages.append(msg)
                }
            }
            
            if !fetchedMessages.isEmpty {
                self.messages[targetId] = fetchedMessages
                if let th = self.findThread(targetId: targetId) {
                    self.messages[th.targetId] = fetchedMessages
                    if !th.targetUsername.isEmpty {
                        self.messages[th.targetUsername] = fetchedMessages
                    }
                    if let c = th.conversationId {
                        self.messages[String(c)] = fetchedMessages
                    }
                }
                saveLocalData()
            }
            
            let maxSeq = fetchedMessages.filter { !$0.isFromMe }.compactMap { $0.seq }.max()
            await markAsRead(targetId: targetId, maxSeq: maxSeq)
            self.isLoadingMessages = false
        } catch {
            logger("[DirectMessage] 抓取私信详情失败: \(error.localizedDescription)")
            self.isLoadingMessages = false
        }
    }
    
    // MARK: - 发送私信 POST /api/dm/messages (对标官方 dm-names-20261104.js)
    func sendMessage(
        to targetId: String,
        targetUsername: String,
        targetNickname: String? = nil,
        targetAvatar: String? = nil,
        content: String
    ) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard AccountState.isLogin() else {
            LoginStateChecker.LoginStateHandle()
            ToastView.warningToast(needLoginTextCanDo)
            return false
        }
        
        self.isSending = true
        
        // 1. 本地乐观 UI 立即插入
        let localMsg = ChatMessage(
            senderUsername: AccountState.userName,
            senderNickname: AccountState.displayName,
            senderAvatar: AccountState.avatarUrl,
            content: trimmed,
            timestamp: Date(),
            isFromMe: true
        )
        if self.messages[targetId] != nil {
            self.messages[targetId]?.append(localMsg)
        } else {
            self.messages[targetId] = [localMsg]
        }
        
        // 更新会话列表（安全去重查找与更新）
        let candidateThread = DirectMessageThread(
            conversationId: nil,
            targetId: targetId,
            targetUsername: targetUsername,
            targetNickname: targetNickname,
            targetAvatar: targetAvatar,
            lastMessage: trimmed,
            lastUpdated: Date(),
            unreadCount: 0
        )
        if let idx = threads.firstIndex(where: { isSameConversation($0, candidateThread) }) {
            threads[idx].lastMessage = trimmed
            threads[idx].lastUpdated = Date()
            if (threads[idx].targetAvatar == nil || threads[idx].targetAvatar?.isEmpty == true) && targetAvatar?.isEmpty == false {
                threads[idx].targetAvatar = targetAvatar
            }
            let moved = threads.remove(at: idx)
            threads.insert(moved, at: 0)
        } else {
            threads.insert(candidateThread, at: 0)
        }
        self.threads = deduplicateThreads(threads)
        saveLocalData()
        
        // 2. 发起官方 API POST 请求: https://www.guozaoke.com/api/dm/messages
        do {
            let apiUrl = "\(APIService.baseUrlString)/api/dm/messages"
            let token = AccountState.token()
            let clientKey = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            
            // 查找现有会话 ID
            let cid = threads.first(where: { $0.targetId == targetId })?.conversationId
            let numericPeerId = Int(targetId.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined())
            
            var payload: [String: Any] = [
                "text": trimmed,
                "client_key": clientKey
            ]
            if let validCid = cid, validCid > 0 {
                payload["conversation_id"] = validCid
            } else if let validPeer = numericPeerId, validPeer > 0 {
                payload["recipient_id"] = validPeer
            }
            
            let headers: HTTPHeaders = [
                "Accept": "application/json",
                "Content-Type": "application/json",
                "Origin": APIService.baseUrlString,
                "Referer": "\(APIService.baseUrlString)/messages/\(targetId)",
                "X-Xsrftoken": token
            ]
            
            logger("[DirectMessage] 向官方 API 提交私信: \(apiUrl), 参数: \(payload)")
            
            // 发送 JSON 格式 POST 请求
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            var urlRequest = try URLRequest(url: URL(string: apiUrl)!, method: .post, headers: headers)
            urlRequest.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let responseString = String(data: data, encoding: .utf8) ?? ""
            logger("[DirectMessage] 官方 API 响应: \(responseString)")
            
            if let resp = try? JSONDecoder().decode(DMResponse<DMSendResult>.self, from: data),
               let sendResult = resp.data {
                if let newCid = sendResult.conversation_id {
                    if let idx = self.threads.firstIndex(where: { $0.targetId == targetId }) {
                        self.threads[idx].conversationId = newCid
                        self.saveLocalData()
                    }
                }
                ToastView.successToast(sendResult.message ?? "消息已发出")
            } else if responseString.contains("ok") || responseString.contains("conversation_id") {
                ToastView.successToast("消息已发出")
            } else {
                // 如果官方 API 返回格式不同，兜底调用 POST /messages/{targetId}
                let formUrl = "\(APIService.baseUrlString)/messages/\(targetId)"
                let formParams: [String: Any] = [
                    "_xsrf": token,
                    "content": trimmed
                ]
                let formHeaders: HTTPHeaders = [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Origin": APIService.baseUrlString,
                    "Referer": formUrl,
                    "X-Xsrftoken": token
                ]
                _ = try? await NetworkManager.shared.post(formUrl, parameters: formParams, headers: formHeaders)
                ToastView.successToast("消息已发送")
            }
            
            self.isSending = false
            
            // 发送成功后刷新会话
            Task {
                await self.fetchThreads()
                await self.fetchMessages(for: targetId)
            }
            
            return true
        } catch {
            logger("[DirectMessage] 发送网络异常: \(error.localizedDescription)")
            self.isSending = false
            return true
        }
    }
    
    // MARK: - 删除与清空
    func deleteThread(targetId: String) async {
        let thread = findThread(targetId: targetId)
        let cid = thread?.conversationId ?? Int(targetId)
        
        // 1. 同步服务端隐藏会话: POST /api/dm/conversations/{cid}/hide
        if let validCid = cid, validCid > 0, AccountState.isLogin() {
            let hideUrl = "\(APIService.baseUrlString)/api/dm/conversations/\(validCid)/hide"
            let token = AccountState.token()
            let headers: HTTPHeaders = [
                "Accept": "application/json",
                "Content-Type": "application/json",
                "Origin": APIService.baseUrlString,
                "Referer": "\(APIService.baseUrlString)/messages/\(validCid)",
                "X-Xsrftoken": token
            ]
            do {
                var urlRequest = try URLRequest(url: URL(string: hideUrl)!, method: .post, headers: headers)
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [:])
                _ = try await URLSession.shared.data(for: urlRequest)
                logger("[DirectMessage] 服务端已隐藏会话 cid: \(validCid)")
            } catch {
                logger("[DirectMessage] 服务端隐藏会话失败: \(error.localizedDescription)")
            }
        }
        
        // 2. 本地删除所有关联数据
        let dummy = DirectMessageThread(
            conversationId: cid,
            targetId: targetId,
            targetUsername: targetId,
            lastMessage: "",
            lastUpdated: Date(),
            unreadCount: 0
        )
        threads.removeAll { isSameConversation($0, dummy) }
        messages.removeValue(forKey: targetId)
        if let th = thread {
            messages.removeValue(forKey: th.targetId)
            messages.removeValue(forKey: th.targetUsername)
            if let c = th.conversationId {
                messages.removeValue(forKey: String(c))
            }
        }
        saveLocalData()
        ToastView.successToast("会话已删除")
    }
    
    func clearMessages(for targetId: String) {
        let thread = findThread(targetId: targetId)
        let cid = thread?.conversationId ?? Int(targetId)
        let dummy = DirectMessageThread(
            conversationId: cid,
            targetId: targetId,
            targetUsername: targetId,
            lastMessage: "",
            lastUpdated: Date(),
            unreadCount: 0
        )
        
        messages[targetId] = []
        if let th = thread {
            messages[th.targetId] = []
            messages[th.targetUsername] = []
            if let c = th.conversationId {
                messages[String(c)] = []
            }
        }
        
        for i in 0..<threads.count {
            if isSameConversation(threads[i], dummy) {
                threads[i].lastMessage = "[暂无消息]"
            }
        }
        saveLocalData()
        ToastView.successToast("聊天记录已清空")
    }
}
