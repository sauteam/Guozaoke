//
//  SendCommentInfo.swift
//  Guozaoke
//
//  Created by scy on 2025/3/5.
//

import Foundation

struct SendCommentInfo: Codable {
    static let sendCommentInfoKey = "SendCommentInfo-"
    let content: String?
    let detailId: String?
    let username: String?
    

    static func saveComment(_ comment: SendCommentInfo) {
        do {
            if let info = getCommentInfo(comment.username ?? ""), info.content == comment.content {
                log("[comment][save] 相同内容不保存")
                return
            }
            
            let jsonData = try JSONEncoder().encode(comment)
            Persist.save(value: jsonData, forkey: keyValue(comment.username))
            log("[comment][save]: \(comment) saved \(keyValue(comment.username))")
        } catch {
            log("Save post failed")
        }
    }
    
    static func keyValue(_ text: String?) -> String {
        return sendCommentInfoKey + (text ?? "")
    }
    
    static func getCommentInfo(_ username: String) -> SendCommentInfo? {
        do {
            let data = Persist.read(key: keyValue(username))
            guard let data = data else { return nil }
            let info = try JSONDecoder()
                .decode(SendCommentInfo.self, from: data)
            log("[comment][getCommentInfo] get: \(info) saved \(keyValue(username))")
            return info
        } catch {
            log("[comment][getCommentInfo] readAccount failed")
        }
        return nil
    }
    
    static func hadCommentInfo(_ username: String) -> Bool {
        let info = getCommentInfo(username)
        return info?.content != nil && info?.username != nil
    }
        
    static func removeComment(_ commentId: String) {
        Persist.remove(key: keyValue(commentId))
        log("[comment][remove] \(keyValue(commentId))")
    }
    
    static func clearAllSendCommentInfo() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix(sendCommentInfoKey) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}

struct EditPost: Codable {
    static let editPostInfoKey = "EditPostInfo" + "-" + AccountState.userName
    let title: String?
    let content: String?
    let topicId: String?
    let topicLink: String?

    static func saveEditPost(_ post: EditPost) {
        do {
            let jsonData = try JSONEncoder().encode(post)
            Persist.save(value: jsonData, forkey: editPostInfoKey)
            log("account: \(post) saved")
        } catch {
            log("Save post failed")
        }
    }
    
    static func removeEditPost() {
        Persist.remove(key: editPostInfoKey)
    }
    
    static func getEditPost() -> EditPost? {
        do {
            let data = Persist.read(key: editPostInfoKey)
            guard let data = data else { return nil }
            let info = try JSONDecoder()
                .decode(EditPost.self, from: data)
            return info
        } catch {
            log("readAccount failed")
        }
        return nil
    }
}
