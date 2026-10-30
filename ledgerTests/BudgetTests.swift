//
//  BudgetTests.swift
//  LedgerTests
//

import Foundation
import SwiftData
import Testing
@testable import Ledger

struct BudgetUsageTests {
    @Test(arguments: [
        (100, 0, 0.0),
        (100, 25, 0.25),
        (100, 100, 1.0),
        (100, 150, 1.5),
        (0, 50, 0.0),
    ] as [(Decimal, Decimal, Double)])
    func usageIsShareOfLimit(limit: Decimal, spent: Decimal, expected: Double) {
        #expect(Budget(limit: limit).usage(of: spent) == expected)
    }

    @Test func budgetWithoutCategoryIsGeneral() {
        #expect(Budget(limit: 100).isGeneral)
        #expect(!Budget(limit: 100, category: Category(name: "Food")).isGeneral)
    }

    @Test func monthIntervalCoversWholeMonth() {
        let month = DateInterval.month(containing: date(2028, 2, 14, calendar: utcCalendar), calendar: utcCalendar)
        #expect(month.start == date(2028, 2, 1, hour: 0, calendar: utcCalendar))
        #expect(month.end == date(2028, 3, 1, hour: 0, calendar: utcCalendar))
    }
}

@MainActor
struct BudgetDraftTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try makeTestContainer()
    }

    @Test func unchangedDraftKeepsAlertDate() {
        let budget = Budget(limit: 100)
        context.insert(budget)
        budget.lastAlertDate = date(2026, 10, 5)

        BudgetDraft(budget).apply(to: budget)

        #expect(budget.lastAlertDate == date(2026, 10, 5))
    }

    @Test func changedLimitResetsAlertDate() {
        let budget = Budget(limit: 100)
        context.insert(budget)
        budget.lastAlertDate = date(2026, 10, 5)

        var draft = BudgetDraft(budget)
        draft.limit = 200
        draft.apply(to: budget)

        #expect(budget.limit == 200)
        #expect(budget.lastAlertDate == nil)
    }

    @Test func changedCategoryResetsAlertDate() {
        let food = Category(name: "Food")
        context.insert(food)
        let budget = Budget(limit: 100)
        context.insert(budget)
        budget.lastAlertDate = date(2026, 10, 5)

        var draft = BudgetDraft(budget)
        draft.category = food
        draft.apply(to: budget)

        #expect(budget.category === food)
        #expect(budget.lastAlertDate == nil)
    }

    @Test func toggledActiveResetsAlertDate() {
        let budget = Budget(limit: 100)
        context.insert(budget)
        budget.lastAlertDate = date(2026, 10, 5)

        var draft = BudgetDraft(budget)
        draft.isActive = false
        draft.apply(to: budget)

        #expect(!budget.isActive)
        #expect(budget.lastAlertDate == nil)
    }
}

@MainActor
struct BudgetNotifierTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let food: Ledger.Category
    let rent: Ledger.Category
    let now = date(2026, 10, 15)

    init() throws {
        container = try makeTestContainer()
        food = Category(name: "Food")
        rent = Category(name: "Rent")
        container.mainContext.insert(food)
        container.mainContext.insert(rent)
    }

    private func addExpense(_ amount: Decimal, _ category: Ledger.Category?, on day: Date) {
        context.insert(Transaction(amount: amount, kind: .expense, note: "", date: day, category: category))
    }

    private func usage(of budget: Budget) -> BudgetNotifier.Usage? {
        BudgetNotifier.usages(in: context, month: .month(containing: now)).first { $0.budget === budget }
    }

    @Test func generalBudgetCountsAllExpensesOfTheMonth() throws {
        let general = Budget(limit: 500)
        context.insert(general)
        addExpense(100, food, on: date(2026, 10, 1, hour: 0))
        addExpense(50, rent, on: date(2026, 10, 31, hour: 23))
        addExpense(25, nil, on: date(2026, 10, 10))
        addExpense(999, food, on: date(2026, 9, 30, hour: 23))
        addExpense(999, food, on: date(2026, 11, 1, hour: 0))
        context.insert(Transaction(amount: 999, kind: .income, note: "", date: date(2026, 10, 10)))
        context.insert(Transaction(amount: 999, kind: .transfer, note: "", date: date(2026, 10, 10)))
        try context.save()

        #expect(usage(of: general)?.spent == 175)
    }

    @Test func categoryBudgetCountsOnlyItsCategory() throws {
        let foodBudget = Budget(limit: 200, category: food)
        context.insert(foodBudget)
        addExpense(80, food, on: date(2026, 10, 3))
        addExpense(70, food, on: date(2026, 10, 4))
        addExpense(300, rent, on: date(2026, 10, 5))
        try context.save()

        let result = try #require(usage(of: foodBudget))
        #expect(result.spent == 150)
        #expect(result.ratio == 0.75)
    }

    @Test func generalUsageIgnoresInactiveOrUnlimitedBudgets() throws {
        context.insert(Budget(limit: 500, isActive: false))
        context.insert(Budget(limit: 200, category: food))
        try context.save()
        #expect(BudgetNotifier.generalUsage(in: context, now: now) == nil)

        let unlimited = Budget(limit: 0)
        context.insert(unlimited)
        try context.save()
        #expect(BudgetNotifier.generalUsage(in: context, now: now) == nil)

        unlimited.limit = 300
        #expect(BudgetNotifier.generalUsage(in: context, now: now)?.budget === unlimited)
    }

    @Test func checkMarksReachedBudgetAsAlerted() throws {
        let budget = Budget(limit: 100, category: food)
        context.insert(budget)
        addExpense(100, food, on: date(2026, 10, 3))
        try context.save()

        BudgetNotifier.check(in: context, now: now)

        #expect(budget.lastAlertDate == now)
    }

    @Test func checkIgnoresBudgetsBelowLimitOrInactive() throws {
        let below = Budget(limit: 100, category: food)
        let inactive = Budget(limit: 10, isActive: false, category: rent)
        context.insert(below)
        context.insert(inactive)
        addExpense(99, food, on: date(2026, 10, 3))
        addExpense(50, rent, on: date(2026, 10, 3))
        try context.save()

        BudgetNotifier.check(in: context, now: now)

        #expect(below.lastAlertDate == nil)
        #expect(inactive.lastAlertDate == nil)
    }

    @Test func checkAlertsOncePerMonth() throws {
        let budget = Budget(limit: 100)
        context.insert(budget)
        addExpense(150, food, on: date(2026, 10, 3))
        try context.save()

        BudgetNotifier.check(in: context, now: date(2026, 10, 5))
        BudgetNotifier.check(in: context, now: date(2026, 10, 20))
        #expect(budget.lastAlertDate == date(2026, 10, 5))

        addExpense(150, food, on: date(2026, 11, 2))
        try context.save()
        BudgetNotifier.check(in: context, now: date(2026, 11, 3))
        #expect(budget.lastAlertDate == date(2026, 11, 3))
    }
}
