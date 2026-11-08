//
//  InAppPurchaseView.swift
//  Guozaoke
//
//  Created by scy on 2025/3/12.
//

import SwiftUI
import StoreKit

let purchaseInfo = """
过早客还有很多功能需要完善，仅有部分个性设置需要内购或打赏才可使用，基本不影响使用，感谢支持！

如果您觉得过早客App很有意义，您可以考虑赞助，有利于我们积极更新和维护，不断提高产品体验。
"""


struct InAppPurchaseView: View {
    @Binding var isPresented: Bool
    @ObservedObject var purchaseAppState: PurchaseAppState
    @StateObject private var storeManager: StoreManager
    @State private var selectedProduct: Product?
    
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
                let safeTrailing = GKDisplayMetrics.safeTabBarTrailingInset(
                    geometryTrailing: proxy.safeAreaInsets.trailing
                )
                let safeBottom = GKDisplayMetrics.safeTabBarBottomInset(
                    geometryBottom: proxy.safeAreaInsets.bottom
                )
                
                if isDual {
                    // 横屏/展开态：左边描述文案，右边展示商品列表和购买
                    HStack(spacing: 0) {
                        // 左窗格：品牌图标与描述说明
                        descriptionView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.bottom, safeBottom)
                        
                        // 物理中缝避让隔离带 (32pt)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: GKDisplayMetrics.hingeExclusionRadius * 2)
                            .allowsHitTesting(false)
                        
                        // 右窗格：仅展示商品列表与购买按钮 (不重复展示描述)
                        VStack(spacing: 0) {
                            productOnlyListView
                            
                            if storeManager.isLoading {
                                ProgressView("加载中...")
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.vertical, 8)
                            }
                            
                            purchaseButton
                                .padding(.bottom, safeBottom)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.trailing, safeTrailing)
                    }
                    .environment(\.isGKDualColumn, true)
                } else {
                    // 竖屏单列常规流：顶部描述 + 下方商品列表与购买
                    VStack(spacing: 0) {
                        productListView
                        
                        if storeManager.isLoading {
                            ProgressView("加载中...")
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.vertical, 8)
                        }
                        
                        purchaseButton
                    }
                    .environment(\.isGKDualColumn, false)
                }
            }
            .navigationTitleStyle(purchaseAppState.isPurchased ? "感谢支持 " : "赞助我们")
            .onAppear {
                // 立即显示加载状态
                if storeManager.products.isEmpty {
                    storeManager.isLoading = true
                }
                storeManager.refreshIfNeeded()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }) {
                        Text("恢复购买")
                    }
                }
            }
        }
        .onAppear {
            // 如果产品列表为空，立即显示加载状态
            if storeManager.products.isEmpty {
                storeManager.isLoading = true
            }
            
            Task {
                await storeManager.fetchProducts()
                
                let rewardProducts = storeManager.products.filter { product in
                    product.id == "GuozaokeReward" || product.id == "GuozaokeReward2" || product.id == "sponsorDeveloper"
                }
                
                if !rewardProducts.isEmpty {
                    selectedProduct = rewardProducts.randomElement()
                    logger("[iap] 随机选择默认商品: \(selectedProduct?.id ?? "无")", tag: "InAppPurchaseView")
                } else if let defaultProduct = storeManager.products.first(where: { $0.id == storeManager.sponserIds }) {
                    selectedProduct = defaultProduct
                } else {
                    selectedProduct = storeManager.products.last
                }
                
                logger("[iap][list] \(storeManager.products.map { $0.id })", tag: "InAppPurchaseView")
            }
        }
    }
    
    private func productSortOrder(lhs: Product, rhs: Product) -> Bool {
        let ids = storeManager.productIDs
        return (ids.firstIndex(of: lhs.id) ?? ids.count) < (ids.firstIndex(of: rhs.id) ?? ids.count)
    }
    
    // MARK: - 横屏左侧描述视图 (品牌与赞助背景)
    @ViewBuilder
    private var descriptionView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: purchaseAppState.isPurchased ? "checkmark.seal.fill" : "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text(purchaseAppState.isPurchased ? "感谢您的支持" : "赞助过早客")
                .font(.title2.bold())
            
            Text(purchaseInfo)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(5)
                .padding(.horizontal, 28)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 横屏右侧纯商品列表 (不包含重复描述文案)
    @ViewBuilder
    private var productOnlyListView: some View {
        List {
            ForEach(storeManager.products.sorted(by: productSortOrder), id: \.self) { product in
                productRow(for: product)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .buttonStyle(.plain)
    }
    
    // MARK: - 竖屏列表视图 (保留顶部描述文案)
    @ViewBuilder
    private var productListView: some View {
        List {
            Text(purchaseInfo)
                .titleFontStyle()
                .padding()

            ForEach(storeManager.products.sorted(by: productSortOrder), id: \.self) { product in
                productRow(for: product)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func productRow(for product: Product) -> some View {
        Button(action: {
            selectedProduct = product
        }) {
            HStack {
                productSelectionIcon(for: product)
                VStack(alignment: .leading) {
                    Text(product.displayPrice)
                        .subTitleFontStyle()
                        .padding(.bottom, 2)

                    Text(product.displayName)
                        .subTitleFontStyle()
                }
                .padding(.vertical)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(product == selectedProduct ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func productSelectionIcon(for product: Product) -> some View {
        if product == selectedProduct {
            SFSymbol.checkmarkCircleFill.image
                .foregroundColor(.blue)
                .padding()
        } else {
            SFSymbol.circle.image
                .foregroundColor(.gray)
                .padding()
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        Button(action: {
            Task {
                if let product = selectedProduct {
                    await storeManager.purchaseProduct(product)
                }
            }
        }) {
            Text(selectedProduct?.description ?? "确认")
                .subTitleFontStyle()
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .disabled(selectedProduct == nil)
    }
}
