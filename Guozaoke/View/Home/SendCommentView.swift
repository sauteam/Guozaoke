//
//  Guozaoke
//
//  Created by scy on 2025/1/23.
//

import SwiftUI

struct SendCommentView: View {
    let detailId: String
    let replyUser: String?
    let username: String?
    @Binding var isPresented: Bool
    let sendSuccess: () -> Void
    @StateObject private var viewModel = PostListParser()
    @State private var content = ""
    @Environment(\.dismiss) var dismiss

    @State private var isPosting = false
    @State private var postSuccess = false
    @State private var errorMessage: String? = nil
    @FocusState private var isFocused: Bool
    @State private var textEditorHeight: CGFloat = 60
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .frame(height: textEditorHeight)
                
                if content.isEmpty {
                    Text(replyUser?.isEmpty == false ? "回复 \(replyUser ?? "")" : "写点什么...")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: textEditorHeight)
                    .onChange(of: content) { _ in
                        updateTextEditorHeight()
                    }
                    .onSubmit {
                        if contentTextValid && !isPosting {
                            Task {
                                await sendComment()
                            }
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("发送中...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            if let comment = SendCommentInfo.getCommentInfo(username ?? ""), comment.detailId == getDetailId() {
                content = comment.content ?? ""
            } else {
                if let replyUser = replyUser, !replyUser.isEmpty {
                    content = replyUser
                }
            }
            self.isFocused = true
            updateTextEditorHeight()
        }
        .onDisappear() {
            self.isFocused = false
            if contentTextValid, !getDetailId().isEmpty, !isPosting {
                let comment = SendCommentInfo(content: content, detailId: getDetailId(), username: username)
                SendCommentInfo.saveComment(comment)
            } else {
                if let comment = SendCommentInfo.getCommentInfo(username ?? ""), comment.detailId == getDetailId() {
                    SendCommentInfo.removeComment(username ?? "")
                }
            }
        }
    }
    
    func clear() {
        content = ""
    }
    
    private func updateTextEditorHeight() {
        let minHeight: CGFloat = 60
        let maxHeight: CGFloat = 200
        
        // 计算文本行数
        let lines = content.components(separatedBy: .newlines).count
        let lineHeight: CGFloat = 20
        let padding: CGFloat = 16 // 上下padding
        
        let calculatedHeight = max(minHeight, min(maxHeight, CGFloat(lines) * lineHeight + padding))
        
        withAnimation(.easeInOut(duration: 0.2)) {
            textEditorHeight = calculatedHeight
        }
    }
    
    private var contentTextValid: Bool {
        var valid = false
        let text = content.trim()
        if !replyUser.isEmpty, content != replyUser {
            if text.count != (replyUser?.count ?? 0)-1 {
                valid = true
            }
        }
        
        if replyUser.isEmpty {
            if text.count == 0 {
                valid = false
            } else {
                valid = true
            }
        }
        return  valid
    }
    
    private func closeView() {
        isPresented = false
        dismiss()
    }
    
    private func getDetailId() -> String {
        var topicUrl   = detailId
        if let result = topicUrl.components(separatedBy: "#").first {
            topicUrl  = result
        }
        return topicUrl
    }
    
    private func sendComment() async {
        if !LoginStateChecker.isLogin {
            LoginStateChecker.LoginStateHandle()
            closeView()
            return
        }

        isPosting = true
        do {
            guard getDetailId().isEmpty == false else {
                return
            }
            let response = try await APIService.sendComment(url: APIService.baseUrlString + getDetailId(), content: content)
            logger("Response: \(response)")
            postSuccess = true
            sendSuccess()
            ToastView.successToast("评论成功")
            closeView()
            clear()
        } catch {
            isPosting = false
            errorMessage = "发送失败: \(error.localizedDescription)"
            ToastView.errorToast("发送失败")
        }
    }
}
