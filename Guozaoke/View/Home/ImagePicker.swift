//
//  ImagePicker.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 选取的媒体项模型（支持静态图与动图 GIF 原生多帧数据）
struct PickedMediaItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let rawData: Data?
    let isGIF: Bool
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

// MARK: - 多图选择器（基于 PHPickerViewController，支持多选、顺序保持、原生 GIF 动图多帧解析）
struct MultiImagePicker: UIViewControllerRepresentable {
    var maxSelectionCount: Int = 9
    var onItemsPicked: (([PickedMediaItem]) -> Void)? = nil
    var onImagesPicked: (([UIImage]) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode

    init(
        maxSelectionCount: Int = 9,
        onItemsPicked: @escaping ([PickedMediaItem]) -> Void
    ) {
        self.maxSelectionCount = maxSelectionCount
        self.onItemsPicked = onItemsPicked
        self.onImagesPicked = nil
    }

    init(
        maxSelectionCount: Int = 9,
        onImagesPicked: @escaping ([UIImage]) -> Void
    ) {
        self.maxSelectionCount = maxSelectionCount
        self.onItemsPicked = nil
        self.onImagesPicked = onImagesPicked
    }

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

            var loadedItems = [PickedMediaItem?](repeating: nil, count: results.count)
            let group = DispatchGroup()

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                if provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
                    group.enter()
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.gif.identifier) { data, _ in
                        if let gifData = data, let img = UIImage(data: gifData) {
                            DispatchQueue.main.async {
                                loadedItems[index] = PickedMediaItem(image: img, rawData: gifData, isGIF: true)
                            }
                        }
                        group.leave()
                    }
                } else if provider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage {
                            DispatchQueue.main.async {
                                loadedItems[index] = PickedMediaItem(image: uiImage, rawData: nil, isGIF: false)
                            }
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                let finalItems = loadedItems.compactMap { $0 }
                if !finalItems.isEmpty {
                    if let onItems = self.parent.onItemsPicked {
                        onItems(finalItems)
                    } else if let onImages = self.parent.onImagesPicked {
                        onImages(finalItems.map { $0.image })
                    }
                }
            }
        }
    }
}
