//
//  DailyReminder.swift
//  budget tracker
//

import Foundation
import UserNotifications

enum DailyReminder {
    static let storageKey = "isReminderOn"
    private static let identifier = "daily_reminder"

    static func enable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return false
            }
        } catch {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder_title")
        content.body = String(localized: "reminder_body")
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
