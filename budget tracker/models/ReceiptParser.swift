//
//  ReceiptParser.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 29.09.2026..
//

import Foundation
import FoundationModels

struct ParsedReceipt {
    var total: Decimal?
    var date: Date?
    var merchant: String?
    var categoryName: String? = nil
}

enum ReceiptParser {
    static func parse(_ text: String, categoryNames: [String]) async -> ParsedReceipt {
        let fallback = parseWithRules(text)
        guard SystemLanguageModel.default.isAvailable,
              let generated = try? await parseWithModel(text, categoryNames: categoryNames) else {
            return fallback
        }

        let merchant = (try? generated.value(String.self, forProperty: "merchant"))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let total = (try? generated.value(String.self, forProperty: "total")) ?? ""
        let date = (try? generated.value(String.self, forProperty: "date")) ?? ""
        let category = try? generated.value(String.self, forProperty: "category")

        return ParsedReceipt(
            total: decimal(from: total) ?? fallback.total,
            date: isoDate(from: date) ?? fallback.date,
            merchant: merchant.isEmpty ? fallback.merchant : merchant,
            categoryName: category.flatMap { categoryNames.contains($0) ? $0 : nil }
        )
    }

    private static func makeSchema(categoryNames: [String]) throws -> GenerationSchema {
        var properties: [DynamicGenerationSchema.Property] = [
            DynamicGenerationSchema.Property(
                name: "merchant",
                description: "Store brand name printed at the top of the receipt, without the legal form (d.o.o., d.d.) or address, e.g. Konzum",
                schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "total",
                description: "Final amount paid including tax, digits only with a dot as decimal separator, e.g. 12.49",
                schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "date",
                description: "Purchase date as YYYY-MM-DD, or an empty string if not printed",
                schema: DynamicGenerationSchema(type: String.self)
            )
        ]

        let uniqueNames = Array(Set(categoryNames)).sorted()
        if !uniqueNames.isEmpty {
            properties.append(DynamicGenerationSchema.Property(
                name: "category",
                description: "The spending category that best matches the purchased items and the store",
                schema: DynamicGenerationSchema(name: "Category", anyOf: uniqueNames)
            ))
        }

        let receipt = DynamicGenerationSchema(name: "Receipt", properties: properties)
        return try GenerationSchema(root: receipt, dependencies: [])
    }

    private static func parseWithModel(_ text: String, categoryNames: [String]) async throws -> GeneratedContent {
        let session = LanguageModelSession(instructions: """
            You extract data from OCR text of shopping receipts for a personal budgeting app. \
            The text may contain OCR errors. Only use values that appear in the text. \
            Receipts are often Croatian: the final amount is labeled UKUPNO, ZA PLATITI or ZA UPLATU, \
            numbers use a decimal comma (12,49) and dates are written as DD.MM.YYYY. \
            Ignore VAT (PDV) summary lines when choosing the total. \
            Pick the category from the purchased items and the type of store. \
            Sometimes VAT (PDV) is a separate table right after the total amount, make sure we don't pick this Total 
            """)
        return try await session.respond(
            to: "Receipt text:\n\(text)",
            schema: try makeSchema(categoryNames: categoryNames)
        ).content
    }

    private static let totalKeywords = ["za platiti", "za uplatu", "sveukupno", "ukupno", "total"]

    private static let excludedKeywords = ["pdv", "porez", "osnovica"]

    private static func parseWithRules(_ text: String) -> ParsedReceipt {
        let lines = text.lowercased().components(separatedBy: .newlines)
        let merchant = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.contains(where: \.isLetter) }
        return ParsedReceipt(total: findTotal(in: lines), date: findDate(in: text), merchant: merchant)
    }

    private static func findTotal(in lines: [String]) -> Decimal? {
        for keyword in totalKeywords {
            for (index, line) in lines.enumerated()
            where line.contains(keyword) && !excludedKeywords.contains(where: line.contains) {
                if let amount = lastAmount(in: line) {
                    return amount
                }
                if index + 1 < lines.count, let amount = lastAmount(in: lines[index + 1]) {
                    return amount
                }
            }
        }
        return nil
    }

    private static func lastAmount(in line: String) -> Decimal? {
        guard let match = line.matches(of: /\d{1,3}(?:[ .,]?\d{3})*[.,]\d{2}(?!\d)/).last else {
            return nil
        }
        return decimal(from: String(match.output))
    }

    private static func findDate(in text: String) -> Date? {
        guard let match = text.firstMatch(of: /(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4})/),
              let day = Int(match.1), let month = Int(match.2), let year = Int(match.3) else {
            return nil
        }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func decimal(from string: String) -> Decimal? {
        var number = string.filter { $0.isNumber || $0 == "," || $0 == "." }
        if let separator = number.lastIndex(where: { $0 == "," || $0 == "." }) {
            let integer = number[..<separator].filter(\.isNumber)
            let fraction = number[number.index(after: separator)...]
            number = "\(integer).\(fraction)"
        }
        guard let value = Decimal(string: number, locale: Locale(identifier: "en_US_POSIX")), value > 0 else {
            return nil
        }
        return value
    }

    private static func isoDate(from string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
