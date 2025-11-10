//
//  NotifyOrToast.swift
//  MusicAI
//
//  Created by 林恩佑 on 2025/11/11.
//


import UserNotifications
import UIKit

enum NotifyOrToast {
    static func send(title: String, body: String, symbolName: String = "sparkles") {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized = (settings.authorizationStatus == .authorized)
            if authorized {
                // 有權限 → 用你現有的圖像通知
                SymbolNotificationManager.notifyWithSymbolImage(
                    title: title,
                    body: body,
                    symbolName: symbolName,
                    tintColor: .label,
                    
                )
            } else {
                // 無權限/免費帳號真機 → 顯示 App 內 Toast
                ToastCenter.shared.show(title: title, message: body, symbolName: symbolName, duration: 2.0)
            }
        }
    }
}
