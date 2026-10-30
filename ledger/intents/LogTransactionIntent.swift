//
//  LogTransactionIntent.swift
//  Ledger
//

import AppIntents
import Foundation
import SwiftData
import SwiftUI

/// Logs an expense or income without opening the app, e.g. "Log an expense in Ledger",
/// or from a Shortcuts Wallet automation that passes the amount and merchant.
struct LogTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Transaction"
    static let description = IntentDescription("Adds an expense or income to Ledger.")
    static var supportedModes: IntentModes { .background }
    /// The store can't be read while the device is locked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "amount", requestValueDialog: "How much?")
    var amount: Double

    @Parameter(title: "kind", default: .expense)
    var kind: TransactionKindAppEnum

    /// Optional; without it the category learned for the note's merchant is used.
    @Parameter(title: "category")
    var category: CategoryEntity?

    /// Optional; without it the account used most often for this kind is used.
    @Parameter(title: "source")
    var account: AccountEntity?

    @Parameter(title: "note")
    var note: String?

    @Parameter(title: "date")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$kind) of \(\.$amount)") {
            \.$category
            \.$account
            \.$note
            \.$date
        }
    }

    init() {}

    init(amount: Double, kind: TransactionKindAppEnum = .expense, category: CategoryEntity? = nil,
         account: AccountEntity? = nil, note: String? = nil, date: Date? = nil) {
        self.amount = amount
        self.kind = kind
        self.category = category
        self.account = account
        self.note = note
        self.date = date
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let context = LedgerStore.container.mainContext
        let transaction = try logTransaction(in: context)
        LedgerIntentSupport.transactionsDidChange(in: context)

        let card = TransactionCardData(transaction)
        return .result(dialog: "Logged \(LedgerIntentSupport.formatted(transaction.amount)).") {
            TransactionCardContent(data: card, currencyCode: currency)
                .padding()
        }
    }

    /// Validates the parameters, then inserts and saves the transaction.
    @MainActor
    func logTransaction(in context: ModelContext) throws -> Transaction {
        let note = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Resolve everything first; the transaction is saved last.
        guard amount > 0, amount.isFinite else { throw LedgerIntentError.invalidAmount }
        var value = Decimal(amount)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)

        let category = try resolvedCategory(note: note, in: context)
        // A chosen category decides the kind, so "Log Salary" logs an income.
        let kind = category.map { TransactionKindAppEnum($0.categoryKind) } ?? self.kind
        let account = try resolvedAccount(for: kind.transactionKind, in: context)

        let transaction = Transaction(
            amount: rounded,
            kind: kind.transactionKind,
            source: kind == .expense ? account : nil,
            destination: kind == .income ? account : nil,
            note: note,
            date: date ?? .now,
            category: category
        )
        context.insert(transaction)
        try context.save()
        return transaction
    }

    @MainActor
    private func resolvedCategory(note: String, in context: ModelContext) throws -> Category? {
        if let category {
            guard let model = try category.model(in: context) else { throw AppIntentError.Unrecoverable.entityNotFound }
            return model
        }
        // Same merchant learning the receipt scanner uses.
        guard kind == .expense, !note.isEmpty else { return nil }
        return MerchantCategory.learned(for: note, in: context)?.category
    }

    @MainActor
    private func resolvedAccount(for kind: TransactionKind, in context: ModelContext) throws -> Source {
        if let account {
            guard let model = try account.model(in: context) else { throw AppIntentError.Unrecoverable.entityNotFound }
            return model
        }
        let role: SourceSuggestion.Role = kind == .income ? .destination : .source
        if let suggested = SourceSuggestion.mostLikely(role, for: kind, in: context) { return suggested }
        guard let first = try context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.createdAt)])).first else {
            throw LedgerIntentError.noAccount
        }
        return first
    }
}
