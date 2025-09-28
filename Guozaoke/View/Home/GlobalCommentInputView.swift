//
//  GlobalCommentInputView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/27.
//

import SwiftUI

struct GlobalCommentInputView: View {
    @ObservedObject private var commentInputManager = CommentInputManager.shared
    
    var body: some View {
        Group {
            if commentInputManager.isPresented {
                CustomCommentInputView(
                    detailId: commentInputManager.detailId,
                    replyUser: commentInputManager.replyUser,
                    username: commentInputManager.username,
                    isPresented: $commentInputManager.isPresented,
                    sendSuccess: {
                        commentInputManager.dismiss()
                    }
                )
            }
        }
    }
}
