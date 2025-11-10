//
//  SymbolNotificationManager.swift
//  MusicAI
//
//  Created by 林恩佑 on 2025/11/11.
//


import UIKit
import UserNotifications

enum SymbolNotificationManager {

    /// 以 SF Symbol 產生圖片並附加到通知
    static func notifyWithSymbolImage(
        title: String,
        body: String,
        symbolName: String,
        pointSize: CGFloat = 72,
        weight: UIImage.SymbolWeight = .regular,
        scale: UIImage.SymbolScale = .large,
        tintColor: UIColor? = nil
    ) {
        // 1️⃣ 產生 SF Symbol 圖片
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight, scale: scale)
        guard var image = UIImage(systemName: symbolName, withConfiguration: config) else {
            NotificationManager.notify(title: title, body: body)
            return
        }
        if let tint = tintColor {
            image = image.withTintColor(tint, renderingMode: .alwaysOriginal)
        } else {
            image = image.withTintColor(.label, renderingMode: .alwaysOriginal)
        }

        // 2️⃣ 暫存成檔案
        guard let data = image.pngData(),
              let tmpURL = try? FileManager.default
                    .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent(UUID().uuidString + ".png")
        else {
            NotificationManager.notify(title: title, body: body)
            return
        }
        try? data.write(to: tmpURL)

        // 3️⃣ 附加到通知
        let attachment = try? UNNotificationAttachment(identifier: "symbol", url: tmpURL)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let attachment { content.attachments = [attachment] }

        // 4️⃣ 建立通知請求
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}