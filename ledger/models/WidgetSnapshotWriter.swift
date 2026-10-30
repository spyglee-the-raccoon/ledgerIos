//
//  WidgetSnapshotWriter.swift
//  Ledger
//

import Foundation
import SwiftData
import WidgetKit

/// Computes what the widgets show and shares it with them.
enum WidgetSnapshotWriter {
    private static let recentTransactionCount = 3

    static func update(in context: ModelContext, now: Date = .now) {
        let snapshot = makeSnapshot(in: context, now: now)
        if (try? snapshot.save()) == true {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func makeSnapshot(in context: ModelContext, now: Date = .now) -> WidgetSnapshot {
        let month = DateInterval.month(containing: now)
        let start = month.start
        let end = month.end
        let monthTransactions = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.date >= start && $0.date < end
        }))) ?? []
        let expenses = monthTransactions.filter { $0.kind == .expense }
        let incomes = monthTransactions.filter { $0.kind == .income }

        var recent = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        recent.fetchLimit = recentTransactionCount
        let recentTransactions = (try? context.fetch(recent)) ?? []

        return WidgetSnapshot(
            month: month,
            currencyCode: currency,
            budget: shownBudget(in: context, month: month),
            slices: slices(for: expenses),
            monthBalance: incomes.reduce(0) { $0 + $1.amount } - expenses.reduce(0) { $0 + $1.amount },
            recentTransactions: recentTransactions.map { TransactionCardData($0) }
        )
    }

    /// The general limit when it's set and on, otherwise the first active category budget.
    static func shownBudget(in context: ModelContext, month: DateInterval) -> BudgetCardData? {
        let usages = BudgetNotifier.usages(in: context, month: month)
            .filter { $0.budget.isActive && $0.budget.limit > 0 }
        let shown = usages.first { $0.budget.isGeneral }
            ?? usages
                .filter { !$0.budget.isGeneral }
                .min { ($0.budget.category?.name ?? "").localizedStandardCompare($1.budget.category?.name ?? "") == .orderedAscending }
        return shown.map { BudgetCardData($0.budget, spent: $0.spent) }
    }

    /// Spending per category, largest first, like the chart on the main screen.
    private static func slices(for expenses: [Transaction]) -> [WidgetSnapshot.ChartSlice] {
        var byCategory: [PersistentIdentifier: WidgetSnapshot.ChartSlice] = [:]
        var uncategorized = WidgetSnapshot.ChartSlice(name: String(localized: "uncategorized"), amount: 0, color: .gray)
        for expense in expenses {
            if let category = expense.category {
                byCategory[category.persistentModelID, default: .init(name: category.name, amount: 0, color: category.color)]
                    .amount += expense.amount
            } else {
                uncategorized.amount += expense.amount
            }
        }
        var slices = Array(byCategory.values)
        if uncategorized.amount > 0 { slices.append(uncategorized) }
        return slices.sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.name < $1.name }
    }
}
