//
//  Base64View.swift
//  Guozaoke
//
//  Created by scy on 2025/3/10.
//

import SwiftUI

struct Base64View: View {
    @Binding var isPresented: Bool
    @State private var inputText: String = ""
    @State private var encodedText: String = ""
    @State private var decodedText: String = ""
    @State private var showingCopyAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("输入要加密的文本", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .subTitleFontStyle()
                
                HStack {
                    Button(action: {
                        hapticFeedback()
                        if let encoded = inputText.base64Encoded {
                            encodedText = encoded
                        }
                    }) {
                        Text("加密")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .subTitleFontStyle()

                    }
                    .padding()
                    
                    Button(action: {
                        encodedText.copyToClipboard()
                        hapticFeedback()
                    }) {
                        Text("拷贝")
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .subTitleFontStyle()
                    }
                    .padding()
                }
                
                Text("加密后的文本")
                    .subTitleFontStyle()
                Text(encodedText)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .subTitleFontStyle()
                    .frame(width: .infinity)
                    .padding()
                
                HStack {
                    Button(action: {
                        hapticFeedback()
                        if encodedText.count > 0 {
                            if let decoded = encodedText.base64Decoded, !decoded.isEmpty {
                                decodedText = decoded
                            }
                        } else {
                            if inputText.count > 0 {
                                decodedText = inputText.base64Decoded ?? ""
                            }
                        }
                    }) {
                        Text("解密")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .subTitleFontStyle()
                    }
                    .padding()
                    
                    Button(action: {
                        hapticFeedback()
                        decodedText.copyToClipboard()
                        //UIPasteboard.general.string = decodedText
                        //alertMessage = "解密后的文本已复制到剪贴板。"
                        //showingCopyAlert = true
                    }) {
                        Text("拷贝")
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .subTitleFontStyle()
                    }
                    .padding()
                }
                
                Text("解密后的文本")
                    .subTitleFontStyle()

                Text(decodedText)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding()
                    .subTitleFontStyle()
                    .frame(width: .infinity)
                
                Spacer()
            }
            .navigationTitle("Base64 加密解密")
            .navigationBarTitleDisplayMode(.inline)
        }
//            .alert(isPresented: $showingCopyAlert) {
//                Alert(title: Text("拷贝成功"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
//            }
    }
}
