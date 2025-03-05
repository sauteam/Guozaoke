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
        KFImage(URL(string: url ?? ""))
            .placeholder { progress in
                placeholder
            }
            .fade(duration: 0.25)
            .resizable()
            .cacheOriginalImage() // 确保缓存原始图片
            .diskCacheExpiration(.days(30)) // 设置磁盘缓存有效期
            .memoryCacheExpiration(.days(7)) // 设置内存缓存有效期
    }
}

// MARK: - 扩展
extension KFImageView {
    // 头像样式
    func avatar(size: CGFloat = 40) -> some View {
        self.frame(width: size, height: size)
            //.clipShape(Circle())
            .cornerRadius(8)
    }
    
    // 缩略图样式
    func thumbnail(width: CGFloat, height: CGFloat) -> some View {
        self.frame(width: width, height: height)
            .cornerRadius(8)
    }
    
    // 自适应宽度，固定高度
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
    
    // 检查是否为表情图片
    private func checkIsEmoji(_ urlString: String) -> Bool {
        // 检查 URL 中的关键词
        let emojiKeywords = ["emoji", "face", "sticker", "表情", "face/", "emot", "gif"]
        let lowercasedUrl = urlString.lowercased()
        
        // 检查是否为 GIF
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
                    // 使用 AnimatedImage 处理 GIF
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
                        .scaleFactor(UIScreen.main.scale)
                } else {
                    // 使用普通 KFImage 处理静态图片
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

// MARK: - 图片预览视图
struct ImagePreviewView: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss
    @State private var isAnimated: Bool = false
    
    // ... 其他代码保持不变 ...
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                Group {
                    if isAnimated {
                        KFAnimatedImage(URL(string: urlString))
                            .configure { view in
                                view.framePreloadCount = 3
                            }
                            .placeholder { _ in
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                    } else {
                        KFImage.url(URL(string: urlString))
                            .placeholder { _ in
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                    }
                }
                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                .aspectRatio(contentMode: .fit)
                // ... 其他手势和控制代码保持不变 ...
            }
        }
        .onAppear {
            isAnimated = urlString.lowercased().hasSuffix(".gif")
        }
    }
}
// MARK: - 图片预览视图
//struct ImagePreviewView: View {
//    let urlString: String
//    @Environment(\.dismiss) private var dismiss
//    
//    @State private var scale: CGFloat = 1.0
//    @State private var lastScale: CGFloat = 1.0
//    @State private var offset = CGSize.zero
//    @State private var lastOffset = CGSize.zero
//    @State private var showControls = true
//    
//    private var url: URL? {
//        URL(string: urlString)
//    }
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // 背景
//                Color.black.edgesIgnoringSafeArea(.all)
//                // 图片
//                KFImage.url(url)
//                    .placeholder { _ in
//                        ProgressView()
//                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                    }
//                    .loadDiskFileSynchronously()
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .scaleEffect(scale)
//                    .offset(offset)
//                    .gesture(
//                        SimultaneousGesture(
//                            // 缩放手势
//                            MagnificationGesture()
//                                .onChanged { value in
//                                    let delta = value / lastScale
//                                    lastScale = value
//                                    scale = min(max(scale * delta, 1), 4)
//                                }
//                                .onEnded { _ in
//                                    lastScale = 1.0
//                                },
//                            // 拖动手势
//                            DragGesture()
//                                .onChanged { value in
//                                    let delta = CGSize(
//                                        width: value.translation.width - lastOffset.width,
//                                        height: value.translation.height - lastOffset.height
//                                    )
//                                    lastOffset = value.translation
//                                    offset = CGSize(
//                                        width: offset.width + delta.width,
//                                        height: offset.height + delta.height
//                                    )
//                                }
//                                .onEnded { _ in
//                                    lastOffset = .zero
//                                }
//                        )
//                    )
//                    .onTapGesture(count: 2) {
//                        withAnimation {
//                            if scale > 1 {
//                                scale = 1
//                                offset = .zero
//                            } else {
//                                scale = 2
//                            }
//                        }
//                    }
//                
//                // 控制按钮
//                if showControls {
//                    VStack {
//                        HStack (alignment: .top, spacing: 100) {
//                            Spacer()
//                            Button {
//                                dismiss()
//                            } label: {
//                                Image(systemName: "xmark")
//                                    .foregroundColor(.white)
//                                    .padding()
//                                    .background(Color.black.opacity(0.6))
//                                    .clipShape(Circle())
//                            }
//                            .padding()
//                        }
//                        Spacer()
//                    }
//                }
//            }
//            .onTapGesture {
//                withAnimation {
//                    showControls.toggle()
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//    }
//}

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
        // 配置内存缓存
        ImageCache.default.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024 // 300MB
        ImageCache.default.memoryStorage.config.countLimit = 100 // 最多缓存100张图片
        ImageCache.default.memoryStorage.config.expiration = .days(1)
        
        // 配置磁盘缓存
        ImageCache.default.diskStorage.config.sizeLimit = 1000 * 1024 * 1024 // 1GB
        ImageCache.default.diskStorage.config.expiration = .days(7)
        
        // 清理过期缓存
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

