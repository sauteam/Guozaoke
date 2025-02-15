//
//  SafariView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/27.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        
    }
}

//struct SafariView: UIViewControllerRepresentable {
//    let url: URL
//    let delegate = SafariViewControllerDelegate()
//
//    func makeUIViewController(context: Context) -> SFSafariViewController {
//        log("[web] url \(url.absoluteString)")
//        let safariVC = SFSafariViewController(url: url)
//        safariVC.preferredControlTintColor = .systemBlue
//        safariVC.delegate = delegate
//        return safariVC
//    }
//
//    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
//    
//    }
//    
//    class SafariViewControllerDelegate: NSObject, SFSafariViewControllerDelegate {
//        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
//            // 当用户关闭 SFSafariViewController 时调用
//            print("Safari 视图已关闭")
//        }
//    }
//}


//#Preview {
//    SafariView()
//}
