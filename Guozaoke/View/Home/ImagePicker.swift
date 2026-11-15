//
//  ImagePicker.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI
import PhotosUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - 媒体选择结果包装（支持静态照片、GIF动图与 Live Photo 实况照片）
struct PickedMediaItem {
    let previewImage: UIImage
    let uploadData: Data
    let isLivePhoto: Bool
    let isGif: Bool
    let mimeType: String
}

// MARK: - Live Photo 实况照片转换辅助
struct LivePhotoHelper {
    /// 将 Live Photo 配对的伴随 QuickTime MOV 视频转为高质量紧凑循环 GIF 动图
    static func convertVideoToGif(videoURL: URL, maxDimension: CGFloat = 480, fps: Double = 12, maxDuration: Double = 3.0) -> Data? {
        let asset = AVAsset(url: videoURL)
        let totalSeconds = CMTimeGetSeconds(asset.duration)
        guard totalSeconds > 0 else { return nil }
        let duration = min(totalSeconds, maxDuration)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        
        let frameCount = max(1, Int(duration * fps))
        let frameDuration = duration / Double(frameCount)
        var times: [NSValue] = []
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) * frameDuration, preferredTimescale: 600)
            times.append(NSValue(time: time))
        }
        
        let gifData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(gifData, UTType.gif.identifier as CFString, frameCount, nil) else {
            return nil
        }
        
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0 // 循环播放
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDuration,
                kCGImagePropertyGIFUnclampedDelayTime: frameDuration
            ]
        ]
        
        for timeVal in times {
            let time = timeVal.timeValue
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }
        }
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return gifData as Data
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage? // 绑定选中的图片
    @Environment(\.presentationMode) var presentationMode // 控制模态视图消失

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator // 设置代理
        picker.allowsEditing = false // 是否允许编辑图片
        picker.sourceType = .photoLibrary // 使用相册作为图片来源
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 不需要实现
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator 用于管理 UIImagePickerController 的代理回调
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - 多图选择器（基于 PHPickerViewController，支持多选、保证选择顺序）
struct MultiImagePicker: UIViewControllerRepresentable {
    var maxSelectionCount: Int = 9
    var onImagesPicked: ([UIImage]) -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxSelectionCount
        config.filter = .images
        if #available(iOS 15.0, *) {
            config.selection = .ordered
        }
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker

        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            guard !results.isEmpty else { return }

            var loadedImages = [UIImage?](repeating: nil, count: results.count)
            let group = DispatchGroup()

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage {
                            loadedImages[index] = uiImage
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                let finalImages = loadedImages.compactMap { $0 }
                if !finalImages.isEmpty {
                    self.parent.onImagesPicked(finalImages)
                }
            }
        }
    }
}
