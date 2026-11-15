//
//  KFImageView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/13.
//

import SwiftUI
import Kingfisher

// MARK: - Kingfisher 普通图片

struct KFImageView: View {
    let url: String?
    var placeholder: AnyView
    
    init(
        _ url: String?,
        placeholder: AnyView = AnyView(Color.gray.opacity(0.3))
    ) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        let cleanUrl: URL? = {
            guard let raw = url?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            if raw.hasPrefix("//") {
                return URL(string: "https:" + raw)
            } else if raw.hasPrefix("/") {
                return URL(string: APIService.baseUrlString + raw)
            }
            return URL(string: raw)
        }()
        
        KFImage(cleanUrl)
            .placeholder { progress in
                placeholder
            }
            .fade(duration: 0.25)
            .resizable()
            .cacheOriginalImage()
            .diskCacheExpiration(.days(30)) // 设置磁盘缓存有效期
            .memoryCacheExpiration(.days(7)) // 设置内存缓存有效期
    }
}

// MARK: - 扩展
extension KFImageView {
    func avatar(size: CGFloat = 30) -> some View {
        self.frame(width: size, height: size)
            //.clipShape(Circle())
            .cornerRadius(8)
    }
    
    func thumbnail(width: CGFloat, height: CGFloat) -> some View {
        self.frame(width: width, height: height)
            .cornerRadius(8)
    }
    
    func adaptiveHeight(_ height: CGFloat) -> some View {
        self.frame(maxWidth: .infinity)
            .frame(height: height)
            .cornerRadius(8)
    }
}



// MARK: - Kingfisher 大图优化
/// 大图显示优化
struct OptimizedImageView: View {
    let urlString: String
    var contentMode: SwiftUI.ContentMode = .fill
    var autoResize: Bool = true
    var showPreview: Bool = true
    
    @State private var isPreviewPresented = false
    @State private var isEmoji: Bool = false
    @State private var isAnimated: Bool = false
    @Environment(\.displayScale) private var displayScale
    
    // 检查是否为表情图片
    private func checkIsEmoji(_ urlString: String) -> Bool {
        let emojiKeywords = ["emoji", "face", "sticker", "表情", "face/", "emot", "gif"]
        let lowercasedUrl = urlString.lowercased()
        
        if lowercasedUrl.hasSuffix(".gif") {
            isAnimated = true
        }
        
        return emojiKeywords.contains { lowercasedUrl.contains($0) }
    }
    
    // 计算表情尺寸
    private func calculateEmojiSize() -> CGSize {
        // GIF 表情稍大一些
        let size: CGFloat = isAnimated ? 25 : 20
        return CGSize(width: size, height: size)
    }
    
    // 计算实际显示尺寸
    private func calculateSize(for geometry: GeometryProxy) -> CGSize {
        if isEmoji {
            return calculateEmojiSize()
        }
        if autoResize {
            return CGSize(width: geometry.size.width, height: geometry.size.height)
        }
        return CGSize(width: 300, height: 300)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let targetSize = calculateSize(for: geometry)
            
            Group {
                if isAnimated {
                    KFAnimatedImage(URL(string: urlString))
                        .configure { view in
                            view.framePreloadCount = 3 // 预加载帧数
                        }
                        .placeholder { _ in
                            placeholderView(for: targetSize)
                        }
                        .loadDiskFileSynchronously()
                        .cacheMemoryOnly()
                        .fade(duration: 0.25)
                        .forceRefresh(true)
                        .scaleFactor(displayScale)
                } else {
                    KFImage.url(URL(string: urlString))
                        .onSuccess { result in
                            // 通过图片尺寸判断是否为表情
                            let image = result.image
                            if image.size.width <= 100 && image.size.height <= 100 {
                                isEmoji = true
                            }
                        }
                        .placeholder { _ in
                            placeholderView(for: targetSize)
                        }
                        .setProcessor(DownsamplingImageProcessor(size: targetSize))
                        .loadDiskFileSynchronously()
                        .cacheMemoryOnly()
                        .fade(duration: 0.25)
                        .cancelOnDisappear(true)
                }
            }
            .frame(width: targetSize.width, height: targetSize.height)
            .aspectRatio(contentMode: contentMode)
            .clipped()
            .onTapGesture {
                if showPreview && !isEmoji {
                    isPreviewPresented = true
                }
            }
//            .fullScreenCover(isPresented: $isPreviewPresented) {
//                ImagePreviewView(urlString: urlString)
//            }
        }
        .frame(
            width: isEmoji ? calculateEmojiSize().width : nil,
            height: isEmoji ? calculateEmojiSize().height : nil
        )
        .onAppear {
            isEmoji = checkIsEmoji(urlString)
        }
    }
    
    @ViewBuilder
    private func placeholderView(for size: CGSize) -> some View {
        if isEmoji {
            Color.clear
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - 全屏大图交互预览视图（自适应正确尺寸、支持缩放/拖动与本地图片）
struct ImagePreviewView: View {
    var urlString: String? = nil
    var image: UIImage? = nil
    var onDismiss: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls: Bool = true
    
    private var isAnimated: Bool {
        guard let url = urlString?.lowercased() else { return false }
        return url.hasSuffix(".gif") || url.contains(".gif?")
    }
    
    private var cleanURL: URL? {
        guard let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        } else if raw.hasPrefix("/") {
            return URL(string: APIService.baseUrlString + raw)
        }
        return URL(string: raw)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            
            ZStack {
                // 纯黑沉浸式背景
                Color.black
                    .edgesIgnoringSafeArea(.all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                    }
                
                // 图片主体：保持原始长宽比自适应屏幕，支持捏合缩放与拖动平移
                imageContent(screenSize: screenSize)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            // 双指捏合缩放（1.0x ~ 5.0x）
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale <= 1.0 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                },
                            // 拖动手势：放大时漫游平移，未放大时支持下拉拖拽跟手关闭
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        let delta = CGSize(
                                            width: value.translation.width - lastOffset.width,
                                            height: value.translation.height - lastOffset.height
                                        )
                                        lastOffset = value.translation
                                        offset = CGSize(
                                            width: offset.width + delta.width,
                                            height: offset.height + delta.height
                                        )
                                    } else {
                                        offset = CGSize(width: 0, height: max(0, value.translation.height))
                                    }
                                }
                                .onEnded { value in
                                    lastOffset = .zero
                                    if scale <= 1.0 {
                                        if value.translation.height > 90 {
                                            closeView()
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                offset = .zero
                                            }
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            clampOffset(screenSize: screenSize)
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        // 双击放大 2.5x 或还原
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                            } else {
                                scale = 2.5
                            }
                        }
                    }
                
                // 顶部关闭按钮（常驻控制条）
                if showControls {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                closeView()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(.top, 44)
                                    .padding(.trailing, 20)
                            }
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    @ViewBuilder
    private func imageContent(screenSize: CGSize) -> some View {
        if isAnimated, let url = cleanURL {
            KFAnimatedImage(url)
                .configure { view in
                    view.framePreloadCount = 3
                }
                .placeholder { _ in
                    if let localImg = image {
                        Image(uiImage: localImg)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .scaledToFit()
                .frame(maxWidth: screenSize.width, maxHeight: screenSize.height)
        } else if let localImg = image {
            Image(uiImage: localImg)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: screenSize.width, maxHeight: screenSize.height)
        } else if let url = cleanURL {
            KFImage(url)
                .placeholder { _ in
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .fade(duration: 0.2)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: screenSize.width, maxHeight: screenSize.height)
        } else {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    private func clampOffset(screenSize: CGSize) {
        let maxOffsetX = max(0, (screenSize.width * (scale - 1)) / 2)
        let maxOffsetY = max(0, (screenSize.height * (scale - 1)) / 2)
        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
    }
    
    private func closeView() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

//// MARK: - 使用示例
//struct ContentView: View {
//    let imageUrl = URL(string: "https://example.com/image.jpg")
//    
//    var body: some View {
//        OptimizedImageView(
//            url: imageUrl,
//            contentMode: .fill,
//            autoResize: true,
//            showPreview: true
//        )
//        .frame(height: 200)
//        .onAppear {
//            // 初始化缓存管理器
//            _ = ImageCacheManager.shared
//        }
//    }
//}

//// MARK: - 图片网格示例
//struct ImageGridView: View {
//    let imageUrls: [URL?] = [
//        URL(string: "https://example.com/image1.jpg"),
//        URL(string: "https://example.com/image2.jpg"),
//        URL(string: "https://example.com/image3.jpg"),
//    ]
//    
//    var body: some View {
//        ScrollView {
//            LazyVGrid(columns: [
//                GridItem(.flexible()),
//                GridItem(.flexible()),
//                GridItem(.flexible())
//            ], spacing: 8) {
//                ForEach(imageUrls, id: \.self) { url in
//                    OptimizedImageView(
//                        urlString: url,
//                        contentMode: .fill,
//                        autoResize: true
//                    )
//                    .frame(height: 120)
//                    .clipped()
//                }
//            }
//            .padding(8)
//        }
//    }
//}

// MARK: - 内存优化的图片缓存管理器
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private init() {
        setupCache()
    }
    
    private func setupCache() {
        ImageCache.default.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024 // 300MB
        ImageCache.default.memoryStorage.config.countLimit = 100
        ImageCache.default.memoryStorage.config.expiration = .days(1)
        
        ImageCache.default.diskStorage.config.sizeLimit = 1000 * 1024 * 1024 // 1GB
        ImageCache.default.diskStorage.config.expiration = .days(7)
        
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache()
    }
    
    func clearCache() {
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache()
    }
    
    func removeCache(for url: URL) {
        ImageCache.default.removeImage(forKey: url.absoluteString)
    }
}

