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
    @State private var textEditorHeight: CGFloat = 40
    //var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 自适应输入框容器
            HStack(alignment: .bottom, spacing: 12) {
                // 输入框
                ZStack(alignment: .topLeading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    
                    // 占位符文本
                    if content.isEmpty {
                        Text(replyUser?.isEmpty == false ? "回复 \(replyUser ?? "")" : "写点什么...")
                            .foregroundColor(.secondary)
                            .subTitleFontStyle()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    
                    // 自适应文本输入框
                    TextEditor(text: $content)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($isFocused)
                        .subTitleFontStyle()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(height: textEditorHeight)
                        .onChange(of: content) { newValue in
                            updateTextEditorHeight()
                        }
                        .readSize { size in
                            let newHeight = max(40, min(120, size.height))
                            if abs(newHeight - textEditorHeight) > 1 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    textEditorHeight = newHeight
                                }
                            }
                        }
                }
                .frame(maxHeight: 120)
                
                // 发送按钮
                Button(action: {
                    if content.trim().isEmpty {
                        ToastView.warningToast("输入内容")
                        return
                    }
                    // 添加触觉反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    Task {
                        await sendComment()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(contentTextValid ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .shadow(color: contentTextValid ? Color.blue.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                        
                        if isPosting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(contentTextValid ? .white : .gray)
                                .scaleEffect(contentTextValid ? 1.0 : 0.8)
                        }
                    }
                }
                .disabled(isPosting || !contentTextValid)
                .scaleEffect(contentTextValid ? 1.0 : 0.9)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: contentTextValid)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPosting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 加载指示器
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("发送中...")
                        .subTitleFontStyle()
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .keyboardAware()
        .onAppear {
            if let comment = SendCommentInfo.getCommentInfo(username ?? ""), comment.detailId == getDetailId() {
                content = comment.content ?? ""
            } else {
                if let replyUser = replyUser, !replyUser.isEmpty {
                    content = replyUser
                }
            }
            self.isFocused = true
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
        let lines = content.components(separatedBy: .newlines).count
        let baseHeight: CGFloat = 40
        let lineHeight: CGFloat = 20
        let newHeight = baseHeight + CGFloat(max(0, lines - 1)) * lineHeight
        let clampedHeight = max(40, min(120, newHeight))
        
        if abs(clampedHeight - textEditorHeight) > 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                textEditorHeight = clampedHeight
            }
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
