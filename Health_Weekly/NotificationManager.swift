//
//  NotificationManager.swift
//  Health_Weekly
//
//  Created by Riccardo Pinna on 29/1/26.
//

import Foundation
import UserNotifications

func notifyWeeklyReportSent() {
    let content = UNMutableNotificationContent()
    content.title = "Report settimanale inviato"
    content.body = "Il report è stato inviato automaticamente via email."
    content.sound = .default

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil // immediata
    )

    UNUserNotificationCenter.current().add(request)
}
