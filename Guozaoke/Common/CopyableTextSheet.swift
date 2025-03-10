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
        textView.isEditable = false
        textView.isSelectable = true
        textView.delegate = context.coordinator
        textView.text = text
        textView.backgroundColor = .clear
        //textView.isScrollEnabled = false
        textView.font = UIFont.systemFont(ofSize: titleFontSize)
        textView.textColor = UIColor.black.withAlphaComponent(0.7)
        return textView
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
        }
        .navigationBarTitle("复制文本", displayMode: .inline)
        .navigationBarItems(trailing: Button("关闭") {
            isPresented = false
        })
    }
}

