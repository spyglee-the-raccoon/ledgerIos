//
//  CSVImporter.swift
//  ledger
//
//  Created by Maksym Bahrov on 30.09.2026..
//

import Foundation
import SwiftData

struct CSVImportResult {
    var importedCount = 0
    var createdSources = 0
    var createdCategories = 0
    var skippedLines: [String: [Int]] = [:]

    var skippedCount: Int { skippedLines.values.reduce(0) { $0 + $1.count } }
}

enum CSVImportError: LocalizedError {
    case unreadable(String)
    case unknownFormat(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let file): String(localized: "import_error_unreadable \(file)")
        case .unknownFormat(let file): String(localized: "import_error_unknown_format \(file)")
        }
    }
}

/// Reads the files written by `CSVExporter`, plus transaction files from other apps
/// in the same layout. Each file's type is recognized from its header, not its name.
@MainActor
struct CSVImporter {
    private let context: ModelContext
    private var sourcesByName: [String: Source] = [:]
    private var categoriesByKey: [String: Category] = [:]
    private var collectionsByName: [String: TransactionCollection] = [:]
    private var budgetKeys: Set<String> = []
    private var plannedKeys: Set<String> = []
    /// Transactions referenced by collection and receipt item files. Ones imported in
    /// this run are preferred, so re-importing an export links to the new copies.
    private var importedTransactions: [String: [Transaction]] = [:]
    private var existingTransactions: [String: [Transaction]] = [:]
    private var result = CSVImportResult()

    init(context: ModelContext) {
        self.context = context
        for source in (try? context.fetch(FetchDescriptor<Source>())) ?? [] {
            sourcesByName[Self.normalized(source.name)] = source
        }
        for category in (try? context.fetch(FetchDescriptor<Category>())) ?? [] {
            categoriesByKey[Self.categoryKey(category.name, category.categoryKind)] = category
        }
        for collection in (try? context.fetch(FetchDescriptor<TransactionCollection>())) ?? [] {
            collectionsByName[Self.normalized(collection.name)] = collection
        }
        for budget in (try? context.fetch(FetchDescriptor<Budget>())) ?? [] {
            budgetKeys.insert(Self.normalized(budget.category?.name ?? ""))
        }
        for planned in (try? context.fetch(FetchDescriptor<PlannedTransaction>())) ?? [] {
            plannedKeys.insert(Self.plannedKey(planned))
        }
    }

    static func importFiles(_ urls: [URL], into context: ModelContext) throws -> CSVImportResult {
        var importer = CSVImporter(context: context)
        let files = try urls.map { url in (url.lastPathComponent, try readText(at: url)) }
        let tables = try files
            .map { name, text in try parse(text, fileName: name) }
            .sorted { $0.kind.order < $1.kind.order }

        // Index existing transactions before inserting any, so new ones aren't counted twice.
        if tables.contains(where: \.kind.referencesTransactions) {
            for transaction in (try? context.fetch(FetchDescriptor<Transaction>())) ?? [] {
                importer.existingTransactions[transactionKey(transaction), default: []].append(transaction)
            }
        }

        for table in tables {
            for line in table.lines {
                if !importer.insert(line, of: table.kind) {
                    importer.result.skippedLines[table.fileName, default: []].append(line.number)
                }
            }
        }
        try context.save()
        return importer.result
    }

    // MARK: - Parsing

    private enum FileKind {
        case accounts, categories, transactions(TransactionKind), plannedTransactions
        case budgets, collections, collectionTransactions, receiptItems

        /// Accounts and categories go first so transactions link to them instead of
        /// creating defaults; files that reference transactions go last.
        var order: Int {
            switch self {
            case .accounts: 0
            case .categories: 1
            case .transactions: 2
            case .plannedTransactions: 3
            case .budgets: 4
            case .collections: 5
            case .collectionTransactions: 6
            case .receiptItems: 7
            }
        }

        var referencesTransactions: Bool {
            switch self {
            case .collectionTransactions, .receiptItems: true
            default: false
            }
        }
    }

    private struct Table {
        var fileName: String
        var kind: FileKind
        var lines: [Line]
    }

    private struct Line {
        var number: Int
        var columns: [String]
        var fields: [String]

        /// The trimmed value in `column`, or `nil` when the column is missing or empty.
        subscript(_ column: String) -> String? {
            guard let index = columns.firstIndex(of: column), index < fields.count, !fields[index].isEmpty else { return nil }
            return fields[index]
        }
    }

    private static func parse(_ text: String, fileName: String) throws -> Table {
        let lines = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
            .enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let header = lines.first else { throw CSVImportError.unknownFormat(fileName) }
        let columns = fields(header.element).map { $0.lowercased() }
        guard let kind = fileKind(for: Set(columns)) else { throw CSVImportError.unknownFormat(fileName) }

        let rows = lines.dropFirst().map { offset, line in
            Line(number: offset + 1, columns: columns, fields: fields(line))
        }
        return Table(fileName: fileName, kind: kind, lines: rows)
    }

    private static func fileKind(for columns: Set<String>) -> FileKind? {
        if columns.isSuperset(of: ["date", "amount"]) {
            if columns.isSuperset(of: ["source", "target"]) { return .transactions(.transfer) }
            if columns.isSuperset(of: ["destination", "category"]) { return .transactions(.income) }
            if columns.isSuperset(of: ["source", "category"]) { return .transactions(.expense) }
            return nil
        }
        if columns.isSuperset(of: ["collection", "transaction_date"]) { return .collectionTransactions }
        if columns.isSuperset(of: ["transaction_date", "name"]) { return .receiptItems }
        if columns.isSuperset(of: ["kind", "amount", "frequency", "start_date"]) { return .plannedTransactions }
        if columns.isSuperset(of: ["limit"]) { return .budgets }
        if columns.isSuperset(of: ["name", "initial_value"]) { return .accounts }
        if columns.isSuperset(of: ["name", "kind"]) { return .categories }
        if columns.isSuperset(of: ["name", "icon", "color"]) { return .collections }
        return nil
    }

    private static func fields(_ line: String) -> [String] {
        line.components(separatedBy: ";").map {
            $0.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static func parseDate(_ string: String) -> Date? {
        let trimmed = string.hasSuffix(".") ? String(string.dropLast()) : string
        return dateFormatter.date(from: trimmed)
    }

    /// Transaction amounts are always positive; the kind gives the direction.
    private static func parseAmount(_ string: String) -> Decimal? {
        parseSignedAmount(string).map { abs($0) }
    }

    private static func parseSignedAmount(_ string: String) -> Decimal? {
        var cleaned = string.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }
        if cleaned.contains(",") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func parseBool(_ string: String?, default defaultValue: Bool) -> Bool {
        guard let string else { return defaultValue }
        return ["true", "yes", "1"].contains(string.lowercased())
    }

    private static func readText(at url: URL) throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1250)
                ?? String(data: data, encoding: .isoLatin1)
        else { throw CSVImportError.unreadable(url.lastPathComponent) }
        return text
    }

    // MARK: - Inserting

    /// Returns `false` when the line is invalid and should be reported as skipped.
    /// Lines describing something that already exists are ignored and return `true`.
    private mutating func insert(_ line: Line, of kind: FileKind) -> Bool {
        switch kind {
        case .accounts: insertAccount(line)
        case .categories: insertCategory(line)
        case .transactions(let kind): insertTransaction(line, kind: kind)
        case .plannedTransactions: insertPlannedTransaction(line)
        case .budgets: insertBudget(line)
        case .collections: insertCollection(line)
        case .collectionTransactions: insertCollectionTransaction(line)
        case .receiptItems: insertReceiptItem(line)
        }
    }

    private mutating func insertAccount(_ line: Line) -> Bool {
        guard let name = line["name"] else { return false }
        let key = Self.normalized(name)
        guard sourcesByName[key] == nil else { return true }

        let source = Source(
            name: name,
            systemImage: line["icon"] ?? SourceDraft().systemImage,
            initValue: line["initial_value"].flatMap(Self.parseSignedAmount) ?? 0,
            color: line["color"].flatMap(CategoryColor.init(rawValue:)) ?? SourceDraft().color
        )
        context.insert(source)
        sourcesByName[key] = source
        result.createdSources += 1
        return true
    }

    private mutating func insertCategory(_ line: Line) -> Bool {
        guard let name = line["name"], let kind = line["kind"].flatMap(CategoryKind.init(rawValue:)) else { return false }
        let key = Self.categoryKey(name, kind)
        guard categoriesByKey[key] == nil else { return true }

        let category = Category(
            name: name,
            systemImage: line["icon"] ?? CategoryDraft().systemImage,
            color: line["color"].flatMap(CategoryColor.init(rawValue:)) ?? CategoryDraft().color,
            categoryKind: kind
        )
        context.insert(category)
        categoriesByKey[key] = category
        result.createdCategories += 1
        return true
    }

    private mutating func insertTransaction(_ line: Line, kind: TransactionKind) -> Bool {
        let sourceName = kind == .income ? nil : line["source"]
        let destinationName: String? = switch kind {
        case .income: line["destination"]
        case .transfer: line["target"]
        case .expense: nil
        }
        guard let date = line["date"].flatMap(Self.parseDate),
              let amount = line["amount"].flatMap(Self.parseAmount),
              sourceName != nil || destinationName != nil
        else { return false }

        let transaction = Transaction(
            amount: amount,
            kind: kind,
            source: sourceName.map { source(named: $0) },
            destination: destinationName.map { source(named: $0) },
            note: line["details"] ?? "",
            date: date,
            category: line["category"].flatMap { category(named: $0, for: kind) }
        )
        context.insert(transaction)
        importedTransactions[Self.transactionKey(transaction), default: []].append(transaction)
        result.importedCount += 1
        return true
    }

    private mutating func insertPlannedTransaction(_ line: Line) -> Bool {
        guard let kind = line["kind"].flatMap(TransactionKind.init(rawValue:)),
              let amount = line["amount"].flatMap(Self.parseAmount),
              let frequency = line["frequency"].flatMap(RecurrenceFrequency.init(rawValue:)),
              let startDate = line["start_date"].flatMap(Self.parseDate)
        else { return false }
        let interval = max(line["interval"].flatMap { Int($0) } ?? 1, 1)
        let sourceName = line["source"]
        let destinationName = line["destination"]
        let note = line["details"] ?? ""
        guard sourceName != nil || destinationName != nil else { return false }

        // Check before building the model: linking it to an existing account or
        // category inserts it into the context even if it's never inserted explicitly.
        let key = Self.plannedKey(
            kind: kind, amount: amount, sourceName: sourceName, destinationName: destinationName,
            frequency: frequency, interval: interval, startDate: startDate, note: note
        )
        guard !plannedKeys.contains(key) else { return true }

        let planned = PlannedTransaction(
            amount: amount,
            kind: kind,
            source: sourceName.map { source(named: $0) },
            destination: destinationName.map { source(named: $0) },
            note: note,
            category: line["category"].flatMap { category(named: $0, for: kind) },
            frequency: frequency,
            interval: interval,
            startDate: startDate,
            endDate: line["end_date"].flatMap(Self.parseDate),
            occurrencesGenerated: 0,
            isPaused: Self.parseBool(line["paused"], default: false)
        )

        // Past occurrences are already in the exported transactions, so mark them as
        // generated; otherwise the recurrence engine would create them a second time.
        while let due = planned.nextDueDate, due <= .now {
            if let end = planned.endDate, due > end { break }
            planned.occurrencesGenerated += 1
        }
        context.insert(planned)
        plannedKeys.insert(key)
        return true
    }

    private mutating func insertBudget(_ line: Line) -> Bool {
        guard let limit = line["limit"].flatMap(Self.parseAmount) else { return false }
        let categoryName = line["category"]
        let key = Self.normalized(categoryName ?? "")
        guard !budgetKeys.contains(key) else { return true }

        let budget = Budget(
            limit: limit,
            isActive: Self.parseBool(line["active"], default: true),
            category: categoryName.flatMap { category(named: $0, for: .expense) }
        )
        context.insert(budget)
        budgetKeys.insert(key)
        return true
    }

    private mutating func insertCollection(_ line: Line) -> Bool {
        guard let name = line["name"] else { return false }
        guard collectionsByName[Self.normalized(name)] == nil else { return true }
        _ = collection(
            named: name,
            systemImage: line["icon"],
            color: line["color"].flatMap(CategoryColor.init(rawValue:))
        )
        return true
    }

    private mutating func insertCollectionTransaction(_ line: Line) -> Bool {
        guard let name = line["collection"] else { return false }
        let matches = transactions(referencedBy: line)
        guard !matches.isEmpty else { return false }

        let target = collection(named: name)
        // Identical transactions are added one per line; when all are already in
        // the collection the line is a duplicate and is ignored.
        if let transaction = matches.first(where: { candidate in !target.transactions.contains { $0 === candidate } }) {
            target.transactions.append(transaction)
        }
        return true
    }

    private mutating func insertReceiptItem(_ line: Line) -> Bool {
        guard let name = line["name"], let transaction = transactions(referencedBy: line).first else { return false }
        let position = line["position"].flatMap { Int($0) } ?? 0
        let existing = transaction.receiptItems ?? []
        guard !existing.contains(where: { $0.position == position && $0.name == name }) else { return true }

        let item = ReceiptItem(
            name: name,
            quantity: line["quantity"].flatMap(Self.parseAmount) ?? 1,
            unitPrice: line["unit_price"].flatMap(Self.parseAmount) ?? 0,
            totalPrice: line["total_price"].flatMap(Self.parseAmount) ?? 0,
            position: position
        )
        context.insert(item)
        item.transaction = transaction
        return true
    }

    private mutating func source(named name: String) -> Source {
        let key = Self.normalized(name)
        if let existing = sourcesByName[key] { return existing }
        let source = Source(name: name, systemImage: SourceDraft().systemImage)
        context.insert(source)
        sourcesByName[key] = source
        result.createdSources += 1
        return source
    }

    private mutating func category(named name: String, for kind: TransactionKind) -> Category? {
        let categoryKind: CategoryKind
        switch kind {
        case .income: categoryKind = .income
        case .expense: categoryKind = .expense
        case .transfer: return nil
        }
        let key = Self.categoryKey(name, categoryKind)
        if let existing = categoriesByKey[key] { return existing }
        let category = Category(name: name, systemImage: CategoryDraft().systemImage, categoryKind: categoryKind)
        context.insert(category)
        categoriesByKey[key] = category
        result.createdCategories += 1
        return category
    }

    private mutating func collection(named name: String, systemImage: String? = nil, color: CategoryColor? = nil) -> TransactionCollection {
        let key = Self.normalized(name)
        if let existing = collectionsByName[key] { return existing }
        let collection = TransactionCollection(
            name: name,
            systemImage: systemImage ?? CollectionDraft().systemImage,
            color: color ?? CollectionDraft().color,
            transactions: []
        )
        context.insert(collection)
        collectionsByName[key] = collection
        return collection
    }

    // MARK: - Keys

    /// Transactions matching the `transaction_*` columns written by `CSVExporter`.
    private func transactions(referencedBy line: Line) -> [Transaction] {
        guard let date = line["transaction_date"].flatMap(Self.parseDate),
              let kind = line["transaction_kind"].flatMap(TransactionKind.init(rawValue:)),
              let amount = line["transaction_amount"].flatMap(Self.parseAmount)
        else { return [] }
        let key = Self.transactionKey(
            date: date, kind: kind, amount: amount,
            sourceName: line["transaction_source"],
            destinationName: line["transaction_destination"],
            note: line["transaction_details"] ?? ""
        )
        return (importedTransactions[key] ?? []) + (existingTransactions[key] ?? [])
    }

    private static func transactionKey(_ transaction: Transaction) -> String {
        transactionKey(
            date: transaction.date, kind: transaction.kind, amount: transaction.amount,
            sourceName: transaction.source?.name,
            destinationName: transaction.destination?.name,
            note: transaction.note
        )
    }

    /// Exported dates have no time and exported text is escaped, so both sides of
    /// the comparison are reduced to what survives a round trip through the CSV.
    private static func transactionKey(date: Date, kind: TransactionKind, amount: Decimal,
                                       sourceName: String?, destinationName: String?, note: String) -> String {
        [
            dateFormatter.string(from: date),
            kind.rawValue,
            NSDecimalNumber(decimal: amount).stringValue,
            normalized(sourceName ?? ""),
            normalized(destinationName ?? ""),
            roundTripped(note)
        ].joined(separator: "\u{1F}")
    }

    private static func plannedKey(_ planned: PlannedTransaction) -> String {
        plannedKey(
            kind: planned.kind, amount: planned.amount,
            sourceName: planned.source?.name, destinationName: planned.destination?.name,
            frequency: planned.frequency, interval: planned.interval,
            startDate: planned.startDate, note: planned.note
        )
    }

    private static func plannedKey(kind: TransactionKind, amount: Decimal, sourceName: String?, destinationName: String?,
                                   frequency: RecurrenceFrequency, interval: Int, startDate: Date, note: String) -> String {
        [
            kind.rawValue,
            NSDecimalNumber(decimal: amount).stringValue,
            normalized(sourceName ?? ""),
            normalized(destinationName ?? ""),
            frequency.rawValue,
            String(interval),
            dateFormatter.string(from: startDate),
            roundTripped(note)
        ].joined(separator: "\u{1F}")
    }

    /// Mirrors `CSVExporter`'s escaping followed by `fields(_:)` trimming.
    private static func roundTripped(_ text: String) -> String {
        text
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "\"", with: "'")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func categoryKey(_ name: String, _ kind: CategoryKind) -> String {
        "\(kind.rawValue):\(normalized(name))"
    }
}
