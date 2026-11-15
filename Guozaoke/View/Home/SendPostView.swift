//
//  SendPostView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI
import Kingfisher

struct UploadedImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let thumbUrl: String
    var localImage: UIImage? = nil
}

struct SendPostView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTopic: Node?
    
    var postDetail: PostDetail?
    let sendSuccess: () -> Void
    private let defaultNode = Node(title: "IT技术", link: "/node/IT")
    @StateObject private var viewModel = PostListParser()
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var originalTitle: String = ""
    @State private var originalContent: String = ""
    
    @State private var showingImagePicker: Bool = false
    @State private var isUploadingImage: Bool = false
    @State private var uploadProgressText: String = ""
    @State private var uploadedImages: [UploadedImageItem] = []
    @State private var previewItem: UploadedImageItem? = nil
    @State private var showNoImageHostAlert: Bool = false
    @State private var showImageHostSetting: Bool = false
    
    // 编辑与预览模式切换：0: 编辑, 1: 预览
    @State private var editorTab: Int = 0
    
    @State private var isPosting: Bool = false
    @State private var postSuccess: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var isFocused: Bool
    @State private var isEditPost: Bool = false
    @State private var isLoadingEditData: Bool = false
    
    // 关闭二次确认弹窗
    @State private var showDiscardAlert: Bool = false
    @State private var showEmojiAlert: Bool = false

    private var isModified: Bool {
        if isEditPost {
            return title != originalTitle || content != originalContent || !uploadedImages.isEmpty
        } else {
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   !uploadedImages.isEmpty
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoadingEditData {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在拉取原始编辑内容...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.08))
                }
                
                if editorTab == 0 {
                    List {
                    Section {
                        TextField("输入标题", text: $title)
                            .padding(.vertical, 4)
                            .focused($isFocused)
                            .subTitleFontStyle()
                    }
                    
                    Section {
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("输入正文，支持 Markdown 语法...")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .subTitleFontStyle()
                            }
                            TextEditor(text: $content)
                                .frame(minHeight: 220)
                                .subTitleFontStyle()
                        }
                    }
                    
                    // 已上传图片展示与预览区域
                    if !uploadedImages.isEmpty || isUploadingImage {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("已上传图片 (\(uploadedImages.count))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if isUploadingImage {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("正在上传至图床...")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(uploadedImages) { item in
                                            ZStack(alignment: .topTrailing) {
                                                Button {
                                                    hapticFeedback()
                                                    previewItem = item
                                                } label: {
                                                    Group {
                                                        if let local = item.localImage {
                                                            Image(uiImage: local)
                                                                .resizable()
                                                                .scaledToFill()
                                                        } else {
                                                            let displayUrl = item.thumbUrl.isEmpty ? item.url : item.thumbUrl
                                                            KFImage(cleanURL(displayUrl))
                                                                .placeholder {
                                                                    Color.gray.opacity(0.2)
                                                                }
                                                                .fade(duration: 0.2)
                                                                .resizable()
                                                                .scaledToFill()
                                                        }
                                                    }
                                                    .frame(width: 76, height: 76)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                                
                                                // 点击删除图片
                                                Button {
                                                    hapticFeedback()
                                                    removeUploadedImage(item)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                                }
                                                .offset(x: 5, y: -5)
                                            }
                                        }
                                    }
                                    .padding(.top, 6)
                                    .padding(.trailing, 8)
                                    .padding(.bottom, 4)
                                    .padding(.leading, 2)
                                }
                                Text("提示：点击缩略图可全屏无损预览大图（支持手势缩放与拖动）；图片已生成 Markdown 插入正文。")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section {
                        Picker("所属节点", selection: $selectedTopic) {
                            let bindNodes = viewModel.updateSendNode(selectedTopic ?? defaultNode)
                            ForEach(bindNodes, id: \.self) { node in
                                Text(node.title)
                                    .tag(Optional(node))
                                    .subTitleFontStyle()
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                    }
                    
                    Section {
                        Button(action: {
                            submitAction()
                        }) {
                            if isPosting {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                            } else {
                                let canSubmit = !title.trim().isEmpty && !content.trim().isEmpty
                                Text(isEditPost ? "保存修改" : "发布新主题")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(canSubmit ? Color.blue : Color.blue.opacity(0.5))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .subTitleFontStyle()
                                    .contentShape(Rectangle())
                            }
                        }
                        .disabled(isPosting || title.trim().isEmpty || content.trim().isEmpty)
                        .buttonStyle(.borderless)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                postPreviewView
            }
                
                // 底部编辑辅助工具栏
                editorBottomBar
            }
            .navigationTitle(isEditPost ? "编辑主题" : "创建新主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        handleClose()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $editorTab) {
                        Text("编辑").tag(0)
                        Text("预览").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        submitAction()
                    }) {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text(isEditPost ? "保存" : "发布")
                                .fontWeight(.semibold)
                                .foregroundColor(title.trim().isEmpty || content.trim().isEmpty ? .gray.opacity(0.4) : .blue)
                        }
                    }
                    .disabled(isPosting || title.trim().isEmpty || content.trim().isEmpty)
                }
            }
            .alert("放弃本次编辑？", isPresented: $showDiscardAlert) {
                Button("放弃退出", role: .destructive) {
                    isPresented = false
                }
                Button("继续编辑", role: .cancel) {}
            } message: {
                Text("当前输入或修改的内容尚未保存，退出后更改将不会保留。")
            }
            .alert("社区不支持原生 Emoji", isPresented: $showEmojiAlert) {
                Button("清除 Emoji 并继续") {
                    title = title.stripping4ByteUnicode
                    content = content.stripping4ByteUnicode
                    Task {
                        await sendPost()
                    }
                }
                Button("返回修改", role: .cancel) {}
            } message: {
                let emojis = (title + content).fourByteCharacters.prefix(6).joined(separator: " ")
                Text("过早客服务端数据库字符集暂不支持原生 Emoji 表情（如 \(emojis)），直接提交会导致服务端 500 报错。\n\n是否为您自动清除 Emoji 后继续发布？")
            }
            .alert("未配置图片托管", isPresented: $showNoImageHostAlert) {
                Button("前往配置图床", role: .none) {
                    showImageHostSetting = true
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("在帖子中上传图片需要先绑定 ImgURL API Token。绑定后即可直接上传图片并插入正文。")
            }
            .sheet(isPresented: $showImageHostSetting) {
                NavigationView {
                    ImageHostSettingView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("完成") {
                                    showImageHostSetting = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                MultiImagePicker(maxSelectionCount: 9) { images in
                    handleImagesPicked(images)
                }
            }
            .fullScreenCover(item: $previewItem) { item in
                ImagePreviewView(
                    urlString: item.url,
                    image: item.localImage,
                    onDismiss: {
                        previewItem = nil
                    }
                )
            }
            .onAppear() {
                setupInitialData()
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
        }
    }
    
    // MARK: - 底部快捷工具栏
    private var editorBottomBar: some View {
        HStack(spacing: 14) {
            // 上传图片按钮（支持多张图片批量上传）
            Button {
                checkAndPickImage()
            } label: {
                HStack(spacing: 4) {
                    if isUploadingImage {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(uploadProgressText.isEmpty ? "上传中..." : uploadProgressText)
                            .font(.footnote)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 15))
                        Text("上传图片")
                            .font(.footnote)
                    }
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .disabled(isUploadingImage)
            
            // 常用 Markdown 辅助
            Button {
                hapticFeedback()
                insertMarkdownLink()
            } label: {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Button {
                hapticFeedback()
                content += "\n```\n\n```"
            } label: {
                Image(systemName: "curlybraces")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Button {
                hapticFeedback()
                content += "\n> "
            } label: {
                Image(systemName: "quote.opening")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 模式切换按钮（编辑 / 预览）
            Button {
                hapticFeedback()
                withAnimation(.easeInOut(duration: 0.2)) {
                    editorTab = (editorTab == 0 ? 1 : 0)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: editorTab == 0 ? "eye" : "pencil")
                        .font(.system(size: 13))
                    Text(editorTab == 0 ? "预览" : "编辑")
                        .font(.footnote)
                }
                .foregroundColor(editorTab == 1 ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(editorTab == 1 ? Color.blue : Color(UIColor.tertiarySystemFill))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            
            Text("\(content.count) 字")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - 帖子发布/编辑效果实时预览
    private var postPreviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 顶部节点与状态徽章
                HStack(spacing: 8) {
                    Text(selectedTopic?.title ?? defaultNode.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.caption2)
                        Text("实时排版预览")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                // 标题
                Text(title.trim().isEmpty ? "（未输入标题）" : title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(title.trim().isEmpty ? .secondary.opacity(0.6) : .primary)
                    .textSelection(.enabled)
                
                // 作者信息卡片模拟
                HStack(spacing: 10) {
                    if let avatarUrl = AccountState.getAccount()?.avatar, !avatarUrl.isEmpty {
                        KFImage(cleanURL(avatarUrl))
                            .placeholder {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.blue.opacity(0.6))
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 34, height: 34)
                            .foregroundColor(.blue.opacity(0.6))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        let name = AccountState.displayName.isEmpty ? "我" : AccountState.displayName
                        Text(name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("将在发布后公开呈现 · 刚刚")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                // 正文 Markdown 渲染
                if content.trim().isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.document")
                            .font(.system(size: 38))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("暂无正文内容\n切换至「编辑」编写 Markdown 语法或插入图片")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    MarkdownTextView(content: content)
                        .textSelection(.enabled)
                }
                
                Spacer(minLength: 40)
            }
            .padding(16)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 交互与逻辑方法
    private func handleClose() {
        hapticFeedback()
        if isModified {
            showDiscardAlert = true
        } else {
            isPresented = false
        }
    }
    
    private func checkAndPickImage() {
        hapticFeedback()
        Task {
            let (bound, _) = await APIService.checkImageHostBound()
            if bound {
                showingImagePicker = true
            } else {
                showNoImageHostAlert = true
            }
        }
    }
    
    private func handleImagesPicked(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        isUploadingImage = true
        let total = images.count
        
        Task {
            var successCount = 0
            var failCount = 0
            var lastErrorMsg = ""
            
            for (index, image) in images.enumerated() {
                uploadProgressText = "(\(index + 1)/\(total))"
                do {
                    let (imgUrl, thumbUrl) = try await APIService.uploadImageToHost(image: image)
                    let item = UploadedImageItem(url: imgUrl, thumbUrl: thumbUrl, localImage: image)
                    uploadedImages.append(item)
                    
                    // 自动插入 Markdown 到正文末尾
                    let md = "\n![图片](\(imgUrl))\n"
                    content += md
                    successCount += 1
                } catch {
                    failCount += 1
                    lastErrorMsg = error.localizedDescription
                }
            }
            
            isUploadingImage = false
            uploadProgressText = ""
            hapticFeedback()
            
            if failCount == 0 {
                ToastView.successToast(total == 1 ? "图片已上传并插入正文" : "已成功上传 \(total) 张图片并插入正文")
            } else if successCount > 0 {
                ToastView.warningToast("\(successCount) 张上传成功，\(failCount) 张失败: \(lastErrorMsg)")
            } else {
                ToastView.errorToast("图片上传失败: \(lastErrorMsg)")
            }
        }
    }
    
    private func removeUploadedImage(_ item: UploadedImageItem) {
        uploadedImages.removeAll(where: { $0.id == item.id })
        // 尝试从正文中移除对应的 markdown 格式
        let md = "![图片](\(item.url))"
        if content.contains(md) {
            content = content.replacingOccurrences(of: md, with: "")
        }
    }
    
    private func insertMarkdownLink() {
        content += "[链接文字](https://)"
    }
    
    private func cleanURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("//") {
            return URL(string: "https:" + trimmed)
        } else if trimmed.hasPrefix("/") {
            return URL(string: APIService.baseUrlString + trimmed)
        }
        return URL(string: trimmed)
    }
    
    private func extractImagesFromContent(_ text: String) {
        let pattern = #"!\[.*?\]\((https?:\/\/[^\s\)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        for match in results {
            if match.numberOfRanges > 1 {
                let urlRange = match.range(at: 1)
                let imgUrl = nsString.substring(with: urlRange)
                if !uploadedImages.contains(where: { $0.url == imgUrl }) {
                    uploadedImages.append(UploadedImageItem(url: imgUrl, thumbUrl: imgUrl, localImage: nil))
                }
            }
        }
    }
    
    private func setupInitialData() {
        if !viewModel.hadNodeItemData {
            viewModel.refreshPostList(type: .hot)
        }
        if let postDetail = postDetail {
            isEditPost = true
            selectedTopic = Node(title: postDetail.author.node, link: postDetail.nodeUrl)
            title = postDetail.title
            content = postDetail.content
            originalTitle = postDetail.title
            originalContent = postDetail.content
            extractImagesFromContent(postDetail.content)
            
            // 异步从网页 /t/edit/{id} 拉取真实的未编译 Markdown 源码
            isLoadingEditData = true
            Task {
                if let raw = try? await APIService.fetchEditTopic(topicId: postDetail.id) {
                    if !raw.title.isEmpty {
                        self.title = raw.title
                        self.originalTitle = raw.title
                    }
                    if !raw.content.isEmpty {
                        self.content = raw.content
                        self.originalContent = raw.content
                        self.extractImagesFromContent(raw.content)
                    }
                }
                isLoadingEditData = false
            }
        } else {
            if let postInfo = EditPost.getEditPost() {
                if postInfo.topicLink == selectedTopic?.link {
                    title = postInfo.title ?? ""
                    content = postInfo.content ?? ""
                    originalTitle = title
                    originalContent = content
                    extractImagesFromContent(content)
                    selectedTopic = Node(title: postInfo.topicId ?? defaultNode.title, link: postInfo.topicLink ?? defaultNode.link)
                }
            }
        }
        
        if selectedTopic == nil, let firstTopic = viewModel.onlyHotNodes.randomElement() {
            selectedTopic = firstTopic
        }
        self.isFocused = true
    }
    
    private func submitAction() {
        hapticFeedback()
        if title.trim().isEmpty || content.trim().isEmpty {
            ToastView.warningToast("请输入标题和内容")
            return
        }
        if title.contains4ByteUnicode || content.contains4ByteUnicode {
            showEmojiAlert = true
            return
        }
        Task {
            await sendPost()
        }
    }
    
    private func sendPost() async {
        isPosting = true
        do {
            let nodeSlug = selectedTopic?.link.nodeSlug ?? defaultNode.link.nodeSlug
            if isEditPost, let detail = postDetail {
                _ = try await APIService.updatePost(
                    topicId: detail.id,
                    title: title,
                    content: content,
                    nodeSlug: nodeSlug
                )
                isPosting = false
                postSuccess = true
                ToastView.successToast("主题修改成功")
                hapticFeedback()
                isPresented = false
                sendSuccess()
            } else {
                let response = try await APIService.sendPost(
                    url: selectedTopic?.link.createPostUrl ?? defaultNode.link.createPostUrl,
                    title: title,
                    content: content,
                    nodeSlug: nodeSlug
                )
                logger("Response: \(response)")
                isPosting = false
                postSuccess = true
                ToastView.successToast("发布成功")
                hapticFeedback()
                isPresented = false
                content = ""
                title = ""
                sendSuccess()
            }
        } catch {
            isPosting = false
            errorMessage = "操作失败: \(error.localizedDescription)"
            ToastView.errorToast("失败: \(error.localizedDescription)")
        }
    }
}
