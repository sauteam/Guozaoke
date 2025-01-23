//
//  SendPostView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI

struct SendPostView: View {
    @Binding var isPresented: Bool
    let sendSuccess: () -> Void

    @StateObject private var viewModel = PostListParser()
    @State private var selectedTopic: Node = Node(title: "IT技术", link: "/node/IT")
    @State private var title = ""
    @State private var content = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showingImagePicker = false
    
    @State private var isPosting = false
    @State private var postSuccess = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            Form {
                TextField("输入标题", text: $title)
                    .padding(.vertical)
                    .frame(height: 30)
                
                TextEditor(text: $content)
                    .frame(minHeight: 180)
                    .padding(.top)
                                
//                HStack {
//                    if let selectedImage = selectedImage {
//                        Image(uiImage: selectedImage)
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 100, height: 100)
//                            .clipped()
//                    } else {
//                        Text("没有选择图片")
//                            .foregroundColor(.gray)
//                    }
//                    Spacer()
//                    Button("选择图片") {
//                        showingImagePicker.toggle()
//                    }
//                }
                
                Picker("主题", selection: $selectedTopic) {
                    ForEach(viewModel.onlyNodes, id: \.self) { topic in
                        Text(topic.title)
                            .tag(topic.link)
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
                Button(action: {
                    if title.trim().isEmpty {
                        return
                    }
                    
                    if content.trim().isEmpty {
                        return
                    }
                    
                    Task {
                        await sendPost()
                    }
                }) {
                     if isPosting {
                        ProgressView()
                    } else {
                        Text("发布新主题")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(isPosting || title.isEmpty || content.isEmpty)
                .pickerStyle(DefaultPickerStyle())
            }
            .onAppear() {
                if !viewModel.hadNodeItemData {
                    viewModel.refresh(type: .hot)
                }
                
                if let postInfo = EditPost.getEditPost() {
                    title   = postInfo.title ?? ""
                    content = postInfo.content ?? ""
                }
            }
            .onDisappear() {
                if !content.isEmpty, !title.isEmpty {
                    let editPost = EditPost(title: title, content: content, topicId: selectedTopic.link)
                    EditPost.saveEditPost(editPost)
                }
            }
            .onReceive(viewModel.$onlyNodes) { nodes in
                if let firstTopic = nodes.randomElement() {
                    selectedTopic = firstTopic
               }
            }
            .listRowBackground(Color.clear)
            .navigationTitle("创建新主题")
            .navigationBarItems(trailing: Button("取消") {
                isPresented = false
            })
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    private func sendPost() async {
        isPosting = true
        do {
            let response = try await APIService.sendPost(url: selectedTopic.link.createPostUrl(), title: title, content: content)
            print("Response: \(response)")
            postSuccess = true
            isPresented = false
            content = ""
            title   = ""
            sendSuccess()
        } catch {
            isPosting = false
            errorMessage = "发布失败: \(error.localizedDescription)"
        }
    }
}

struct PlaceholderTextEditor: View {
    @State private var text: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("请输入内容...")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 0)
                    .padding(.vertical, 0)
            }
            TextEditor(text: $text)
                .padding(0)
        }
        .frame(minHeight: 150)
        .background(.clear)
        .cornerRadius(8)
        .padding()
    }
}

//#Preview {
//let topics = ["生活百科", "社会信息", "科学技术", "文化人文", "艺术时尚", "休闲娱乐", "社区管理"]
//    SendPostView()
//}


