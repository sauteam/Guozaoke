//
//  NavigationUtil.swift
//  Guozaoke
//
//  Created by scy on 2025/1/14.
//

import SwiftUI

// MARK: - 导航工具
enum NavigationUtil {
    static func push<V: View>(_ view: V) {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        let rootViewController = window?.rootViewController
        
        if let navigationController = rootViewController?.navigationController {
            // 如果已经在导航控制器中，直接 push
            let hostingController = UIHostingController(rootView: view)
            navigationController.pushViewController(hostingController, animated: true)
        } else {
            // 如果不在导航控制器中，创建一个新的
            let hostingController = UIHostingController(rootView:
                NavigationView {
                    view
                }
            )
            rootViewController?.present(hostingController, animated: true)
        }
    }
}

// MARK: - 视图扩展
extension View {
    func pushLink<Destination: View>(destination: Destination) -> some View {
        self.onTapGesture {
            NavigationUtil.push(destination)
        }
    }
}

struct TagDetailView: View {
    let tag: String
    
    var body: some View {
        VStack {
            Text("话题: #\(tag)")
            // ... 标签相关内容 ...
        }
    }
}

struct ImagePreviewView: View {
    let url: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
    }
}


//#Preview {
//    NavigationUtil()
//}
