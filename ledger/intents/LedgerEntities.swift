//
//  LedgerEntities.swift
//  Ledger
//
//  Categories and accounts as Siri and Shortcuts see them.
//

import AppIntents
import Foundation
import SwiftData

/// Kinds of transaction an action can log. Raw values are stored in saved shortcuts; never change them.
nonisolated enum TransactionKindAppEnum: String, AppEnum {
    case expense = "expense"
    case income = "income"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "kind")
    static let caseDisplayRepresentations: [TransactionKindAppEnum: DisplayRepresentation] = [
        .expense: "expense",
        .income: "income",
    ]

    var transactionKind: TransactionKind {
        switch self {
        case .expense: .expense
        case .income: .income
        }
    }

    init(_ kind: CategoryKind) {
        switch kind {
        case .expense: self = .expense
        case .income: self = .income
        }
    }
}

// MARK: - Category

/// A category, identified by kind and name rather than its database ID so saved
/// shortcuts keep working after the data is exported and imported again.
struct CategoryEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "category")
    static let defaultQuery = CategoryEntityQuery()

    let id: String
    @Property(title: "name") var name: String
    @Property(title: "kind") var kind: TransactionKindAppEnum
    let systemImage: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: DisplayRepresentation.Image(systemName: systemImage))
    }

    init(id: String, name: String, kind: TransactionKindAppEnum, systemImage: String) {
        self.id = id
        self.systemImage = systemImage
        self.name = name
        self.kind = kind
    }

    @MainActor
    init(_ category: Category) {
        let kind = TransactionKindAppEnum(category.categoryKind)
        self.init(id: Self.id(name: category.name, kind: kind), name: category.name, kind: kind, systemImage: category.systemImage)
    }

    static func id(name: String, kind: TransactionKindAppEnum) -> String {
        "\(kind.rawValue):\(name)"
    }

    /// The stored category this entity refers to, if it still exists.
    @MainActor
    func model(in context: ModelContext) throws -> Category? {
        try context.fetch(FetchDescriptor<Category>()).first { Self.id(name: $0.name, kind: .init($0.categoryKind)) == id }
    }
}

nonisolated struct CategoryEntityQuery: EntityStringQuery {
    /// Lets the log action offer only categories of the chosen kind.
    @IntentParameterDependency<LogTransactionIntent>(\.$kind)
    var logTransaction

    @MainActor
    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        let wanted = Set(identifiers)
        return try allCategories().filter { wanted.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        try await suggestedEntities().filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        let categories = try allCategories()
        guard let kind = logTransaction?.kind else { return categories }
        return categories.filter { $0.kind == kind }
    }

    @MainActor
    private func allCategories() throws -> [CategoryEntity] {
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
        return try LedgerStore.container.mainContext.fetch(descriptor).map { CategoryEntity($0) }
    }
}

// MARK: - Account

/// An account, identified by its name for the same reason as `CategoryEntity`.
struct AccountEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "source")
    static let defaultQuery = AccountEntityQuery()

    let id: String
    @Property(title: "name") var name: String
    let systemImage: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: DisplayRepresentation.Image(systemName: systemImage))
    }

    init(id: String, name: String, systemImage: String) {
        self.id = id
        self.systemImage = systemImage
        self.name = name
    }

    @MainActor
    init(_ source: Source) {
        self.init(id: source.name, name: source.name, systemImage: source.systemImage)
    }

    @MainActor
    func model(in context: ModelContext) throws -> Source? {
        try context.fetch(FetchDescriptor<Source>()).first { $0.name == id }
    }
}

nonisolated struct AccountEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        let wanted = Set(identifiers)
        return try await suggestedEntities().filter { wanted.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [AccountEntity] {
        try await suggestedEntities().filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AccountEntity] {
        let descriptor = FetchDescriptor<Source>(sortBy: [SortDescriptor(\.createdAt)])
        return try LedgerStore.container.mainContext.fetch(descriptor).map { AccountEntity($0) }
    }
}

// MARK: - Shared helpers

/// Errors Siri and Shortcuts read out to the user.
nonisolated enum LedgerIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidAmount
    case noAccount
    case appLocked
    case noBudget

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount: "The amount must be greater than zero."
        case .noAccount: "Add an account in Ledger first."
        case .appLocked: "Ledger is locked. Open the app to see your data."
        case .noBudget: "There's no active budget to check."
        }
    }
}

enum LedgerIntentSupport {
    /// Actions that read data out loud respect the in-app Face ID lock.
    static func ensureAppUnlocked() throws {
        if UserDefaults.standard.bool(forKey: AppLock.storageKey) { throw LedgerIntentError.appLocked }
    }

    /// Updates everything that depends on transactions after an action changed them.
    static func transactionsDidChange(in context: ModelContext) {
        BudgetNotifier.check(in: context)
        WidgetSnapshotWriter.update(in: context)
    }

    static func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currency))
    }
}
