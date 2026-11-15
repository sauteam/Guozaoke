//
//  InAppPurchaseView.swift
//  Guozaoke
//
//  Created by scy on 2025/3/12.
//

import SwiftUI
import StoreKit

struct InAppPurchaseView: View {
    @Binding var isPresented: Bool
    @ObservedObject var purchaseAppState: PurchaseAppState
    @StateObject private var storeManager: StoreManager
    @State private var selectedProduct: Product?
    
    // 统一主题主色：遵循 iOS 原生 HIG 规范，沉稳克制、杜绝花里胡哨
    private let themeColor = Color.blue
    
    init(isPresented: Binding<Bool>, purchaseAppState: PurchaseAppState) {
        self._isPresented  = isPresented
        self.purchaseAppState = purchaseAppState
        let storeManager   = StoreManager(purchaseAppState: purchaseAppState)
        self._storeManager = StateObject(wrappedValue: storeManager)
    }
        
    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let isDual = GKDisplayMetrics.isDualColumnDisplay(size: proxy.size)
                
                if isDual {
                    // 横屏/展开态双栏排版
                    HStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 20) {
                                headerHeroView
                                privilegesSection
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // 物理中缝避让隔离带 (32pt)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: GKDisplayMetrics.hingeExclusionRadius * 2)
                            .allowsHitTesting(false)
                        
                        // 右窗格：展示全商品列表与购买操作
                        VStack(spacing: 16) {
                            ScrollView {
                                VStack(spacing: 12) {
                                    productListSection
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            }
                            
                            if storeManager.isLoading {
                                ProgressView("处理中...")
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.vertical, 4)
                            }
                            
                            purchaseButtonSection
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.trailing, 10)
                    }
                    .environment(\.isGKDualColumn, true)
                } else {
                    // 竖屏单列常规流：整洁合一界面
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 20) {
                                headerHeroView
                                privilegesSection
                                productListSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        }
                        
                        if storeManager.isLoading {
                            ProgressView("处理中...")
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.vertical, 4)
                        }
                        
                        purchaseButtonSection
                    }
                    .environment(\.isGKDualColumn, false)
                }
            }
            //.navigationTitleStyle(purchaseAppState.isPurchased ? "过早客 Pro" : "开通过早客 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        isPresented = false
                    }
                    .font(.body)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("恢复购买") {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .onAppear {
            if storeManager.products.isEmpty {
                storeManager.isLoading = true
            }
            storeManager.refreshIfNeeded()
            
            Task {
                await storeManager.fetchProducts()
                if let defaultProduct = storeManager.purchasableProducts.first(where: { $0.id == storeManager.sponserIds }) {
                    selectedProduct = defaultProduct
                } else {
                    selectedProduct = storeManager.purchasableProducts.first
                }
            }
        }
    }
    
    // MARK: - 1. 顶部 Hero 区域：简洁居中、轻盈留白、统一图标色调
    @ViewBuilder
    private var headerHeroView: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeColor.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(themeColor)
            }
            .padding(.top, 4)
            
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("过早客 Pro")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(purchaseAppState.isPurchased ? "终身版" : "永久买断")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(themeColor.opacity(0.12))
                        )
                }
                
                Text(purchaseAppState.isPurchased ? "已开通过早客 Pro，您仍可在此打赏鼓励作者" : "一次开通 · 终身享有全部专属特权")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
    
    // MARK: - 2. 专属特权卡片：统一样式容器、同色系图标
    @ViewBuilder
    private var privilegesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("专属特权")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                privilegeRow(
                    icon: "clock.badge.checkmark",
                    title: "超时长期编辑",
                    subtitle: "突破 15 分钟纠错限制，随时随地维护主楼内容"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                privilegeRow(
                    icon: "photo.stack.fill",
                    title: "单帖 9 图批量传",
                    subtitle: "支持多图批量连发与高清 GIF 动图原画上传"
                )
                
                Divider()
                    .padding(.leading, 56)
                
                privilegeRow(
                    icon: "paperplane.fill",
                    title: "每日畅享私信",
                    subtitle: "突破每日私信沟通配额限制，联系交流快人一步"
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
    
    @ViewBuilder
    private func privilegeRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(themeColor.opacity(0.1))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    // MARK: - 3. 全商品列表：统一卡片高亮与无缝促销对比
    @ViewBuilder
    private var productListSection: some View {
        if !storeManager.purchasableProducts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("全部商品")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                VStack(spacing: 10) {
                    ForEach(storeManager.purchasableProducts.sorted(by: productSortOrder), id: \.self) { product in
                        productItemCard(for: product)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func productItemCard(for product: Product) -> some View {
        let isSelected = (product == selectedProduct)
        let originCheck = originPriceComparison(for: product)
        
        Button {
            selectedProduct = product
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? themeColor : Color(UIColor.tertiaryLabel))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if product.id == storeManager.sponserIds {
                            Text("推荐")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(themeColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(themeColor.opacity(0.12)))
                        }
                        
                        if originCheck.shouldShowOriginPrice, let discount = originCheck.discountText {
                            Text(discount)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.red.opacity(0.1)))
                        }
                    }
                    
                    Text(product.description.isEmpty ? "解锁所有专属特权" : product.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if originCheck.shouldShowOriginPrice {
                        Text(originCheck.originPriceText)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .strikethrough()
                    }
                    
                    Text(product.displayPrice)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? themeColor : .primary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? themeColor.opacity(0.04) : Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? themeColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 辅助：原价对比判定（不相等则显示划线原价，相等则不展示方便促销恢复）
    private func originPriceComparison(for product: Product) -> (shouldShowOriginPrice: Bool, originPriceText: String, discountText: String?) {
        guard product.id == storeManager.sponserIds,
              let origin = storeManager.originProduct else {
            return (false, "", nil)
        }
        
        if product.price != origin.price {
            var discount: String? = nil
            if origin.price > 0 && product.price < origin.price {
                let curD = Double(truncating: product.price as NSDecimalNumber)
                let orgD = Double(truncating: origin.price as NSDecimalNumber)
                let fold = (curD / orgD) * 10
                discount = String(format: "%.1f折", fold)
            }
            return (true, origin.displayPrice, discount)
        }
        
        return (false, "", nil)
    }
    
    // MARK: - 4. 底部购买按钮与合规协议
    @ViewBuilder
    private var purchaseButtonSection: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if let product = selectedProduct {
                        await storeManager.purchaseProduct(product)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if purchaseAppState.isPurchased {
                        Image(systemName: "heart.fill")
                        let price = selectedProduct?.displayPrice ?? ""
                        Text("打赏赞助作者 \(price)")
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                        let price = selectedProduct?.displayPrice ?? "¥8"
                        Text("立即以 \(price) 开通过早客 Pro")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(themeColor)
                )
            }
            .disabled(selectedProduct == nil || storeManager.isLoading)
            .padding(.horizontal, 16)
            
            Text("Apple 官方安全支付 · 支持换机随时免费恢复购买")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                if let eulaUrl = URL(string: AppInfo.appleEula) {
                    Link("使用条款 (EULA)", destination: eulaUrl)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text("·")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if let privacyUrl = URL(string: APIService.feedbackAllLink) {
                    Link("隐私协议", destination: privacyUrl)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 6)
        }
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground).ignoresSafeArea(edges: .bottom))
    }
    
    private func productSortOrder(lhs: Product, rhs: Product) -> Bool {
        let ids = storeManager.productIDs
        return (ids.firstIndex(of: lhs.id) ?? ids.count) < (ids.firstIndex(of: rhs.id) ?? ids.count)
    }
}
