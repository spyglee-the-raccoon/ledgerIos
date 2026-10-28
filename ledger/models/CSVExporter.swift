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

        return (files, transactions.count)
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
