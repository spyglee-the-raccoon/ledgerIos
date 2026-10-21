//
//  PlannedTransactionNotifier.swift
//  Ledger
//

import Foundation
import SwiftData
import UserNotifications

enum PlannedTransactionNotifier {
    private static let identifierPrefix = "planned_transaction_"
    private static let maxScheduled = 60

    private struct Payload: Sendable {
        let identifier: String
        let title: String
        let body: String
        let date: Date
    }

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    @MainActor
    static func reschedule(in context: ModelContext, now: Date = .now) {
        let templates = (try? context.fetch(FetchDescriptor<PlannedTransaction>(
            predicate: #Predicate { !$0.isPaused }
        ))) ?? []

        let currency = Locale.current.currency?.identifier ?? "EUR"
        let payloads: [Payload] = templates
            .compactMap { template -> (PlannedTransaction, Date)? in
                guard let due = template.nextDueDate, due > now else { return nil }
                if let end = template.endDate, due > end { return nil }
                return (template, due)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(maxScheduled)
            .enumerated()
            .map { index, item in
                let (template, due) = item
                let amount = template.amount.formatted(.currency(code: currency))
                return Payload(
                    identifier: "\(identifierPrefix)\(index)",
                    title: String(localized: "planned_transaction_performed_title"),
                    body: String(localized: "planned_transaction_performed_body \(title(for: template)) \(amount)"),
                    date: due
                )
            }

        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            for payload in payloads {
                let content = UNMutableNotificationContent()
                content.title = payload.title
                content.body = payload.body
                content.sound = .default

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: payload.date
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: payload.identifier, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    private static func title(for template: PlannedTransaction) -> String {
        if !template.note.isEmpty { return template.note }
        if template.kind == .transfer { return String(localized: "transfer") }
        if let category = template.category { return category.name }
        return String(localized: "uncategorized")
    }
}
