//
//  SendPostView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI

struct SendPostView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTopic: Node?
    
    var postDetail: PostDetail?
    let sendSuccess: () -> Void
    private let defaultNode = Node(title: "IT技术", link: "/node/IT")
    @StateObject private var viewModel = PostListParser()
    @State private var title   = ""
    @State private var content = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showingImagePicker = false
    
    @State private var isPosting = false
    @State private var postSuccess = false
    @State private var errorMessage: String? = nil
    @FocusState private var isFocused: Bool
    @State private var isEditPost = false

    var body: some View {
        NavigationView {
            List {
                TextField("输入标题", text: $title)
                    .padding(.vertical)
                    .frame(height: 30)
                    .focused($isFocused)
                    .subTitleFontStyle()

                TextEditor(text: $content)
                    .frame(minHeight: 300)
                    .padding(.top)
                    .subTitleFontStyle()
                                
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
                    let bindNodes = viewModel.updateSendNode(selectedTopic ?? defaultNode)
                    ForEach(bindNodes, id: \.self) { node in
                        Text(node.title)
                            .tag(Optional(node))
                            .subTitleFontStyle()
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
                Button(action: {
                    hapticFeedback()
                    if title.trim().isEmpty || content.trim().isEmpty {
                        ToastView.warningToast("输入内容")
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
                            .listRowBackground(Color.clear)
                            .subTitleFontStyle()
                            .hapticOnTap()
                    }
                }
                .disabled(isPosting || title.isEmpty || content.isEmpty)
                .pickerStyle(DefaultPickerStyle())
                .buttonStyle(.plain)
                .listStyle(.plain)
            }
            .listRowBackground(Color.clear)
            .onAppear() {
                if !viewModel.hadNodeItemData {
                    viewModel.refreshPostList(type: .hot)
                }
                if let postDetail = postDetail  {
                    isEditPost.toggle()
                    selectedTopic = Node(title: postDetail.author.node, link: postDetail.nodeUrl)
                    title   = postDetail.title
                    content = postDetail.content
                    logger("[edit] post\(postDetail)")
                } else {
                    if let postInfo = EditPost.getEditPost() {
                        if postInfo.topicLink == selectedTopic?.link {
                            title   = postInfo.title ?? ""
                            content = postInfo.content ?? ""
                            selectedTopic = Node(title: postInfo.topicId ?? defaultNode.title, link: postInfo.topicLink ?? defaultNode.link)
                        }
                    }
                }
                
                if selectedTopic == nil, let firstTopic = viewModel.onlyHotNodes.randomElement() {
                    selectedTopic = firstTopic
                }
                self.isFocused = true
            }
            .onDisappear() {
                self.isFocused = false
                if !content.isEmpty, !title.isEmpty, !isEditPost {
                    let editPost = EditPost(title: title, content: content, topicId: selectedTopic?.title, topicLink: selectedTopic?.link)
                    EditPost.saveEditPost(editPost)
                }
            }
            .onReceive(viewModel.$onlyHotNodes) { nodes in
                if selectedTopic == nil, let firstTopic = nodes.randomElement() {
                    selectedTopic = firstTopic
               }
            }
            .navigationTitleStyle("创建新主题")
            .navigationBarItems(trailing: Button("关闭") {
                isPresented = false
            })
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    func clear() {
        content = ""
        title   = ""
    }
    
    private func sendPost() async {
        isPosting = true
        do {
            let response = try await APIService.sendPost(url: selectedTopic?.link.createPostUrl ?? defaultNode.link.createPostUrl, title: title, content: content)
            logger("Response: \(response)")
            postSuccess = true
            isPresented = false
            content = ""
            title   = ""
            ToastView.successToast("发送成功")
            hapticFeedback()
            sendSuccess()
            clear()
        } catch {
            isPosting = false
            errorMessage = "发布失败: \(error.localizedDescription)"
            ToastView.errorToast("发送失败: \(error.localizedDescription)")
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



