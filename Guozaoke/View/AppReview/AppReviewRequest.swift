import StoreKit
import SwiftUI

@available(iOS 18.0, *)
struct AppReviewRequest {
    @AppStorage("hasPromptedForReview") static var hasPromptedForReview: Bool = false
    @AppStorage("reviewRequestCount") static var reviewRequestCount: Int = 0
    @AppStorage("lastReviewRequestDate") static var lastReviewRequestDate: Date?
    
    static func devReview() {
#if DEUBG
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
#endif
    }
    
    static func clearReviewData() {
#if DEBUG
         hasPromptedForReview = false
         reviewRequestCount = 0
         lastReviewRequestDate = nil
#endif
    }
    
    static func requestReviewIfAppropriate() {
        
        logger("[review]1 hasPromptedForReview \(hasPromptedForReview) reviewRequestCount \(reviewRequestCount) lastReviewRequestDate \(lastReviewRequestDate ?? Date())")
        if !hasPromptedForReview {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                hasPromptedForReview = true
                return
            }
        }
        
        logger("[review]2 hasPromptedForReview \(hasPromptedForReview) reviewRequestCount \(reviewRequestCount) lastReviewRequestDate \(lastReviewRequestDate ?? Date())")
        reviewRequestCount += 1
        if let lastRequestDate = lastReviewRequestDate,
           Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0 < 30 {
            logger("[review] within the last 30 days")
            return
        }
        
        logger("[review]3 hasPromptedForReview \(hasPromptedForReview) reviewRequestCount \(reviewRequestCount) lastReviewRequestDate \(lastReviewRequestDate ?? Date())")
        
        if reviewRequestCount >= 3 {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                reviewRequestCount = 0
                lastReviewRequestDate = Date()
            }
        }
    }
}
