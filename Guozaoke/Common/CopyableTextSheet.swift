//
//  CopyableTextSheet.swift
//  Guozaoke
//
//  Created by scy on 2025/3/9.
//

import SwiftUI
import UIKit

struct CopyableTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable   = false
        textView.isSelectable = true
        textView.delegate = context.coordinator
        textView.text = text
        textView.backgroundColor = .clear
        ///textView.isScrollEnabled = false
        textView.font = fontStyle
        textView.textColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.white.withAlphaComponent(0.8)
            default:
                return UIColor.black.withAlphaComponent(0.8)
            }
        }
        return textView
    }
    
    var fontStyle: UIFont {
        let font = UIFont(name: titleFontName, size: subTitleFontSize) ?? UIFont.systemFont(ofSize: subTitleFontSize)
        return font
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CopyableTextEditor

        init(_ parent: CopyableTextEditor) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let selectedRange = textView.selectedTextRange {
                let selectedText = textView.text(in: selectedRange)
                parent.selectedText = selectedText ?? ""
            }
        }
    }
}

// 复制功能的 Sheet
struct CopyableTextSheet: View {
    @Binding var isPresented: Bool
    @Binding var text: String
    @State private var selectedText = ""

    var body: some View {
        NavigationStack {
            VStack {
                CopyableTextEditor(text: $text, selectedText: $selectedText)
                    .titleFontStyle()
            }
            .padding()
            .navigationBarTitle("选择文本", displayMode: .inline)
        }
    }
}
