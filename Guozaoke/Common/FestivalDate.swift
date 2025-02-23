//
//  FestivalDate.swift
//  Guozaoke
//
//  Created by scy on 2025/2/12.
//

import Foundation


class FestivalDate {
    
    
    static func getFestivalGreeting() -> String {
        let userName = AccountState.userName
        var text     = todayEvents() ?? "欢迎进入过早客"
        if !userName.isEmpty {
            text = userName + " " + text
        }
        return text
    }
    
    /// 节日或欢迎进入过早客
    static func todayEvents() -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        let festivalMessages: [String: String] = festivalDate2025()
        let text = festivalMessages[today] ?? nil
        return text
    }
    
    static func getCurrentYear() -> String {
        let currentYear = Calendar.current.component(.year, from: Date())
        if currentYear == 2025 {
            return "2025"
        } else if currentYear == 2026 {
            return "2026"
        } else {
            return ""
        }
    }
    
    static func festivalDate2025() -> [String: String] {
        if getCurrentYear() == "2026" {
            return festivalDate2026()
        }
        return [
            
            "2025-01-28": "除夕快乐！",
            "2025-01-29": "新年快乐！",
            "2025-02-12": "元宵节快乐！",
            "2025-05-01": "劳动节快乐！",
            "2025-06-20": "端午节快乐！",
            "2025-08-15": "中秋节快乐！",
            "2025-10-01": "国庆节快乐！",
            
            "2025-02-03": "立春",
            "2025-02-18": "雨水",
            "2025-03-05": "惊蛰",
            "2025-03-20": "春分",
            "2025-04-04": "清明",
            "2025-04-20": "谷雨",
            "2025-05-05": "立夏",
            "2025-05-21": "小满",
            "2025-06-05": "芒种",
            "2025-06-21": "夏至",
            "2025-07-07": "小暑",
            "2025-07-22": "大暑",
            "2025-08-07": "立秋",
            "2025-08-23": "处暑",
            "2025-09-07": "白露",
            "2025-09-23": "秋分",
            "2025-10-08": "寒露",
            "2025-10-23": "霜降",
            "2025-11-07": "立冬",
            "2025-11-21": "小雪",
            "2025-12-07": "大雪",
            "2025-12-21": "冬至"
        ]
    }
    
    static func festivalDate2026 () -> [String: String] {
        return [
            "2026-01-05": "大雪",
            "2026-01-20": "冬至",
            "2026-02-17": "除夕快乐！",
            "2026-05-01": "劳动节快乐！",
            "2026-06-25": "端午节快乐！",
            "2026-09-26": "中秋节快乐！",
            "2026-10-01": "国庆节快乐！",

            // 24节气
            "2026-02-04": "立春",
            "2026-02-18": "雨水",
            "2026-03-05": "惊蛰",
            "2026-03-20": "春分",
            "2026-04-05": "清明",
            "2026-04-20": "谷雨",
            "2026-05-05": "立夏",
            "2026-05-21": "小满",
            "2026-06-05": "芒种",
            "2026-06-21": "夏至",
            "2026-07-07": "小暑",
            "2026-07-23": "大暑",
            "2026-08-07": "立秋",
            "2026-08-23": "处暑",
            "2026-09-07": "白露",
            "2026-09-23": "秋分",
            "2026-10-08": "寒露",
            "2026-10-23": "霜降",
            "2026-11-07": "立冬",
            "2026-11-22": "小雪",
            "2026-12-07": "大雪",
            "2026-12-22": "冬至",
            "2027-01-05": "小寒",
            "2027-01-20": "大寒"
        ]
    }
}
