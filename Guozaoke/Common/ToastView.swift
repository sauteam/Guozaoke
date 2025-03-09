//
//  ToastView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/9.
//

import Foundation
import JDStatusBarNotification

class ToastView {
    static func toast(_ text: String, subtitle: String? = nil, _ includedStyle: IncludedStatusBarNotificationStyle) {
        if text.isEmpty {
            if subtitle.isEmpty {
                return
            }
        }
        NotificationPresenter.shared.present(text, includedStyle: includedStyle, duration: toastDuration)
    }
    
    static func toastText(_ text: String, subtitle: String? = nil) {
        toast(text, subtitle: subtitle, text == needLoginTextCanDo ? .warning: .dark)
    }
    
    static func warningToast(_ text: String, subtitle: String? = nil) {
        toast(text, subtitle: subtitle, .warning)
    }
    
    static func errorToast(_ text: String, subtitle: String? = nil) {
        toast(text, subtitle: subtitle, .error)
    }
    
    static func successToast(_ text: String, subtitle: String? = nil) {
        toast(text, subtitle: subtitle, .success)
    }
    
    static func reportToast() {
        runInMain(delay: 1) {
            successToast("谢谢反馈，我们已收到", subtitle: "")
            hapticFeedback()
        }
    }
}
