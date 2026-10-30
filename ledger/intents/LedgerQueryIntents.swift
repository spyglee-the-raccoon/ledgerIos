//
//  LedgerQueryIntents.swift
//  Ledger
//
//  Actions that answer questions about the user's money.
//

import AppIntents
import Foundation
import SwiftData
import SwiftUI

/// "How much budget is left?" — the general limit or, when it's off, the first
/// active category budget, like the budget widget. Optionally for one category.
struct BudgetLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "Budget Left"
    static let description = IntentDescription("Tells how much of this month's budget is left.")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "category")
    var category: CategoryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get budget left") { \.$category }
    }

    init() {}

    init(category: CategoryEntity?) {
        self.category = category
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog & ShowsSnippetView {
        try LedgerIntentSupport.ensureAppUnlocked()
        let context = LedgerStore.container.mainContext
        let month = DateInterval.month(containing: .now)

        let budget: BudgetCardData
        if let category {
            let usage = BudgetNotifier.usages(in: context, month: month).first {
                guard let budgetCategory = $0.budget.category else { return false }
                return CategoryEntity(budgetCategory).id == category.id
            }
            guard let usage else { throw LedgerIntentError.noBudget }
            budget = BudgetCardData(usage.budget, spent: usage.spent)
        } else {
            guard let shown = WidgetSnapshotWriter.shownBudget(in: context, month: month) else { throw LedgerIntentError.noBudget }
            budget = shown
        }

        let remaining = budget.limit - budget.spent
        let left = LedgerIntentSupport.formatted(abs(remaining))
        let limit = LedgerIntentSupport.formatted(budget.limit)
        let dialog: IntentDialog = switch (budget.category?.name, remaining >= 0) {
        case (nil, true): "You have \(left) left of your monthly limit of \(limit)."
        case (nil, false): "You're \(left) over your monthly limit of \(limit)."
        case (let name?, true): "You have \(left) left for \(name) this month, out of \(limit)."
        case (let name?, false): "You're \(left) over your \(name) budget of \(limit)."
        }
        return .result(value: NSDecimalNumber(decimal: remaining).doubleValue, dialog: dialog) {
            BudgetCardContent(data: budget, currencyCode: currency)
                .padding()
        }
    }
}

/// "How much did I spend this month?" — this month's spending, income and balance,
/// or the total for one category.
struct MonthSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Spending This Month"
    static let description = IntentDescription("Tells this month's spending, income and balance.")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "category")
    var category: CategoryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get this month's spending") { \.$category }
    }

    init() {}

    init(category: CategoryEntity?) {
        self.category = category
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        try LedgerIntentSupport.ensureAppUnlocked()
        let context = LedgerStore.container.mainContext
        let month = DateInterval.month(containing: .now)
        let start = month.start
        let end = month.end
        let transactions = try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.date >= start && $0.date < end
        }))
        func total(_ kind: TransactionKind) -> Decimal {
            transactions.filter { $0.kind == kind }.reduce(0) { $0 + $1.amount }
        }

        if let category {
            let inCategory = transactions.filter { $0.category.map { CategoryEntity($0).id } == category.id }
            let sum = inCategory.reduce(Decimal(0)) { $0 + $1.amount }
            let amount = LedgerIntentSupport.formatted(sum)
            let dialog: IntentDialog = category.kind == .income
                ? "You received \(amount) from \(category.name) this month."
                : "You spent \(amount) on \(category.name) this month."
            return .result(value: NSDecimalNumber(decimal: sum).doubleValue, dialog: dialog)
        }

        // Same balance as the chart on the main screen: incomes minus expenses.
        let spent = total(.expense)
        let balance = total(.income) - spent
        let dialog: IntentDialog = "This month you spent \(LedgerIntentSupport.formatted(spent)) and earned \(LedgerIntentSupport.formatted(total(.income))). Your balance is \(LedgerIntentSupport.formatted(balance))."
        return .result(value: NSDecimalNumber(decimal: spent).doubleValue, dialog: dialog)
    }
}

/// "What's my Card balance?" — one account's balance, or the total of all accounts.
struct AccountBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Account Balance"
    static let description = IntentDescription("Tells the balance of an account, or of all accounts.")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    /// Without an account the total balance of all accounts is used.
    @Parameter(title: "source")
    var account: AccountEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get balance of \(\.$account)")
    }

    init() {}

    init(account: AccountEntity?) {
        self.account = account
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        try LedgerIntentSupport.ensureAppUnlocked()
        let context = LedgerStore.container.mainContext
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        if let account {
            guard let source = try account.model(in: context) else { throw AppIntentError.Unrecoverable.entityNotFound }
            // Same as the accounts screen: transfers move money between accounts.
            let incoming = transactions.filter { $0.kind != .expense && $0.destination == source }.reduce(Decimal(0)) { $0 + $1.amount }
            let outgoing = transactions.filter { $0.kind != .income && $0.source == source }.reduce(Decimal(0)) { $0 + $1.amount }
            let balance = source.initValue + incoming - outgoing
            return .result(
                value: NSDecimalNumber(decimal: balance).doubleValue,
                dialog: "Your \(source.name) balance is \(LedgerIntentSupport.formatted(balance))."
            )
        }

        // Same as the total on the main screen.
        let initial = try context.fetch(FetchDescriptor<Source>()).reduce(Decimal(0)) { $0 + $1.initValue }
        let incomes = transactions.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amount }
        let expenses = transactions.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
        let balance = initial + incomes - expenses
        return .result(
            value: NSDecimalNumber(decimal: balance).doubleValue,
            dialog: "Your total balance is \(LedgerIntentSupport.formatted(balance))."
        )
    }
}

// MARK: - Asking for the category or account

// Phrases that name a category or account ("Ledger spending on Groceries") only work
// once the system has indexed the names. These versions ask for the name instead, so
// "Ledger spending by category" works with any category, including new ones.

/// Asks which category, then answers like `BudgetLeftIntent`.
struct CategoryBudgetLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "Category Budget Left"
    static let description = IntentDescription("Asks for a category and tells how much of its budget is left.")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "category", requestValueDialog: "Which category?")
    var category: CategoryEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog & ShowsSnippetView {
        try await BudgetLeftIntent(category: category).perform()
    }
}

/// Asks which category, then answers like `MonthSummaryIntent`.
struct CategorySpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Category Spending"
    static let description = IntentDescription("Asks for a category and tells this month's total for it.")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "category", requestValueDialog: "Which category?")
    var category: CategoryEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        try await MonthSummaryIntent(category: category).perform()
    }
}

/// Asks which account, then answers like `AccountBalanceIntent`.
struct AskAccountBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Balance of an Account"
    static let description = IntentDescription("Asks for an account and tells its balance.")
    static var supportedModes: IntentModes { .background }
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "source", requestValueDialog: "Which account?")
    var account: AccountEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        try await AccountBalanceIntent(account: account).perform()
    }
}
