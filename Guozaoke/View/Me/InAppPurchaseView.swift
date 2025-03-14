//
//  InAppPurchaseView.swift
//  Guozaoke
//
//  Created by scy on 2025/3/12.
//

import SwiftUI
import StoreKit

let purchaseInfo = """
过早客还有很多功能需要完善，感谢同学们的关注与支持，仅有部分个性设置需要内购或打赏才可使用，希望大家理解，非常感谢！

如果付费下载显示还需要付费，请尝试恢复购买，如果还是需要付费请联系开发者。
"""


struct InAppPurchaseView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var purchaseAppState: PurchaseAppState
    @StateObject private var storeManager: StoreManager
    @State private var selectedProduct: Product?
    
    init(isPresented: Binding<Bool>, purchaseAppState: PurchaseAppState) {
        self._isPresented  = isPresented
        let storeManager   = StoreManager(purchaseAppState: purchaseAppState)
        self._storeManager = StateObject(wrappedValue: storeManager)
    }
        
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Spacer()
                    if storeManager.isLoading {
                        ProgressView("加载中...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Spacer()
                }
                productListView

                Spacer()
                purchaseButton
            }
            .navigationTitleStyle(purchaseAppState.isPurchased ? "已解锁": "等待解锁")
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
            Task {
                await storeManager.fetchProducts()
            }
            
            if let defaultProduct = storeManager.products.first(where: { $0.id == storeManager.sponserIds }) {
                  selectedProduct = defaultProduct
              } else {
                  selectedProduct = storeManager.products.first
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
                    .frame(width: .infinity, height: 60)
            }
        }
        .listStyle(.plain)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func productRow(for product: Product) -> some View {
        HStack {
            productSelectionIcon(for: product)
            VStack(alignment: .leading) {
                Text(product.displayPrice)
                    .subTitleFontStyle()
                    .padding(.bottom, 2)

                Text(product.description)
                    .subTitleFontStyle()
            }
            .padding(.vertical)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedProduct = product
        }
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
