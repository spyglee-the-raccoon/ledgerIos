//
//  ModelLogicTests.swift
//  LedgerTests
//

import Foundation
import SwiftData
import Testing
@testable import Ledger

struct MerchantNormalizationTests {
    @Test(arguments: [
        ("Konzum plus d.o.o.", "konzum plus"),
        ("KONZUM PLUS D.O.O.", "konzum plus"),
        ("TISAK d.d.", "tisak"),
        ("Pekara Čokolada, obrt", "pekara cokolada"),
        ("Müller Ltd", "muller"),
        ("  Lidl   Hrvatska  ", "lidl hrvatska"),
        ("d.o.o.", ""),
    ])
    func dropsCaseDiacriticsAndLegalForms(merchant: String, expected: String) {
        #expect(MerchantCategory.normalize(merchant) == expected)
    }
}

@MainActor
struct MerchantLearningTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let food = Category(name: "Food")
    let cafe = Category(name: "Cafe")

    init() throws {
        container = try makeTestContainer()
        container.mainContext.insert(food)
        container.mainContext.insert(cafe)
    }

    @Test func learnedMappingIsFoundByAnySpelling() throws {
        let card = Source(name: "Card")
        context.insert(card)
        MerchantCategory.learn(merchant: "Konzum d.o.o.", category: food, source: card, in: context)
        try context.save()

        let mapping = try #require(MerchantCategory.learned(for: "KONZUM", in: context))
        #expect(mapping.category === food)
        #expect(mapping.source === card)
    }

    @Test func learningAgainUpdatesTheExistingMapping() throws {
        MerchantCategory.learn(merchant: "Konzum", category: food, source: nil, in: context)
        try context.save()
        MerchantCategory.learn(merchant: "konzum d.d.", category: cafe, source: nil, in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<MerchantCategory>()) == 1)
        #expect(MerchantCategory.learned(for: "Konzum", in: context)?.category === cafe)
    }

    @Test func longerOrShorterNameMatchesByWholeWordPrefix() throws {
        MerchantCategory.learn(merchant: "Konzum", category: food, source: nil, in: context)
        MerchantCategory.learn(merchant: "Caffe Bar Luka", category: cafe, source: nil, in: context)
        try context.save()

        #expect(MerchantCategory.learned(for: "Konzum Plus", in: context)?.category === food)
        #expect(MerchantCategory.learned(for: "Caffe Bar", in: context)?.category === cafe)
        #expect(MerchantCategory.learned(for: "Konzumacija", in: context) == nil)
    }

    @Test func emptyMerchantIsNeitherLearnedNorFound() throws {
        MerchantCategory.learn(merchant: "d.o.o.", category: food, source: nil, in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<MerchantCategory>()) == 0)
        #expect(MerchantCategory.learned(for: "", in: context) == nil)
    }
}

@MainActor
struct SourceSuggestionTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let cash = Source(name: "Cash")
    let card = Source(name: "Card")
    let bank = Source(name: "Bank")

    init() throws {
        container = try makeTestContainer()
        [cash, card, bank].forEach(container.mainContext.insert)
    }

    /// Adds transactions oldest first, one day apart.
    private func add(_ kind: TransactionKind, sources: [Source], destinations: [Source?]? = nil) throws {
        for (index, source) in sources.enumerated() {
            let destination = destinations?[index] ?? nil
            let isIncome = kind == .income
            context.insert(Transaction(
                amount: 1, kind: kind,
                source: isIncome ? nil : source,
                destination: isIncome ? source : destination,
                note: "", date: date(2026, 10, 1 + index)
            ))
        }
        try context.save()
    }

    @Test func noHistoryMeansNoSuggestion() {
        #expect(SourceSuggestion.mostLikely(.source, for: .expense, in: context) == nil)
    }

    @Test func mostFrequentAccountWins() throws {
        try add(.expense, sources: [card, card, card, cash])
        #expect(SourceSuggestion.mostLikely(.source, for: .expense, in: context) === card)
    }

    @Test func tieGoesToMostRecentlyUsed() throws {
        try add(.expense, sources: [cash, card, cash, card])
        #expect(SourceSuggestion.mostLikely(.source, for: .expense, in: context) === card)
    }

    @Test func otherKindsAreIgnored() throws {
        try add(.expense, sources: [cash])
        try add(.income, sources: [bank, bank, bank])
        #expect(SourceSuggestion.mostLikely(.source, for: .expense, in: context) === cash)
        #expect(SourceSuggestion.mostLikely(.destination, for: .income, in: context) === bank)
    }

    @Test func excludedAccountIsSkipped() throws {
        try add(.transfer, sources: [bank, bank, card], destinations: [cash, cash, bank])
        #expect(SourceSuggestion.mostLikely(.destination, for: .transfer, in: context) === cash)
        #expect(SourceSuggestion.mostLikely(.destination, for: .transfer, excluding: cash, in: context) === bank)
    }

    @Test func onlyRecentHistoryCounts() throws {
        // 40 old uses of cash are pushed out of the 30-transaction window by newer card uses.
        try add(.expense, sources: Array(repeating: cash, count: 40) + Array(repeating: card, count: 30))
        #expect(SourceSuggestion.mostLikely(.source, for: .expense, in: context) === card)
    }
}

@MainActor
struct TransactionSearchTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try makeTestContainer()
    }

    private func makeTransaction(note: String = "", category: String? = nil, items: [String] = []) throws -> Transaction {
        let transaction = Transaction(
            amount: 1, kind: .expense, note: note, date: .now,
            category: category.map { Category(name: $0) }
        )
        context.insert(transaction)
        for (position, name) in items.enumerated() {
            let item = ReceiptItem(name: name, quantity: 1, unitPrice: 1, totalPrice: 1, position: position)
            context.insert(item)
            item.transaction = transaction
        }
        try context.save()
        return transaction
    }

    @Test func matchesNoteIgnoringCaseAndDiacritics() throws {
        let transaction = try makeTransaction(note: "Ručak s prijateljima")
        #expect(transaction.matches("rucak"))
        #expect(transaction.matches("PRIJATELJ"))
        #expect(!transaction.matches("večera"))
    }

    @Test func matchesCategoryName() throws {
        #expect(try makeTransaction(category: "Groceries").matches("grocer"))
    }

    @Test func matchesReceiptItems() throws {
        let transaction = try makeTransaction(note: "Konzum", items: ["MLIJEKO 1L", "Kruh"])
        #expect(transaction.matches("mlijeko"))
        #expect(transaction.matches("kruh"))
        #expect(!transaction.matches("jaja"))
    }
}

struct ReceiptItemNormalizationTests {
    @Test(arguments: [
        ("Mlijeko  1L", "mlijeko 1l"),
        ("  MLIJEKO 1l ", "mlijeko 1l"),
        ("ČOKOLADA\tMILKA", "cokolada milka"),
    ])
    func ignoresCaseDiacriticsAndSpacing(name: String, expected: String) {
        #expect(ReceiptItem.normalize(name) == expected)
    }

    @Test func initStoresNormalizedName() {
        #expect(ReceiptItem(name: "Kruh  Bijeli", quantity: 1, unitPrice: 1, totalPrice: 1, position: 0).normalizedName == "kruh bijeli")
    }
}
