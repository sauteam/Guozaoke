//
//  Guozaoke
//
//  Created by scy on 2025/1/23.
//

import SwiftUI
import Kingfisher

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
    @State private var textEditorHeight: CGFloat = 44
    @State private var isAnimating = false
    
    // 图片上传与预览状态
    @State private var showingImagePicker: Bool = false
    @State private var isUploadingImage: Bool = false
    @State private var uploadProgressText: String = ""
    @State private var uploadedImages: [UploadedImageItem] = []
    @State private var previewItem: UploadedImageItem? = nil
    @State private var showNoImageHostAlert: Bool = false
    @State private var showImageHostSetting: Bool = false
    @State private var showEmojiAlert: Bool = false
    
    var body: some View {
        GeometryReader { proxy in
            let isDual = GKDisplayMetrics.isDualColumnDisplay(size: proxy.size)
            let safeTrailing: CGFloat = isDual ? 10 : 0
            let safeBottom = proxy.safeAreaInsets.bottom
            // 键盘弹起时输入框紧贴键盘（8pt），未弹起时避让底部安全区域
            let bottomPadding: CGFloat = isFocused ? 8 : max(safeBottom, 12)
            
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
                        // 拖拽指示器
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color(.systemGray3))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                            .onTapGesture {
                                isFocused = false
                            }
                        
                        // 已上传图片缩略图横向展示条
                        if !uploadedImages.isEmpty || isUploadingImage {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(uploadedImages) { item in
                                        ZStack(alignment: .topTrailing) {
                                            Button {
                                                isFocused = false
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
                                                            .placeholder { Color.gray.opacity(0.2) }
                                                            .fade(duration: 0.2)
                                                            .resizable()
                                                            .scaledToFill()
                                                    }
                                                }
                                                .frame(width: 56, height: 56)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            
                                            // 删除图片按钮
                                            Button {
                                                removeUploadedImage(item)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.7)))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                    
                                    if isUploadingImage {
                                        VStack(spacing: 4) {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("上传中...")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 56, height: 56)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                            }
                        }
                        
                        // 输入主工具栏：添加图片 + 输入框 + 发送按钮
                        HStack(alignment: .bottom, spacing: 8) {
                            // 图片上传按钮
                            Button {
                                checkAndPickImage()
                            } label: {
                                if isUploadingImage {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                        .frame(width: 34, height: 34)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            Circle()
                                                .fill(Color.blue.opacity(0.08))
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isUploadingImage)
                            
                            // 文本输入区
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
                                    .foregroundColor(.primary)
                                    .focused($isFocused)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .frame(height: max(36, textEditorHeight - 8))
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
                            
                            // 发送按钮
                            Button(action: {
                                if contentTextValid && !isPosting {
                                    if content.contains4ByteUnicode {
                                        showEmojiAlert = true
                                        return
                                    }
                                    Task {
                                        await sendComment()
                                    }
                                }
                            }) {
                                if isPosting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 34, height: 34)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(contentTextValid ? .white : .gray)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            Circle()
                                                .fill(contentTextValid ? Color.blue : Color.gray.opacity(0.12))
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!contentTextValid || isPosting)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, bottomPadding)
                    }
                    .frame(maxWidth: GKDisplayMetrics.comfortReadableWidth)
                    .background(Color(.systemBackground))
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
                    .offset(y: isAnimating ? 0 : textEditorHeight + 100)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: isAnimating)
                    .padding(.trailing, safeTrailing)
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
        .alert("未配置图片托管", isPresented: $showNoImageHostAlert) {
            Button("前往配置图床") {
                showImageHostSetting = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("评论上传图片需要先绑定 ImgURL API Token。绑定后即可直接上传图片并插入评论。")
        }
        .alert("评论不支持原生 Emoji", isPresented: $showEmojiAlert) {
            Button("清除 Emoji 并发送") {
                content = content.stripping4ByteUnicode
                Task {
                    await sendComment()
                }
            }
            Button("返回修改", role: .cancel) {}
        } message: {
            let emojis = content.fourByteCharacters.prefix(6).joined(separator: " ")
            Text("过早客服务端数据库字符集暂不支持原生 Emoji 表情（如 \(emojis)），直接提交会导致服务端 500 报错。\n\n是否为您自动清除 Emoji 后继续发送？")
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
        .onAppear {
            if let comment = SendCommentInfo.getCommentInfo(username ?? ""), comment.detailId == getDetailId() {
                content = comment.content ?? ""
                extractImagesFromContent(content)
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
    
    // MARK: - 图片上传与交互
    private func checkAndPickImage() {
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
                    
                    // 自动插入 Markdown 到评论正文
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
            
            if failCount == 0 {
                ToastView.successToast(total == 1 ? "图片已添加至评论" : "已添加 \(total) 张图片至评论")
            } else if successCount > 0 {
                ToastView.warningToast("\(successCount) 张成功，\(failCount) 张失败: \(lastErrorMsg)")
            } else {
                ToastView.errorToast("图片上传失败: \(lastErrorMsg)")
            }
        }
    }
    
    private func removeUploadedImage(_ item: UploadedImageItem) {
        uploadedImages.removeAll(where: { $0.id == item.id })
        let md = "![图片](\(item.url))"
        if content.contains(md) {
            content = content.replacingOccurrences(of: md, with: "")
        }
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
    
    private func updateTextEditorHeight() {
        let minHeight: CGFloat = 44
        let maxHeight: CGFloat = 200
        
        let font = UIFont.systemFont(ofSize: 16)
        let lineHeight: CGFloat = 22
        let verticalPadding: CGFloat = 8
        let availableWidth = min(GKDisplayMetrics.deviceScreenBounds.width, GKDisplayMetrics.comfortReadableWidth)
        let containerWidth = max(availableWidth - 20 - 34 - 34 - 16, 120)
        
        let textSize = content.size(withAttributes: [.font: font])
        let textWidth = textSize.width
        let autoWrapLines = textWidth > 0 ? max(1, Int(ceil(textWidth / containerWidth))) : 1
        let manualWrapLines = content.components(separatedBy: .newlines).count
        let totalLines = max(autoWrapLines, manualWrapLines)
        
        let calculatedHeight = max(minHeight, min(maxHeight, CGFloat(totalLines) * lineHeight + verticalPadding))
        textEditorHeight = calculatedHeight
    }
    
    private var contentTextValid: Bool {
        if !uploadedImages.isEmpty {
            return true
        }
        var valid = false
        let text = content.trim()
        if let replyUser = replyUser, !replyUser.isEmpty, content != replyUser {
            if text.count != replyUser.count - 1 {
                valid = true
            }
        }
        
        if replyUser?.isEmpty ?? true {
            valid = text.count > 0
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
        return topicUrl.postDetailUrl
    }
    
    private func sendComment() async {
        if !LoginStateChecker.isLogin {
            LoginStateChecker.LoginStateHandle()
            dismissView()
            return
        }

        isPosting = true
        do {
            let targetUrl = getDetailId()
            guard !targetUrl.isEmpty else {
                isPosting = false
                return
            }
            let response = try await APIService.sendComment(url: targetUrl, content: content)
            logger("Response: \(response)")
            postSuccess = true
            sendSuccess()
            ToastView.successToast("评论成功")
            dismissView()
            content = ""
            uploadedImages = []
            isPosting = false
        } catch {
            isPosting = false
            errorMessage = "发送失败: \(error.localizedDescription)"
            ToastView.errorToast("发送失败")
        }
    }
}


