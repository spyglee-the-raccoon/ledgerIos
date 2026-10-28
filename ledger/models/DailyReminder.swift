//
//  DailyReminder.swift
//  ledger
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
enum DailyReminder {
    static let storageKey = "isReminderOn"
    private static let identifier = "daily_reminder"

    static func enable(in context: ModelContext) async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return false
            }
        } catch {
            return false
        }
        return await schedule(body: body(in: context))
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Re-schedules the reminder so its text reflects the current general budget.
    /// The repeating notification keeps the last text until the app updates it again.
    static func refresh(in context: ModelContext, now: Date = .now) {
        guard UserDefaults.standard.bool(forKey: storageKey) else { return }
        let body = body(in: context, now: now)
        Task { _ = await schedule(body: body) }
    }

    private static func schedule(body: String) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder_title")
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        // Adding a request with the same identifier replaces the pending one.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    private static func body(in context: ModelContext, now: Date = .now) -> String {
        let reminder = String(localized: "reminder_body")
        guard let usage = BudgetNotifier.generalUsage(in: context, now: now) else { return reminder }
        return "\(reminder)\n\(budgetMessage(for: usage))"
    }

    /// One of seven hints depending on how much of the general limit is used.
    private static func budgetMessage(for usage: BudgetNotifier.Usage) -> String {
        let currency = Locale.current.currency?.identifier ?? "EUR"
        let remaining = (usage.budget.limit - usage.spent).formatted(.currency(code: currency))
        let over = (usage.spent - usage.budget.limit).formatted(.currency(code: currency))

        switch usage.ratio {
        case ..<0.25:
            return String(localized: "budget_hint_well_under")
        case ..<0.5:
            return String(localized: "budget_hint_under_half")
        case ..<0.75:
            return String(localized: "budget_hint_over_half")
        case ..<0.9:
            return String(localized: "budget_hint_getting_close")
        case ..<1:
            return String(localized: "budget_hint_almost \(remaining)")
        case ..<1.1:
            return String(localized: "budget_hint_reached")
        default:
            return String(localized: "budget_hint_over \(over)")
        }
    }
}
