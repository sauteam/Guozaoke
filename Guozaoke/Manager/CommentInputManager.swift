//
//  CommentInputManager.swift
//  Guozaoke
//
//  Created by scy on 2025/1/27.
//

import SwiftUI

class CommentInputManager: ObservableObject {
    static let shared = CommentInputManager()
    
    @Published var isPresented = false
    @Published var detailId = ""
    @Published var replyUser = ""
    @Published var username = ""
    
    private var onDismiss: (() -> Void)?
    
    private init() {}
    
    func showCommentInput(detailId: String, replyUser: String, username: String, onDismiss: @escaping () -> Void) {
        self.detailId = detailId
        self.replyUser = replyUser
        self.username = username
        self.onDismiss = onDismiss
        self.isPresented = true
    }
    
    func dismiss() {
        isPresented = false
        onDismiss?()
        onDismiss = nil
    }
}
