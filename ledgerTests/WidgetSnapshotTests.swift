//
//  WidgetSnapshotTests.swift
//  LedgerTests
//

import Foundation
import SwiftData
import Testing
@testable import Ledger

@MainActor
struct WidgetSnapshotTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = date(2026, 10, 15)

    init() throws {
        container = try makeTestContainer()
    }

    private func category(_ name: String, color: CategoryColor = .blue) -> Ledger.Category {
        let category = Ledger.Category(name: name, systemImage: "tag", color: color)
        context.insert(category)
        return category
    }

    private func addExpense(_ amount: Decimal, _ category: Ledger.Category?, on day: Date, note: String = "") {
        context.insert(Transaction(amount: amount, kind: .expense, note: note, date: day, category: category))
    }

    private func snapshot() throws -> WidgetSnapshot {
        try context.save()
        return WidgetSnapshotWriter.makeSnapshot(in: context, now: now)
    }

    @Test func showsGeneralBudgetWhenSetAndActive() throws {
        let food = category("Food")
        context.insert(Budget(limit: 500))
        context.insert(Budget(limit: 100, category: food))
        addExpense(40, food, on: date(2026, 10, 3))

        let budget = try #require(try snapshot().budget)
        #expect(budget.category == nil)
        #expect(budget.limit == 500)
        #expect(budget.spent == 40)
    }

    @Test(arguments: [(Decimal(500), false), (0, true)])
    func fallsBackToFirstActiveCategoryBudget(generalLimit: Decimal, generalActive: Bool) throws {
        let rent = category("Rent")
        let food = category("Food")
        let cafe = category("Cafe")
        context.insert(Budget(limit: generalLimit, isActive: generalActive))
        context.insert(Budget(limit: 900, category: rent))
        context.insert(Budget(limit: 100, category: food))
        context.insert(Budget(limit: 50, isActive: false, category: cafe))
        addExpense(30, food, on: date(2026, 10, 3))
        addExpense(800, rent, on: date(2026, 10, 1))

        let budget = try #require(try snapshot().budget)
        #expect(budget.category?.name == "Food", "Alphabetically first active category budget")
        #expect(budget.spent == 30)
    }

    @Test func noActiveBudgetShowsNone() throws {
        context.insert(Budget(limit: 500, isActive: false))
        #expect(try snapshot().budget == nil)
    }

    @Test func chartAndBalanceCoverOnlyThisMonth() throws {
        let food = category("Food", color: .green)
        let rent = category("Rent", color: .red)
        addExpense(30, food, on: date(2026, 10, 2))
        addExpense(20, food, on: date(2026, 10, 9))
        addExpense(400, rent, on: date(2026, 10, 1))
        addExpense(5, nil, on: date(2026, 10, 4))
        addExpense(999, food, on: date(2026, 9, 30))
        context.insert(Transaction(amount: 1000, kind: .income, note: "", date: date(2026, 10, 1)))
        context.insert(Transaction(amount: 300, kind: .transfer, note: "", date: date(2026, 10, 1)))

        let result = try snapshot()
        #expect(result.slices.map(\.amount) == [400, 50, 5], "Largest first, uncategorized included")
        #expect(result.slices.map(\.color) == [.red, .green, .gray])
        #expect(result.monthBalance == 545)
    }

    @Test func recentTransactionsAreTheLatestThreeOfAnyKind() throws {
        let food = category("Food")
        addExpense(1, food, on: date(2026, 9, 1), note: "old")
        addExpense(2, food, on: date(2026, 10, 1), note: "second")
        context.insert(Transaction(amount: 3, kind: .income, note: "third", date: date(2026, 10, 5)))
        context.insert(Transaction(amount: 4, kind: .transfer, note: "latest", date: date(2026, 10, 14)))

        let recent = try snapshot().recentTransactions
        #expect(recent.map(\.note) == ["latest", "third", "second"])
        #expect(recent.map(\.kind) == [.transfer, .income, .expense])
        #expect(recent.last?.category?.name == "Food")
    }

    @Test func nextMonthStartsEmptyButKeepsRecentTransactions() throws {
        let food = category("Food")
        context.insert(Budget(limit: 500))
        addExpense(40, food, on: date(2026, 10, 3))
        let october = try snapshot()

        #expect(october.current(at: date(2026, 10, 31, hour: 23)) == october)

        let november = october.current(at: date(2026, 11, 1, hour: 0))
        #expect(november.budget?.spent == 0)
        #expect(november.budget?.limit == 500)
        #expect(november.slices.isEmpty)
        #expect(november.monthBalance == 0)
        #expect(november.recentTransactions == october.recentTransactions)
        #expect(november.month.start == date(2026, 11, 1, hour: 0))
    }

    @Test func survivesJSONRoundTrip() throws {
        let food = category("Food")
        context.insert(Budget(limit: decimal("250.5"), category: food))
        addExpense(decimal("12.99"), food, on: date(2026, 10, 3), note: "Lunch")
        let original = try snapshot()

        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test(arguments: [
        ("ladger://main", AppRoute.main),
        ("ladger://budgeting", .budgeting),
        ("ladger://sources", .sources),
    ] as [(String, AppRoute)])
    func widgetLinksOpenTheirScreens(link: String, route: AppRoute) throws {
        #expect(AppRoute(url: try #require(URL(string: link))) == route)
    }

    @Test func otherLinksAreNotRoutes() throws {
        #expect(AppRoute(url: try #require(URL(string: "ladger://scan?text=abc"))) == nil)
        #expect(AppRoute(url: try #require(URL(string: "https://budgeting"))) == nil)
    }
}
