//
//  CSVExporter.swift
//  ledger
//
//  Created by Maksym Bahrov on 06.10.2026..
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var fileName: String
    var text: String

    init(fileName: String, text: String) {
        self.fileName = fileName
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        fileName = configuration.file.preferredFilename ?? "export.csv"
        text = configuration.file.regularFileContents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: Data(text.utf8))
        wrapper.preferredFilename = fileName
        return wrapper
    }
}

/// Writes transactions in the same layout `CSVImporter` reads: one semicolon-separated
/// file per transaction kind, so an export can be imported back without changes.
/// Accounts, planned transactions, categories, budgets, collections and receipt items
/// are written to their own files, which `CSVImporter` recognizes by their headers.
@MainActor
enum CSVExporter {
    static func makeFiles(from context: ModelContext) throws -> (files: [CSVFile], count: Int) {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
        let transactions = try context.fetch(descriptor)

        let byKind = Dictionary(grouping: transactions, by: \.kind)
        var files = TransactionKind.allCases.compactMap { kind -> CSVFile? in
            guard let items = byKind[kind], !items.isEmpty else { return nil }
            return CSVFile(fileName: "\(kind.rawValue)s.csv", text: csv(for: kind, items))
        }

        let sources = try context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.createdAt)]))
        if !sources.isEmpty {
            files.append(CSVFile(fileName: "accounts.csv", text: sourcesCSV(sources)))
        }

        let planned = try context.fetch(FetchDescriptor<PlannedTransaction>(sortBy: [SortDescriptor(\.startDate)]))
        if !planned.isEmpty {
            files.append(CSVFile(fileName: "planned_transactions.csv", text: plannedCSV(planned)))
        }

        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)]))
        if !categories.isEmpty {
            files.append(CSVFile(fileName: "categories.csv", text: categoriesCSV(categories)))
        }

        let budgets = try context.fetch(FetchDescriptor<Budget>())
        if !budgets.isEmpty {
            files.append(CSVFile(fileName: "budgets.csv", text: budgetsCSV(budgets)))
        }

        let collections = try context.fetch(FetchDescriptor<TransactionCollection>(sortBy: [SortDescriptor(\.name)]))
        if !collections.isEmpty {
            files.append(CSVFile(fileName: "collections.csv", text: collectionsCSV(collections)))
            files.append(CSVFile(fileName: "collection_transactions.csv", text: collectionTransactionsCSV(collections)))
        }

        let receiptItems = try context.fetch(FetchDescriptor<ReceiptItem>())
        if !receiptItems.isEmpty {
            files.append(CSVFile(fileName: "receipt_items.csv", text: receiptItemsCSV(receiptItems)))
        }

        return (files, transactions.count)
    }

    private static func categoriesCSV(_ categories: [Category]) -> String {
        let header = ["name", "kind", "icon", "color"]
        let rows = categories.map { category in
            [category.name, category.categoryKind.rawValue, category.systemImage, category.color.rawValue]
        }
        return joined([header] + rows)
    }

    /// The general monthly budget has an empty category.
    private static func budgetsCSV(_ budgets: [Budget]) -> String {
        let header = ["category", "limit", "active"]
        let rows = budgets
            .sorted { ($0.category?.name ?? "") < ($1.category?.name ?? "") }
            .map { budget in
                [budget.category?.name ?? "", NSDecimalNumber(decimal: budget.limit).stringValue, budget.isActive ? "true" : "false"]
            }
        return joined([header] + rows)
    }

    private static func collectionsCSV(_ collections: [TransactionCollection]) -> String {
        let header = ["name", "icon", "color"]
        let rows = collections.map { [$0.name, $0.systemImage, $0.color.rawValue] }
        return joined([header] + rows)
    }

    /// One row per transaction in a collection. Exported transactions have no IDs,
    /// so each one is identified by its date, kind, amount, account and details.
    private static func collectionTransactionsCSV(_ collections: [TransactionCollection]) -> String {
        let header = ["collection"] + transactionReferenceHeader
        let rows = collections.flatMap { collection in
            collection.transactions
                .sorted { $0.date < $1.date }
                .map { [collection.name] + transactionReference($0) }
        }
        return joined([header] + rows)
    }

    private static func receiptItemsCSV(_ items: [ReceiptItem]) -> String {
        let header = transactionReferenceHeader + ["position", "name", "quantity", "unit_price", "total_price"]
        let rows = items
            .sorted {
                let lhsDate = $0.transaction?.date ?? .distantPast
                let rhsDate = $1.transaction?.date ?? .distantPast
                return lhsDate == rhsDate ? $0.position < $1.position : lhsDate < rhsDate
            }
            .map { item -> [String] in
                let reference = item.transaction.map(transactionReference) ?? Array(repeating: "", count: transactionReferenceHeader.count)
                return reference + [
                    String(item.position),
                    item.name,
                    NSDecimalNumber(decimal: item.quantity).stringValue,
                    NSDecimalNumber(decimal: item.unitPrice).stringValue,
                    NSDecimalNumber(decimal: item.totalPrice).stringValue
                ]
            }
        return joined([header] + rows)
    }

    private static let transactionReferenceHeader = [
        "transaction_date", "transaction_kind", "transaction_amount",
        "transaction_source", "transaction_destination", "transaction_details"
    ]

    private static func transactionReference(_ transaction: Transaction) -> [String] {
        [
            dateFormatter.string(from: transaction.date),
            transaction.kind.rawValue,
            NSDecimalNumber(decimal: transaction.amount).stringValue,
            transaction.source?.name ?? "",
            transaction.destination?.name ?? "",
            transaction.note
        ]
    }

    private static func sourcesCSV(_ sources: [Source]) -> String {
        let header = ["name", "initial_value", "icon", "color"]
        let rows = sources.map { source in
            [source.name, NSDecimalNumber(decimal: source.initValue).stringValue, source.systemImage, source.color.rawValue]
        }
        return joined([header] + rows)
    }

    private static func plannedCSV(_ planned: [PlannedTransaction]) -> String {
        let header = ["kind", "amount", "source", "destination", "category", "frequency",
                      "interval", "start_date", "end_date", "paused", "details"]
        let rows = planned.map { item -> [String] in
            [
                item.kind.rawValue,
                NSDecimalNumber(decimal: item.amount).stringValue,
                item.source?.name ?? "",
                item.destination?.name ?? "",
                item.category?.name ?? "",
                item.frequency.rawValue,
                String(item.interval),
                dateFormatter.string(from: item.startDate),
                item.endDate.map(dateFormatter.string(from:)) ?? "",
                item.isPaused ? "true" : "false",
                item.note
            ]
        }
        return joined([header] + rows)
    }

    private static func joined(_ lines: [[String]]) -> String {
        lines
            .map { $0.map(escaped).joined(separator: ";") }
            .joined(separator: "\n") + "\n"
    }

    private static func csv(for kind: TransactionKind, _ transactions: [Transaction]) -> String {
        let header: [String]
        switch kind {
        case .expense: header = ["date", "amount", "source", "category", "details"]
        case .income: header = ["date", "amount", "destination", "category", "details"]
        case .transfer: header = ["date", "amount", "source", "target", "details"]
        }

        let rows = transactions.map { transaction -> [String] in
            let date = dateFormatter.string(from: transaction.date)
            let amount = NSDecimalNumber(decimal: transaction.amount).stringValue
            let note = transaction.note
            switch kind {
            case .expense:
                return [date, amount, transaction.source?.name ?? "", transaction.category?.name ?? "", note]
            case .income:
                return [date, amount, transaction.destination?.name ?? "", transaction.category?.name ?? "", note]
            case .transfer:
                return [date, amount, transaction.source?.name ?? "", transaction.destination?.name ?? "", note]
            }
        }

        return joined([header] + rows)
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "\"", with: "'")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}
