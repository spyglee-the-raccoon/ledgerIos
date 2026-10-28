//
//  BudgetNotifier.swift
//  Ledger
//
//  Created by Maksym Bahrov on 28.10.2026..
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
enum BudgetNotifier {
    nonisolated static let identifierPrefix = "budget_limit_"

    struct Usage {
        let budget: Budget
        let spent: Decimal

        var ratio: Double { budget.usage(of: spent) }
    }

    private struct Payload: Sendable {
        let title: String
        let body: String
    }

    /// Spending of the given month against every budget.
    static func usages(in context: ModelContext, month: DateInterval = .month(containing: .now)) -> [Usage] {
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let kind = TransactionKind.expense
        let start = month.start
        let end = month.end
        let expenses = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.kind == kind && $0.date >= start && $0.date < end
        }))) ?? []

        return budgets.map { budget in
            let spent = expenses
                .filter { budget.category == nil || $0.category == budget.category }
                .reduce(0) { $0 + $1.amount }
            return Usage(budget: budget, spent: spent)
        }
    }

    /// The general budget's usage, if it is switched on and has a limit.
    static func generalUsage(in context: ModelContext, now: Date = .now) -> Usage? {
        usages(in: context, month: .month(containing: now))
            .first { $0.budget.isGeneral && $0.budget.isActive && $0.budget.limit > 0 }
    }

    /// Notifies once per month when an active budget reaches its limit and
    /// refreshes the budget hint in the daily reminder.
    static func check(in context: ModelContext, now: Date = .now) {
        let month = DateInterval.month(containing: now)
        let currency = Locale.current.currency?.identifier ?? "EUR"
        var payloads: [Payload] = []

        for usage in usages(in: context, month: month) {
            let budget = usage.budget
            let isReached = budget.isActive && budget.limit > 0 && usage.spent >= budget.limit
            let wasAlerted = budget.lastAlertDate.map(month.contains) ?? false

            if isReached && !wasAlerted {
                budget.lastAlertDate = now
                let limit = budget.limit.formatted(.currency(code: currency))
                let body = if let category = budget.category {
                    String(localized: "budget_reached_category_body \(category.name) \(limit)")
                } else {
                    String(localized: "budget_reached_general_body \(limit)")
                }
                payloads.append(Payload(title: String(localized: "budget_reached_title"), body: body))
            } else if !isReached && wasAlerted {
                // Spending dropped below the limit again (edit or delete), so allow a new alert.
                budget.lastAlertDate = nil
            }
        }

        DailyReminder.refresh(in: context, now: now)

        guard !payloads.isEmpty else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            for payload in payloads {
                let content = UNMutableNotificationContent()
                content.title = payload.title
                content.body = payload.body
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "\(identifierPrefix)\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
                try? await center.add(request)
            }
        }
    }
}

/// Shows budget alerts as banners while the app is open, since the limit is
/// usually reached right after adding an expense in the app.
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix(BudgetNotifier.identifierPrefix) ? [.banner, .sound] : []
    }
}
