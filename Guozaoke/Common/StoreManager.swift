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
    private var transactionListener: Task<Void, Error>?
    private var isInitialized = false
    private var processedTransactions: Set<UInt64> = []
    private var hasCheckedReceipt = false
    private var hasRestoredPurchases = false
    
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
        startTransactionListener()
        initializeIfNeeded()
    }
    
    private func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        
        Task {
            await fetchProducts()
            hasRestoredPurchases = true
            await syncPaidDownloadUsers()
        }
    }
    
    func refreshIfNeeded() {
        Task {
            await fetchProducts()
            if !hasRestoredPurchases {
                //await restorePurchases(false)
                hasRestoredPurchases = true
            }
        }
    }
    
    func forceRestorePurchases() {
        Task {
            await restorePurchases(true)
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Transaction Listener
    private func startTransactionListener() {
        transactionListener = Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .verified(let transaction):
            await handleVerifiedTransaction(transaction)
        case .unverified:
            logger("[iap] ❌ 未验证的交易更新", tag: "StoreManager")
        }
    }
    
    private func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        // 检查是否已经处理过这个交易
        guard !processedTransactions.contains(transaction.id) else {
            logger("[iap] 交易已处理过，跳过: \(transaction.id)", tag: "StoreManager")
            return
        }
        
        // 标记为已处理
        processedTransactions.insert(transaction.id)
        
        switch transaction.revocationDate {
        case .none:
            // 交易有效，确保用户有权限
            if productIDs.contains(transaction.productID) {
                await MainActor.run {
                    purchaseAppState.savePurchaseStatus(isPurchased: true)
                    logger("[iap] ✅ 交易有效，用户权限已更新: \(transaction.id)", tag: "StoreManager")
                }
            }
        case .some:
            // 交易被撤销（退费），移除用户权限
            await MainActor.run {
                purchaseAppState.savePurchaseStatus(isPurchased: false)
                logger("[iap] ❌ 交易被撤销，用户权限已移除: \(transaction.id)", tag: "StoreManager")
            }
        }
        
        // 完成交易处理
        await transaction.finish()
    }
    
    func syncPaidDownloadUsers() async {
        guard !hasCheckedReceipt else {
            logger("[iap] 收据已检查过，跳过", tag: "StoreManager")
            return
        }
        hasCheckedReceipt = true
        
        guard let receiptURL  = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: receiptURL) else {
            logger("[iap] 收据文件不存在，跳过付费下载检查", tag: "StoreManager")
            return
        }
        
        if let originalVersion = extractOriginalApplicationVersion(from: receiptData) {
            logger("[iap] 📄 originalApplicationVersion: \(originalVersion)", tag: "StoreManager")
            if originalVersion < purchasedVersion {
                purchaseAppState.savePurchaseStatus(isPurchased: true)
                logger("[iap] ✅ 付费下载用户，自动解锁", tag: "StoreManager")
            }
        } else {
            logger("[iap] ❌ 无法解析收据", tag: "StoreManager")
        }
    }
    
    func fetchProducts() async {
        guard products.isEmpty else {
            logger("[iap] 产品已加载，跳过", tag: "StoreManager")
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            await MainActor.run {
                products = storeProducts
                isLoading = false
            }
            logger("[iap] 成功加载 \(storeProducts.count) 个产品", tag: "StoreManager")
        } catch {
            await MainActor.run {
                isLoading = false
            }
            logger("[iap] Failed to fetch products: \(error)", tag: "StoreManager")
        }
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
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let transactions = try await getPurchasedTransactions()
            if transactions.isEmpty {
                await MainActor.run {
                    purchaseAppState.savePurchaseStatus(isPurchased: false)
                    isLoading = false
                }
                logger("[iap] No valid purchases found, removing permissions", tag: "StoreManager")
                if toast == true {
                    await MainActor.run {
                        ToastView.purchaseText("没找到已购买的项目")
                    }
                }
            } else {
                let validTransactions = transactions.filter { transaction in
                    return transaction.revocationDate == nil && productIDs.contains(transaction.productID)
                }
                
                await MainActor.run {
                    if validTransactions.isEmpty {
                        purchaseAppState.savePurchaseStatus(isPurchased: false)
                        isLoading = false
                        if toast == true {
                            ToastView.purchaseText("订阅已取消，权限已移除")
                        }
                    } else {
                        // 有有效交易，恢复权限
                        purchaseAppState.savePurchaseStatus(isPurchased: true)
                        isLoading = false
                        if toast == true {
                            ToastView.purchaseText("恢复购买成功！")
                        }
                    }
                }
                
                logger("[iap] Restored valid purchases: \(validTransactions.count)", tag: "StoreManager")
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            logger("[iap] Failed to restore purchases: \(error)", tag: "StoreManager")
            if toast == true {
                await MainActor.run {
                    ToastView.purchaseText("恢复购买失败，发生错误。")
                }
            }
        }
    }
    
    private func getPurchasedTransactions() async throws -> [StoreKit.Transaction] {
        var transactions: [StoreKit.Transaction] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                // 只处理未完成的交易
                if transaction.revocationDate == nil {
                    transactions.append(transaction)
                    logger("[iap] Found active transaction: \(transaction.productID)", tag: "StoreManager")
                } else {
                    logger("[iap] Found revoked transaction: \(transaction.productID)", tag: "StoreManager")
                }
            case .unverified:
                logger("[iap] ⚠️ Unverified transaction found", tag: "StoreManager")
                // 不抛出错误，继续处理其他交易
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
