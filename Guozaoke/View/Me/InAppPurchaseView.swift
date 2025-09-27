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
            VStack {
                productListView
                HStack {
                    Spacer()
                    if storeManager.isLoading {
                        ProgressView("加载中...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Spacer()
                }
                purchaseButton
            }
            .navigationTitleStyle(purchaseAppState.isPurchased ? "感谢支持 ": "赞助我们")
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
