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
        NotificationPresenter.shared.present(text, includedStyle: includedStyle, duration: toastDuration)
    }
    
    static func toastText(_ text: String, subtitle: String? = nil) {
        toast(text, subtitle: subtitle, text == needLoginTextCanDo ? .warning: .dark)
    }
    
    static func reportToast() {
        
        runInMain(delay: 1) {
            toast("谢谢反馈，我们已收到", subtitle: "", .success)
        }
    }
}
