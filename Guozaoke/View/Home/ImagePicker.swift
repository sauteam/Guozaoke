//
//  ImagePicker.swift
//  Guozaoke
//
//  Created by scy on 2025/1/19.
//

import SwiftUI
import PhotosUI

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
