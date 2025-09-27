//
//  ReviewGuideView.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import SwiftUI
import StoreKit

struct ReviewGuideView: View {
    @Binding var isPresented: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    //dismissGuide()
                }
            
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("欢迎使用过早客！")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("感谢您选择过早客，您的支持是我们前进的动力。如果觉得我们做的还不错，请考虑给我们一个五星好评！")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button(action: {
                        requestReview()
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("去App Store评分")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        dismissGuide()
                    }) {
                        Text("下次一定")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private func requestReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
        dismissGuide()
    }
    
    private func dismissGuide() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

#Preview {
    ReviewGuideView(isPresented: .constant(true))
}
