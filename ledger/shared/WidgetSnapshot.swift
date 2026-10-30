//
//  WidgetSnapshot.swift
//  Ledger
//
//  Shared with the widget extension.
//

import Foundation

nonisolated enum TransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case income, expense, transfer

    var id: String { rawValue }
}

/// What a category looks like on a card, without the SwiftData model.
nonisolated struct CategoryLabel: Codable, Hashable, Sendable {
    var name: String
    var systemImage: String
    var color: CategoryColor
}

/// Everything a budget card shows. A budget without a category is the general limit.
nonisolated struct BudgetCardData: Codable, Hashable, Sendable {
    var category: CategoryLabel?
    var limit: Decimal
    var spent: Decimal
    var isActive: Bool

    /// Share of the limit used; `0` when no limit is set.
    var usage: Double {
        guard limit > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / limit).doubleValue
    }
}

/// Everything a transaction card shows.
nonisolated struct TransactionCardData: Codable, Hashable, Sendable {
    var kind: TransactionKind
    var amount: Decimal
    var date: Date
    var note: String
    var category: CategoryLabel?
}

/// Data the app hands to its widgets through the shared App Group container.
/// The widgets can't open the SwiftData store: it's protected while the device is locked.
nonisolated struct WidgetSnapshot: Codable, Hashable, Sendable {
    struct ChartSlice: Codable, Hashable, Sendable {
        var name: String
        var amount: Decimal
        var color: CategoryColor
    }

    /// The month `budget`, `slices` and `monthBalance` were computed for.
    var month: DateInterval
    var currencyCode: String
    var budget: BudgetCardData?
    var slices: [ChartSlice]
    var monthBalance: Decimal
    var recentTransactions: [TransactionCardData]

    static let appGroup = "group.work.spyglee.ledger"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Writes the snapshot and returns `true` when it differs from the stored one.
    /// It stays readable after the first unlock so widgets can refresh while the device is locked.
    @discardableResult
    func save() throws -> Bool {
        guard let url = Self.fileURL else { return false }
        let data = try JSONEncoder().encode(self)
        if let existing = try? Data(contentsOf: url), existing == data { return false }
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return true
    }

    /// The snapshot as it should look at `date`: once its month is over, nothing
    /// has been spent or earned in the new month yet.
    func current(at date: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        guard date < month.start || date >= month.end,
              let newMonth = calendar.dateInterval(of: .month, for: date) else { return self }
        var snapshot = self
        snapshot.month = newMonth
        snapshot.budget?.spent = 0
        snapshot.slices = []
        snapshot.monthBalance = 0
        return snapshot
    }
}

/// URLs the widgets open; handled by `AppRoute(url:)`.
nonisolated enum WidgetLink {
    static let main = URL(string: "ladger://main")!
    static let budgeting = URL(string: "ladger://budgeting")!
    static let sources = URL(string: "ladger://sources")!
}

nonisolated enum WidgetKind {
    static let budget = "LedgerBudgetWidget"
    static let monthChart = "LedgerMonthChartWidget"
    static let recentTransactions = "LedgerRecentTransactionsWidget"
}
