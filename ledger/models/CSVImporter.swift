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

@MainActor
struct CSVImporter {
    private let context: ModelContext
    private var sourcesByName: [String: Source] = [:]
    private var categoriesByKey: [String: Category] = [:]
    private var result = CSVImportResult()

    init(context: ModelContext) {
        self.context = context
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        for source in sources {
            sourcesByName[Self.normalized(source.name)] = source
        }
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        for category in categories {
            categoriesByKey[Self.categoryKey(category.name, category.categoryKind)] = category
        }
    }

    static func importFiles(_ urls: [URL], into context: ModelContext) throws -> CSVImportResult {
        var importer = CSVImporter(context: context)
        let files = try urls.map { url in (url.lastPathComponent, try readText(at: url)) }
        let parsed = try files.map { name, text in (name, try importer.parse(text, fileName: name)) }

        for (fileName, rows) in parsed {
            for row in rows {
                switch row {
                case .success(let row): importer.insert(row)
                case .failure(let line): importer.result.skippedLines[fileName, default: []].append(line.number)
                }
            }
        }
        try context.save()
        return importer.result
    }

    // MARK: - Parsing

    private struct Row {
        var kind: TransactionKind
        var date: Date
        var amount: Decimal
        var sourceName: String?
        var destinationName: String?
        var categoryName: String?
        var note: String
    }

    private struct BadLine: Error {
        var number: Int
    }

    private func parse(_ text: String, fileName: String) throws -> [Result<Row, BadLine>] {
        let lines = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
            .enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let header = lines.first else { throw CSVImportError.unknownFormat(fileName) }
        let columns = Self.fields(header.element).map { $0.lowercased() }
        func index(_ name: String) -> Int? { columns.firstIndex(of: name) }

        guard let dateIndex = index("date"), let amountIndex = index("amount") else {
            throw CSVImportError.unknownFormat(fileName)
        }
        let detailsIndex = index("details")

        let kind: TransactionKind
        let sourceIndex: Int?
        let destinationIndex: Int?
        let categoryIndex: Int?
        if let source = index("source"), let target = index("target") {
            (kind, sourceIndex, destinationIndex, categoryIndex) = (.transfer, source, target, nil)
        } else if let destination = index("destination"), let category = index("category") {
            (kind, sourceIndex, destinationIndex, categoryIndex) = (.income, nil, destination, category)
        } else if let source = index("source"), let category = index("category") {
            (kind, sourceIndex, destinationIndex, categoryIndex) = (.expense, source, nil, category)
        } else {
            throw CSVImportError.unknownFormat(fileName)
        }

        return lines.dropFirst().map { offset, line in
            let fields = Self.fields(line)
            func value(_ index: Int?) -> String? {
                guard let index, index < fields.count, !fields[index].isEmpty else { return nil }
                return fields[index]
            }
            guard let date = value(dateIndex).flatMap(Self.parseDate),
                  let amount = value(amountIndex).flatMap(Self.parseAmount)
            else { return .failure(BadLine(number: offset + 1)) }

            let row = Row(
                kind: kind,
                date: date,
                amount: amount,
                sourceName: value(sourceIndex),
                destinationName: value(destinationIndex),
                categoryName: value(categoryIndex),
                note: value(detailsIndex) ?? ""
            )

            if row.sourceName == nil && row.destinationName == nil {
                return .failure(BadLine(number: offset + 1))
            }
            return .success(row)
        }
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

    private static func parseAmount(_ string: String) -> Decimal? {
        var cleaned = string.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }
        if cleaned.contains(",") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        guard let amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return abs(amount)
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

    private mutating func insert(_ row: Row) {
        let transaction = Transaction(
            amount: row.amount,
            kind: row.kind,
            source: row.sourceName.map { source(named: $0) },
            destination: row.destinationName.map { source(named: $0) },
            note: row.note,
            date: row.date,
            category: row.categoryName.flatMap { category(named: $0, for: row.kind) }
        )
        context.insert(transaction)
        result.importedCount += 1
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

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func categoryKey(_ name: String, _ kind: CategoryKind) -> String {
        "\(kind.rawValue):\(normalized(name))"
    }
}
