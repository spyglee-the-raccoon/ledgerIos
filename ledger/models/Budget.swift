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
        let isChanged = budget.limit != limit
            || budget.isActive != isActive
            || budget.category?.persistentModelID != category?.persistentModelID
        if isChanged {
            budget.lastAlertDate = nil
        }
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
        BudgetCardData(self, spent: spent).usage
    }
}

extension BudgetCardData {
    init(_ budget: Budget, spent: Decimal) {
        self.init(
            category: budget.category.map { CategoryLabel($0) },
            limit: budget.limit,
            spent: spent,
            isActive: budget.isActive
        )
    }
}
