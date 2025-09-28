//
//  LiquidGlassView.swift
//  Guozaoke
//
//  Created by scy on 2025/9/28.
//

import SwiftUI

// MARK: - 液态玻璃容器视图
struct LiquidGlassContainer<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26 GlassEffectContainer
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            // iOS 26以下使用传统背景
            content
                .background(LiquidGlassBackground())
        }
    }
}

// MARK: - 液态玻璃背景
struct LiquidGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        // 创建VisualEffectView
        let visualEffectView = UIVisualEffectView()
        
        if #available(iOS 15.0, *) {
            // iOS 15+ 使用系统Material
            let effect = UIBlurEffect(style: .systemUltraThinMaterial)
            visualEffectView.effect = effect
            visualEffectView.alpha = 0.9
        } else {
            // iOS 15以下降级方案
            visualEffectView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            visualEffectView.alpha = 0.9
        }
        
        containerView.addSubview(visualEffectView)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 动态更新效果
    }
}

// MARK: - 液态玻璃输入框背景
struct LiquidGlassInputBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        
        // 创建VisualEffectView
        let visualEffectView = UIVisualEffectView()
        
        if #available(iOS 15.0, *) {
            // iOS 15+ 使用系统Material
            let effect = UIBlurEffect(style: .systemMaterial)
            visualEffectView.effect = effect
            visualEffectView.alpha = 0.8
        } else {
            // iOS 15以下降级方案
            visualEffectView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.8)
            visualEffectView.alpha = 0.8
        }
        
        containerView.addSubview(visualEffectView)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 动态更新效果
    }
}

// MARK: - 液态玻璃按钮背景
struct LiquidGlassButtonBackground: UIViewRepresentable {
    let isEnabled: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.layer.cornerRadius = 12.5 // 25/2
        containerView.clipsToBounds = true
        
        // 创建VisualEffectView
        let visualEffectView = UIVisualEffectView()
        
        if #available(iOS 15.0, *) {
            // iOS 15+ 使用系统Material
            let effect = UIBlurEffect(style: .systemThickMaterial)
            visualEffectView.effect = effect
            visualEffectView.alpha = 0.8
        } else {
            // iOS 15以下降级方案
            let backgroundColor = isEnabled ? 
                UIColor.systemBlue.withAlphaComponent(0.15) : 
                UIColor.systemGray.withAlphaComponent(0.1)
            visualEffectView.backgroundColor = backgroundColor
            visualEffectView.alpha = 0.8
        }
        
        containerView.addSubview(visualEffectView)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 动态更新效果
    }
}

// MARK: - 液态玻璃修饰符
extension View {
    @ViewBuilder
    func liquidGlassInput() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(LiquidGlassInputBackground())
        }
    }
    
    @ViewBuilder
    func liquidGlassButton(isEnabled: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(LiquidGlassButtonBackground(isEnabled: isEnabled))
        }
    }
}
