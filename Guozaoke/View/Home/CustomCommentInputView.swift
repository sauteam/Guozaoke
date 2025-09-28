//
//  Guozaoke
//
//  Created by scy on 2025/1/23.
//

import SwiftUI

struct CustomCommentInputView: View {
    let detailId: String
    let replyUser: String?
    let username: String?
    @Binding var isPresented: Bool
    let sendSuccess: () -> Void
    @StateObject private var viewModel = PostListParser()
    @State private var content = ""
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var commentInputManager = CommentInputManager.shared

    @State private var isPosting = false
    @State private var postSuccess = false
    @State private var errorMessage: String? = nil
    @FocusState private var isFocused: Bool
    @State private var textEditorHeight: CGFloat = 60
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 半透明背景遮罩
            Color.black.opacity(isAnimating ? 0.3 : 0.0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissView()
                }
                .animation(.easeInOut(duration: 0.3), value: isAnimating)
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color(.systemGray3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .onTapGesture {
                            isFocused = false
                        }
                    
                    HStack(spacing: 2) {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: textEditorHeight)
                            
                            if content.isEmpty {
                                Text(replyUser?.isEmpty == false ? "回复 \(replyUser ?? "")" : "写点什么...")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: $content)
                                .font(.system(size: 16))
                                .focused($isFocused)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(height: textEditorHeight - 8)
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
                        
                        Button(action: {
                            if contentTextValid && !isPosting {
                                Task {
                                    await sendComment()
                                }
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(contentTextValid && !isPosting ? .blue : .gray)
                                .frame(width: 25, height: 25)
                                .background(
                                    Circle()
                                        .fill(contentTextValid && !isPosting ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                        }
                        .disabled(!contentTextValid || isPosting)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 40) // 底部留空40以适应安全区域
                }
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(radius: 10)
                .frame(height: textEditorHeight + 60)
                .offset(y: isAnimating ? 0 : textEditorHeight + 100)
                .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: isAnimating)
            }
        }
        .onAppear {
            if let comment = SendCommentInfo.getCommentInfo(username ?? ""), comment.detailId == getDetailId() {
                content = comment.content ?? ""
            } else {
                if let replyUser = replyUser, !replyUser.isEmpty {
                    content = replyUser
                }
            }
            
            DispatchQueue.main.async {
                updateTextEditorHeight()
            }
            
            // 触发弹出动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isFocused = true
                }
            }
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
    
    private func updateTextEditorHeight() {
        let minHeight: CGFloat = 60
        let maxHeight: CGFloat = 400
        
        let font = UIFont.systemFont(ofSize: 16)
        let lineHeight: CGFloat = 22
        let verticalPadding: CGFloat = 8
        let containerWidth = UIScreen.main.bounds.width - 20 - 25 - 8 // 减去左右边距和发送按钮宽度及间距
        
        let textSize = content.size(withAttributes: [.font: font])
        let textWidth = textSize.width
        let autoWrapLines = textWidth > 0 ? max(1, Int(ceil(textWidth / containerWidth))) : 1
        let manualWrapLines = content.components(separatedBy: .newlines).count
        let totalLines = max(autoWrapLines, manualWrapLines)
        
        let calculatedHeight = max(minHeight, min(maxHeight, CGFloat(totalLines) * lineHeight + verticalPadding))+10
        
        logger("[CustomCommentInputView] 内容: '\(content)', 计算高度: \(calculatedHeight)")
        textEditorHeight = calculatedHeight
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
        return valid
    }
    
    private func dismissView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            commentInputManager.dismiss()
        }
    }
    
    private func getDetailId() -> String {
        var topicUrl = detailId
        if let result = topicUrl.components(separatedBy: "#").first {
            topicUrl = result
        }
        return topicUrl
    }
    
    private func sendComment() async {
        if !LoginStateChecker.isLogin {
            LoginStateChecker.LoginStateHandle()
            dismissView()
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
            dismissView()
            content = ""
            isPosting = false
        } catch {
            isPosting = false
            errorMessage = "发送失败: \(error.localizedDescription)"
            ToastView.errorToast("发送失败")
        }
    }
}

// 扩展用于圆角
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
