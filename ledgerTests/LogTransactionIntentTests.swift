//
//  LogTransactionIntentTests.swift
//  LedgerTests
//

import AppIntents
import Foundation
import SwiftData
import Testing
@testable import Ledger

@MainActor
struct LogTransactionIntentTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try makeTestContainer()
    }

    @discardableResult
    private func addCategory(_ name: String, kind: CategoryKind = .expense) -> Ledger.Category {
        let category = Ledger.Category(name: name, systemImage: "tag", categoryKind: kind)
        context.insert(category)
        return category
    }

    @discardableResult
    private func addSource(_ name: String) -> Source {
        let source = Source(name: name, systemImage: "creditcard")
        context.insert(source)
        return source
    }

    @Test func logsExpenseWithChosenCategoryAndAccount() throws {
        let food = addCategory("Food")
        let card = addSource("Card")
        addSource("Cash")
        try context.save()

        let intent = LogTransactionIntent(
            amount: 12.5, category: CategoryEntity(food), account: AccountEntity(card),
            note: "  Lunch ", date: date(2026, 10, 5)
        )
        let transaction = try intent.logTransaction(in: context)

        #expect(transaction.kind == .expense)
        #expect(transaction.amount == decimal("12.5"))
        #expect(transaction.source === card)
        #expect(transaction.destination == nil)
        #expect(transaction.category === food)
        #expect(transaction.note == "Lunch")
        #expect(transaction.date == date(2026, 10, 5))
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 1)
    }

    @Test func amountIsRoundedToCents() throws {
        addSource("Card")
        let transaction = try LogTransactionIntent(amount: 9.999).logTransaction(in: context)
        #expect(transaction.amount == 10)
        #expect(try LogTransactionIntent(amount: 0.1 + 0.2).logTransaction(in: context).amount == decimal("0.3"))
    }

    @Test(arguments: [0.0, -5.0, .infinity, .nan])
    func invalidAmountsAreRejectedWithoutSaving(amount: Double) throws {
        addSource("Card")
        #expect(throws: LedgerIntentError.self) {
            try LogTransactionIntent(amount: amount).logTransaction(in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    }

    @Test func incomeGoesToDestinationAccount() throws {
        let bank = addSource("Bank")
        let transaction = try LogTransactionIntent(amount: 2000, kind: .income, account: AccountEntity(bank)).logTransaction(in: context)
        #expect(transaction.kind == .income)
        #expect(transaction.destination === bank)
        #expect(transaction.source == nil)
    }

    @Test func categoryDecidesTheKind() throws {
        let salary = addCategory("Salary", kind: .income)
        addSource("Bank")
        let transaction = try LogTransactionIntent(amount: 100, kind: .expense, category: CategoryEntity(salary)).logTransaction(in: context)
        #expect(transaction.kind == .income)
        #expect(transaction.destination?.name == "Bank")
    }

    @Test func withoutAccountTheMostUsedOneIsSuggested() throws {
        let cash = addSource("Cash")
        let card = addSource("Card")
        for day in 1...3 {
            context.insert(Transaction(amount: 1, kind: .expense, source: card, note: "", date: date(2026, 10, day)))
        }
        context.insert(Transaction(amount: 1, kind: .expense, source: cash, note: "", date: date(2026, 10, 4)))
        try context.save()

        #expect(try LogTransactionIntent(amount: 5).logTransaction(in: context).source === card)
    }

    @Test func withoutHistoryTheFirstAccountIsUsed() throws {
        addSource("Wallet")
        #expect(try LogTransactionIntent(amount: 5).logTransaction(in: context).source?.name == "Wallet")
    }

    @Test func withoutAnyAccountItFails() throws {
        #expect(throws: LedgerIntentError.self) {
            try LogTransactionIntent(amount: 5).logTransaction(in: context)
        }
    }

    /// The Wallet automation passes the merchant as the note.
    @Test func merchantNotePicksTheLearnedCategory() throws {
        let food = addCategory("Food")
        addSource("Card")
        MerchantCategory.learn(merchant: "Konzum", category: food, source: nil, in: context)
        try context.save()

        let transaction = try LogTransactionIntent(amount: 23.4, note: "KONZUM d.d.").logTransaction(in: context)
        #expect(transaction.category === food)
    }

    @Test func incomeDoesNotUseMerchantCategories() throws {
        let food = addCategory("Food")
        addSource("Card")
        MerchantCategory.learn(merchant: "Konzum", category: food, source: nil, in: context)
        try context.save()

        #expect(try LogTransactionIntent(amount: 5, kind: .income, note: "Konzum").logTransaction(in: context).category == nil)
    }

    @Test func deletedCategoryIsReported() throws {
        addSource("Card")
        let gone = CategoryEntity(id: CategoryEntity.id(name: "Gone", kind: .expense), name: "Gone", kind: .expense, systemImage: "tag")
        #expect(throws: (any Error).self) {
            try LogTransactionIntent(amount: 5, category: gone).logTransaction(in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    }

    @Test func entityIDsSurviveRecreatingTheRecords() throws {
        let original = addCategory("Food")
        let id = CategoryEntity(original).id
        context.delete(original)
        let recreated = addCategory("Food")
        try context.save()

        let entity = CategoryEntity(id: id, name: "Food", kind: .expense, systemImage: "tag")
        #expect(try entity.model(in: context) === recreated)
        #expect(CategoryEntity(addCategory("Food", kind: .income)).id != id, "Same name, other kind")
    }
}
