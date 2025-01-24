//
//  SendCommentView.swift
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
    
    @State private var isPosting = false
    @State private var postSuccess = false
    @State private var errorMessage: String? = nil
    @FocusState private var isFocused: Bool

    
    var body: some View {
        NavigationView {
            Form {
                Text("输入内容")
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
                    }
                }
                .disabled(isPosting || content.isEmpty)
                .pickerStyle(DefaultPickerStyle())
            }
            .onAppear {
                if let replyUser = replyUser, !replyUser.isEmpty {
                    content = "@" + replyUser + " "
                }
                self.isFocused = true
            }
            .onDisappear() {
                self.isFocused = false
            }
            .listRowBackground(Color.clear)
            .navigationTitle("创建新的回复")
            .navigationBarItems(trailing: Button("取消") {
                isPresented = false
            })
        }
    }
    
    private func getDetailId() -> String {
        var topicUrl   = detailId
        if let result = topicUrl.components(separatedBy: "#").first {
            topicUrl  = result
        }
        return topicUrl
    }
    
    
    private func sendComment() async {
        isPosting = true
        do {
            guard getDetailId().isEmpty == false else {
                return
            }
            let response = try await APIService.sendComment(url: APIService.baseUrlString + getDetailId(), content: content)
            print("Response: \(response)")
            postSuccess = true
            isPresented = false
            sendSuccess()
        } catch {
            isPosting = false
            errorMessage = "发布失败: \(error.localizedDescription)"
        }
    }

}
