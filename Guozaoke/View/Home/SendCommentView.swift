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
    //var onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    if content.trim().isEmpty {
                        ToastView.warningToast("输入内容")
                        return
                    }
                    Task {
                        await sendComment()
                    }
                }) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Text("回复")
                            .frame(maxWidth: 60, minHeight: 25)
                            .foregroundColor(Color.white)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .fontStyle(fontName: titleFontName, fontSize: 16)
                    }
                }
                .disabled(isPosting || !contentTextValid)
                .padding(.trailing, 20)
                .padding(.top, 5)
            }

            
            TextEditor(text: $content)
                .frame(minHeight: 100)
                .focused($isFocused)
                .padding(.top, -8)
                .subTitleFontStyle()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
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
            print("Response: \(response)")
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
