//
//  LaunchCounter.swift
//  Guozaoke
//
//  Created by scy on 2025/1/12.
//

import Foundation

class LaunchCounter: ObservableObject {
    static let shared = LaunchCounter()
    
    @Published var launchCount: Int = 0
    @Published var shouldShowReviewGuide: Bool = false
    @Published var shouldShowPurchaseView: Bool = false
    
    private let launchCountKey = "app_launch_count"
    private let hasShownReviewKey = "has_shown_review_guide"
    private let lastPurchasePromptKey = "last_purchase_prompt_date"
    private let lastPromptDateKey = "last_prompt_date"
    private let nextPromptDateKey = "next_prompt_date"
    
    private init() {
        loadLaunchCount()
        checkGuides()
    }
    
    func incrementLaunchCount() {
        launchCount += 1
        UserDefaults.standard.set(launchCount, forKey: launchCountKey)
        checkGuides()
    }
    
    private func loadLaunchCount() {
        launchCount = UserDefaults.standard.integer(forKey: launchCountKey)
        logger("当前启动次数: \(launchCount)", tag: "LaunchCounter")
    }
    
    private func checkGuides() {
        let hasShownReview = UserDefaults.standard.bool(forKey: hasShownReviewKey)
        //shouldShowReviewGuide = launchCount == 1 && !hasShownReview
        if launchCount == 30 || launchCount == 50 || launchCount == 100 {
            if !hasShownReview {
                shouldShowReviewGuide = true
            }
        } else {
//#if DEBUG
//    shouldShowReviewGuide = true
//#endif
        }
        let isVIP = PurchaseAppState().isPurchased
        let shouldShowPurchase = launchCount >= 6 && !isVIP && canShowPurchasePrompt()
        shouldShowPurchaseView = shouldShowPurchase
    }
    
    private func canShowPurchasePrompt() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        let lastPromptDate = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date
        let nextPromptDate = UserDefaults.standard.object(forKey: nextPromptDateKey) as? Date
        if lastPromptDate == nil || nextPromptDate == nil {
            scheduleNextPrompt()
            return true
        }
        if now >= nextPromptDate! {
            scheduleNextPrompt()
            return true
        }
        
        return false
    }
    
    private func scheduleNextPrompt() {
        let now = Date()
        let calendar = Calendar.current
        let randomDays = Int.random(in: 7...10)
        let nextPromptDate = calendar.date(byAdding: .day, value: randomDays, to: now)!
        
        UserDefaults.standard.set(now, forKey: lastPromptDateKey)
        UserDefaults.standard.set(nextPromptDate, forKey: nextPromptDateKey)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        logger("下次付费提示时间: \(formatter.string(from: nextPromptDate))", tag: "LaunchCounter")
    }
    
    func markReviewGuideShown() {
        UserDefaults.standard.set(true, forKey: hasShownReviewKey)
        shouldShowReviewGuide = false
    }
    
    func markPurchasePromptShown() {
        scheduleNextPrompt()
        shouldShowPurchaseView = false
    }
    
    func resetCounters() {
        launchCount = 0
        UserDefaults.standard.removeObject(forKey: launchCountKey)
        UserDefaults.standard.removeObject(forKey: hasShownReviewKey)
        UserDefaults.standard.removeObject(forKey: lastPurchasePromptKey)
        UserDefaults.standard.removeObject(forKey: lastPromptDateKey)
        UserDefaults.standard.removeObject(forKey: nextPromptDateKey)
        shouldShowReviewGuide = false
        shouldShowPurchaseView = false
    }
}
