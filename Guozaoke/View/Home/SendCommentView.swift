//
//  Guozaoke
//
//  Created by scy on 2025/1/23.
//

import SwiftUI

struct SendCommentView: View {
    let detailId: String
    let replyUser: String?
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
        NavigationView {
            Form {
                TextEditor(text: $content)
                    .frame(minHeight: 180)
                    .padding(.top)
                    .focused($isFocused)
                                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
                Button(action: {
                    if content.trim().isEmpty {
                        ToastView.toastText("输入内容")
                        return
                    }
                    Task {
                        await sendComment()
                    }
                }) {
                     if isPosting {
                        ProgressView()
                    } else {
                        Text("创建新的回复")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .listRowBackground(Color.clear)
                    }
                }
                .disabled(isPosting || !contentTextValid)
                .pickerStyle(DefaultPickerStyle())
                .buttonStyle(.plain)
                .listStyle(.plain)

            }
            .onAppear {
                if let replyUser = replyUser, !replyUser.isEmpty {
                    content = replyUser
                }
                self.isFocused = true
            }
            .onDisappear() {
                self.isFocused = false
            }
            .listRowBackground(Color.clear)
            .navigationTitle("创建新的回复")
            .navigationBarItems(trailing: Button("关闭") {
                self.isFocused = false
                closeView()
                /// isPresented 是 Sheet，检查 @Binding 是否正确传递
                ///  如果 isPresented 是 NavigationStack，用 dismiss()
                ///onDismiss()
            })
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
            print("Response: \(response)")
            postSuccess = true
            sendSuccess()
            ToastView.toastText("评论成功")
            closeView()
        } catch {
            isPosting = false
            errorMessage = "发送失败: \(error.localizedDescription)"
            ToastView.toastText("发送失败")
        }
    }

}
