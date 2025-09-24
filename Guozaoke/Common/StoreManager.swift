//
//  StoreManager.swift
//  Guozaoke
//
//  Created by scy on 2025/3/13.
//

import Foundation
import StoreKit


@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    
    private let purchaseAppState: PurchaseAppState
    
    var sponserIds: String {
        return "sponsorDeveloper"
    }
    var productIDs: [String] {
        let ids = ["sponsorDeveloper", "GuozaokeReward", "GuozaokeReward2"]
//        if purchaseAppState.isPurchased {
//            ids.removeFirst()
//        }
        return ids
    }
    
    init(purchaseAppState: PurchaseAppState) {
        self.purchaseAppState = purchaseAppState
        Task {
            await fetchProducts()
            await restorePurchases(false)
            await syncPaidDownloadUsers()
        }
    }
    
    func syncPaidDownloadUsers() async {
        guard let receiptURL  = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            logger("[iap] ❌ 无法获取收据文件")
            return
        }
        if let originalVersion = extractOriginalApplicationVersion(from: receiptData) {
            logger("[iap] 📄 originalApplicationVersion: \(originalVersion)")
            if originalVersion < purchasedVersion {
                purchaseAppState.savePurchaseStatus(isPurchased: true)
                logger("[iap] ✅ 付费下载用户，自动解锁")
            }
        } else {
            logger("[iap] ❌ 无法解析收据")
        }
    }
    
    func fetchProducts() async {
        isLoading = true
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts
        } catch {
            logger("[iap]Failed to fetch products: \(error)")
        }
        isLoading = false
    }
    
    func purchaseProduct(_ product: Product) async {
        isLoading = true
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    ToastView.purchaseText("支付成功，感谢！")
                    logger("[iap] Purchase successful")
                    NotificationCenter.default.post(name: .purchaseSuccessNoti, object: ["success": "1"])
                    purchaseAppState.savePurchaseStatus(isPurchased: true)
                case .unverified:
                    logger("[iap]Purchase unverified")
                }
            case .userCancelled, .pending:
                ToastView.purchaseText("取消支付")
                logger("[iap]Purchase cancelled or pending")
            @unknown default:
                break
            }
        } catch {
            logger("[iap]Purchase failed: \(error)")
        }
        isLoading = false
    }
    
    func restorePurchases(_ toast: Bool? = true) async {
        isLoading = true
        do {
            let transactions = try await getPurchasedTransactions()
            if transactions.isEmpty {
                logger("[iap] No previous purchases found")
                if toast == true {
                    if purchaseAppState.isPurchased {
                        ToastView.purchaseText("已解锁个性设置功能")
                    } else {
                        ToastView.purchaseText("没找到已购买的项目")
                    }
                }
            } else {
                purchaseAppState.savePurchaseStatus(isPurchased: true)
                logger("[iap] Restored previous purchases")
                if toast == true {
                    ToastView.purchaseText("恢复购买成功！")
                }
            }
        } catch {
            logger("[iap]Failed to restore purchases: \(error)")
            ToastView.purchaseText("恢复购买失败，发生错误。")
        }
        isLoading = false
    }
    
    private func getPurchasedTransactions() async throws -> [StoreKit.Transaction] {
        var transactions: [StoreKit.Transaction] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                transactions.append(transaction)
            case .unverified:
                throw NSError(domain: APIService.baseUrlString, code: 1001, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"])
            }
        }
        return transactions
    }
    

    func extractOriginalApplicationVersion(from receiptData: Data) -> String? {
        let receiptDict = decodeReceipt(data: receiptData)

        if let originalVersion = receiptDict["original_application_version"] as? String {
            return originalVersion
        }
        return nil
    }

    func decodeReceipt(data: Data) -> [String: Any] {
        var format = PropertyListSerialization.PropertyListFormat.xml
        do {
            let receiptDict = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: &format) as? [String: Any]
            return receiptDict ?? [:]
        } catch {
            logger("❌ 解析收据失败: \(error)")
            return [:]
        }
    }
}
