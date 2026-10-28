//
//  Budget.swift
//  Ledger
//
//  Created by Maksym Bahrov on 28.10.2026..
//

import Foundation
import SwiftData

struct BudgetDraft {
    var limit: Decimal = 0
    var isActive: Bool = true
    var category: Category?

    init() {}

    init(_ budget: Budget) {
        limit = budget.limit
        isActive = budget.isActive
        category = budget.category
    }

    func apply(to budget: Budget) {
        budget.limit = limit
        budget.isActive = isActive
        budget.category = category
    }
}

/// A monthly spending limit. A budget without a category is the general
/// monthly limit and covers every expense; otherwise it covers one category.
@Model
final class Budget {
    var limit: Decimal = 0
    var isActive: Bool = true
    var category: Category?
    /// When the "limit reached" notification was last sent, so it fires once per month.
    var lastAlertDate: Date?

    var isGeneral: Bool { category == nil }

    init(limit: Decimal, isActive: Bool = true, category: Category? = nil) {
        self.limit = limit
        self.isActive = isActive
        self.category = category
    }

    /// Share of the limit used by `spent`; `0` when no limit is set.
    func usage(of spent: Decimal) -> Double {
        guard limit > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / limit).doubleValue
    }
}
