//
//  GKDisplayAdapter.swift
//  Guozaoke
//
//  Created for foldable & dual-screen hardware adaptation (iPhone Duo & iPad).
//  Customized for Guozaoke architecture, aligned with RouteX adaptation standards.
//

import UIKit
import SwiftUI

// MARK: - Guozaoke Foldable Geometry & Layout Metrics

public enum GKDisplayMetrics {
    
    /// 折叠屏物理中央铰链分界中线 (横屏展开 951pt 时为 475.5pt)
    public static let hingeThreshold: CGFloat = 475.5
    
    /// 铰链两侧交互避让半宽 (中缝总避让带宽 32pt: [459.5, 491.5]pt)
    public static let hingeExclusionRadius: CGFloat = 16.0
    
    /// 侧边垂直工具/系统导航栏保留宽度 (iOS 27+ iPhone Duo 在外屏与内屏横屏下强制使用 84pt 侧边栏)
    public static let systemSidebarWidth: CGFloat = 84.0
    
    /// 底部水平 TabBar 保留高度 (内屏竖屏/展开状态下为 95pt)
    public static let systemTabBarHeight: CGFloat = 95.0
    
    /// 浮动交互卡片/弹窗推荐基准宽度
    public static let floatingPanelWidth: CGFloat = 420.0
    
    /// 舒适单栏内容阅读最大宽度 (避免大屏下文字跨度过长)
    public static let comfortReadableWidth: CGFloat = 540.0
    
    /// 右侧主操作区黄金可用宽度 (951 - 84 - 475.5 - 16 ≈ 375.5pt，完美对齐 375pt 设计标准)
    public static let standardSinglePaneWidth: CGFloat = 375.5

    /// 获取当前应用活跃主窗口
    public static var primaryKeyWindow: UIWindow? {
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let foregroundScene = activeScenes.first { $0.activationState == .foregroundActive } ?? activeScenes.first
        return foregroundScene?.windows.first { $0.isKeyWindow } ?? foregroundScene?.windows.first
    }
    
    /// 当前设备主屏幕尺寸 (动态读取当前窗口尺寸，杜绝缓存死尺寸)
    public static var deviceScreenBounds: CGRect {
        if let window = primaryKeyWindow {
            return window.bounds
        }
        return UIScreen.main.bounds
    }
    
    /// 当前屏幕宽高尺寸
    public static var deviceScreenSize: CGSize {
        deviceScreenBounds.size
    }
    
    /// 判断当前是否为 iPhone Duo 折叠屏硬件设备 (外屏 466x678, 内屏 669x951)
    public static var isDuoDevice: Bool {
        let bounds = deviceScreenBounds
        let minDim = min(bounds.width, bounds.height)
        let maxDim = max(bounds.width, bounds.height)
        let isOuter = abs(minDim - 466) < 30 && abs(maxDim - 678) < 30
        let isInner = abs(minDim - 669) < 30 && abs(maxDim - 951) < 30
        return isOuter || isInner
    }
    
    /// 判断当前是否处于内屏竖屏姿态 (iPhone Duo 唯一使用底部 95pt 水平 TabBar 的模式)
    public static var isInnerPortraitPose: Bool {
        let bounds = deviceScreenBounds
        return abs(bounds.width - 669) < 30 && abs(bounds.height - 951) < 30
    }
    
    /// 判断是否运行于带右侧垂直 TabBar / 侧边栏的硬件布局上下文
    public static var hasVerticalTabBar: Bool {
        if isDuoDevice {
            // 在 iPhone Duo 上，除内屏竖屏外，其余姿态（外屏竖屏/横屏、内屏横屏）系统均强制使用右侧垂直侧边栏
            return !isInnerPortraitPose
        }
        let trailingInset = primaryKeyWindow?.safeAreaInsets.right ?? 0
        return trailingInset >= 44
    }

    /// 判定当前上下文是否处于宽屏双窗格展示状态 (SwiftUI 支持)
    public static func isDualColumnDisplay(
        size: CGSize? = nil,
        horizontalSizeClass: UserInterfaceSizeClass? = nil
    ) -> Bool {
        let currentSize = size ?? deviceScreenSize
        let isLandscape = currentSize.width > currentSize.height
        
        let isRegular: Bool
        if let hSizeClass = horizontalSizeClass {
            isRegular = (hSizeClass == .regular)
        } else {
            isRegular = (primaryKeyWindow?.traitCollection.horizontalSizeClass == .regular)
        }
        
        // 宽屏模式：宽度足够且横向或者属于 Regular 宽屏展开
        let isWideScreen = currentSize.width >= 700 || (currentSize.width >= 600 && isRegular)
        return isLandscape && isWideScreen
    }

    /// 判定当前上下文是否处于宽屏双窗格展示状态 (UIKit 支持)
    public static func isDualColumnDisplay(
        size: CGSize?,
        traitCollection: UITraitCollection
    ) -> Bool {
        let currentSize = size ?? deviceScreenSize
        let isLandscape = currentSize.width > currentSize.height
        let isRegular = traitCollection.horizontalSizeClass == .regular
        let isWideScreen = currentSize.width >= 700 || (currentSize.width >= 600 && isRegular)
        return isLandscape && isWideScreen
    }
    
    /// 检测 X 轴坐标是否位于铰链物理折痕受损区
    public static func isWithinHingeBuffer(xPosition: CGFloat, containerWidth: CGFloat) -> Bool {
        let centerX = containerWidth / 2.0
        return abs(xPosition - centerX) <= hingeExclusionRadius
    }
    
    /// 获取针对右侧垂直 TabBar 的自适应安全边距
    public static func safeTabBarTrailingInset(geometryTrailing: CGFloat = 0) -> CGFloat {
        if hasVerticalTabBar {
            return max(systemSidebarWidth, geometryTrailing)
        }
        let windowTrailing = primaryKeyWindow?.safeAreaInsets.right ?? 0
        return max(geometryTrailing, windowTrailing)
    }
    
    /// 获取针对底部 TabBar 的自适应安全边距 (避让内屏竖屏 95pt 或标准 TabBar)
    public static func safeTabBarBottomInset(geometryBottom: CGFloat = 0) -> CGFloat {
        if isInnerPortraitPose {
            return max(systemTabBarHeight, geometryBottom)
        }
        let windowBottom = primaryKeyWindow?.safeAreaInsets.bottom ?? 0
        return max(geometryBottom, windowBottom)
    }
}

// MARK: - UIViewController Display Extension

public extension UIViewController {
    
    /// 当前控制器是否处于宽屏/折叠屏横向展开形态
    func isGKDualColumnActive(for targetSize: CGSize? = nil) -> Bool {
        return GKDisplayMetrics.isDualColumnDisplay(
            size: targetSize ?? view.bounds.size,
            traitCollection: traitCollection
        )
    }
    
    /// 获取当前右侧可用安全边距 (自动避让 84pt 侧边栏)
    var gkSafeTrailingInset: CGFloat {
        let rawTrailing = view.safeAreaInsets.right
        return max(rawTrailing, GKDisplayMetrics.safeTabBarTrailingInset())
    }
}

// MARK: - SwiftUI Environment & Adaptive Containers

private struct GKDualColumnEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var isGKDualColumn: Bool {
        get { self[GKDualColumnEnvironmentKey.self] }
        set { self[GKDualColumnEnvironmentKey.self] = newValue }
    }
}

/// 自适应双窗格容器：在宽屏/折叠屏横屏下左右分列，避免跨铰链拉伸；在常规单屏下单列垂直布局
public struct GKSplitScreenContainer<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let primaryView: Primary
    private let secondaryView: Secondary
    private let gap: CGFloat

    public init(
        gap: CGFloat = GKDisplayMetrics.hingeExclusionRadius * 2,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.gap = gap
        self.primaryView = primary()
        self.secondaryView = secondary()
    }

    public var body: some View {
        GeometryReader { proxy in
            let isDual = GKDisplayMetrics.isDualColumnDisplay(
                size: proxy.size,
                horizontalSizeClass: horizontalSizeClass
            )
            
            if isDual {
                HStack(spacing: 0) {
                    // 主侧窗格 (0 ~ 459.5pt)
                    primaryView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 中缝硬件避让隔离带 (32pt)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: gap)
                        .allowsHitTesting(false)
                    
                    // 副侧窗格 (491.5 ~ 867pt)
                    secondaryView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .environment(\.isGKDualColumn, true)
            } else {
                VStack(spacing: 0) {
                    primaryView
                    secondaryView
                }
                .environment(\.isGKDualColumn, false)
            }
        }
    }
}

// MARK: - SwiftUI Modifiers

public extension View {
    
    /// 限制宽屏展开下的控件宽度，杜绝跨折痕过度拉伸
    func gkComfortWidthLimit(_ maxWidth: CGFloat = GKDisplayMetrics.comfortReadableWidth) -> some View {
        modifier(GKComfortWidthModifier(maxWidth: maxWidth))
    }
    
    /// 确保右侧留出侧边栏安全距离 (84pt 避让)
    func gkTrailingSafetyMargin(_ fallbackPadding: CGFloat = 16) -> some View {
        modifier(GKSafetyTrailingModifier(fallbackPadding: fallbackPadding))
    }
    
    /// 确保底部留出 TabBar 安全距离 (内屏竖屏 95pt 避让)
    func gkBottomSafetyMargin(_ fallbackPadding: CGFloat = 16) -> some View {
        modifier(GKSafetyBottomModifier(fallbackPadding: fallbackPadding))
    }
}

private struct GKComfortWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let isDual = GKDisplayMetrics.isDualColumnDisplay(
                size: proxy.size,
                horizontalSizeClass: horizontalSizeClass
            )
            
            content
                .frame(maxWidth: isDual ? maxWidth : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct GKSafetyTrailingModifier: ViewModifier {
    let fallbackPadding: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let safeTrailing = GKDisplayMetrics.safeTabBarTrailingInset(
                geometryTrailing: proxy.safeAreaInsets.trailing
            )
            content
                .padding(.trailing, max(safeTrailing, fallbackPadding))
        }
    }
}

private struct GKSafetyBottomModifier: ViewModifier {
    let fallbackPadding: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let safeBottom = GKDisplayMetrics.safeTabBarBottomInset(
                geometryBottom: proxy.safeAreaInsets.bottom
            )
            content
                .padding(.bottom, max(safeBottom, fallbackPadding))
        }
    }
}
