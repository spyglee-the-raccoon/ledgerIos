//
//  ReceiptParser.swift
//  ledger
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

struct ParsedReceiptItem: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var quantity: Decimal
    var unitPrice: Decimal
    var totalPrice: Decimal
}

enum ReceiptParser {
    private static let maxItems = 80

    /// Recognizes the purchased product lines. Runs as a separate request so a long
    /// item list can't push the total, date and category out of the model's context.
    /// Returns an empty list when the on-device model isn't available.
    static func parseItems(_ text: String) async -> [ParsedReceiptItem] {
        guard SystemLanguageModel.default.isAvailable else { return [] }
        let session = LanguageModelSession(instructions: """
            You list the purchased products from OCR text of shopping receipts. \
            The text may contain OCR errors. Only use values that appear in the text. \
            Numbers often use a decimal comma (1,29). A product line usually shows the name, \
            then quantity × unit price and the line total; weighed goods show the weight in kg as the quantity. \
            Skip totals, subtotals, VAT/tax (PDV, ПДВ, PTU) tables, payment, change, card, \
            loyalty points and store information lines. \
            If a discount line directly follows a product, subtract it from that product's line total.
            """)

        do {
            let content = try await session.respond(
                to: "Receipt text:\n\(text)",
                schema: try makeItemsSchema()
            ).content
            guard case .structure(let properties, _) = content.kind,
                  case .array(let elements)? = properties["items"]?.kind else { return [] }
            return elements.compactMap(item(from:))
        } catch {
            return []
        }
    }

    private static func makeItemsSchema() throws -> GenerationSchema {
        let item = DynamicGenerationSchema(name: "Item", properties: [
            DynamicGenerationSchema.Property(
                name: "name",
                description: "Product name exactly as printed, without quantity or price, e.g. MLIJEKO 2,8% 1L",
                schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "quantity",
                description: "Number of pieces or weight in kg, digits with a dot as decimal separator, e.g. 2 or 0.456; 1 if not printed",
                schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "unitPrice",
                description: "Price of one piece or one kg, digits with a dot as decimal separator, e.g. 1.29; empty if not printed",
                schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "totalPrice",
                description: "Line total paid for this product, digits with a dot as decimal separator, e.g. 2.58",
                schema: DynamicGenerationSchema(type: String.self)
            )
        ])
        let root = DynamicGenerationSchema(name: "ReceiptItems", properties: [
            DynamicGenerationSchema.Property(
                name: "items",
                description: "Every purchased product line in receipt order",
                schema: DynamicGenerationSchema(arrayOf: item, maximumElements: maxItems)
            )
        ])
        return try GenerationSchema(root: root, dependencies: [])
    }

    /// Validates one generated line and fills in a missing unit price or total.
    private static func item(from content: GeneratedContent) -> ParsedReceiptItem? {
        let name = ((try? content.value(String.self, forProperty: "name")) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.contains(where: \.isLetter) else { return nil }

        let quantity = (try? content.value(String.self, forProperty: "quantity")).flatMap(decimal(from:)) ?? 1
        let unitPrice = (try? content.value(String.self, forProperty: "unitPrice")).flatMap(decimal(from:))
        let totalPrice = (try? content.value(String.self, forProperty: "totalPrice")).flatMap(decimal(from:))

        guard let total = totalPrice ?? unitPrice.map({ $0 * quantity }) else { return nil }
        return ParsedReceiptItem(
            name: name,
            quantity: quantity,
            unitPrice: unitPrice ?? total / quantity,
            totalPrice: total
        )
    }

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
        let time = (try? generated.value(String.self, forProperty: "time")) ?? ""
        let category = try? generated.value(String.self, forProperty: "category")

        // The model can latch onto a smaller "Total" (e.g. from a VAT table),
        // so always keep the biggest total found by either the model or the rules.
        let lines = text.lowercased().components(separatedBy: .newlines)
        return ParsedReceipt(
            total: [decimal(from: total), fallback.total].compactMap { $0 }.max(),
            date: combine(
                day: isoDay(from: date) ?? findDay(in: text),
                time: firstTime(in: time) ?? findTime(in: lines)
            ),
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
                description: "Final amount paid including tax; if several totals are printed, the largest one. Digits only with a dot as decimal separator, e.g. 12.49",
                schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "date",
                description: "Purchase date as YYYY-MM-DD, or an empty string if not printed",
                schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "time",
                description: "Purchase time as HH:MM in 24-hour format, e.g. 14:35, often labeled VRIJEME on Croatian receipts; an empty string if not printed",
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

    /// A session created ahead of time by `prewarm()`, consumed by the next parse.
    private static var preparedSession: LanguageModelSession?

    /// Loads the model and caches the instructions while the user is still scanning,
    /// so the request after the scan only has to process the receipt text.
    static func prewarm() {
        guard SystemLanguageModel.default.isAvailable, preparedSession == nil else { return }
        let session = makeSession()
        session.prewarm(promptPrefix: Prompt("Receipt text:\n"))
        preparedSession = session
    }

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: """
            You extract data from OCR text of shopping receipts for a personal budgeting app. \
            The text may contain OCR errors. Only use values that appear in the text. \
            Receipts are often Croatian: the final amount is labeled UKUPNO, SVEUKUPNO, ZA PLATITI, ZA UPLATU or TOTAL, \
            numbers use a decimal comma (12,49), dates are written as DD.MM.YYYY \
            and the purchase time is labeled VRIJEME and written as HH:MM or HH:MM:SS. \
            Ukrainian receipts label the final amount СУМА, ВСЬОГО, РАЗОМ or ДО СПЛАТИ and VAT as ПДВ. \
            Polish receipts label the final amount SUMA, SUMA PLN, RAZEM or DO ZAPŁATY and VAT as PTU or VAT. \
            Ignore VAT (PDV, ПДВ, PTU) summary lines when choosing the total. \
            A VAT table with its own TOTAL, UKUPNO, СУМА or SUMA row often follows the final amount. \
            If several amounts are labeled as a total, return the largest one. \
            Pick the category from the purchased items and the type of store.
            """)
    }

    private static func parseWithModel(_ text: String, categoryNames: [String]) async throws -> GeneratedContent {
        // Each receipt gets a fresh session so earlier receipts don't pile up in the context.
        let session = preparedSession ?? makeSession()
        preparedSession = nil
        return try await session.respond(
            to: "Receipt text:\n\(text)",
            schema: try makeSchema(categoryNames: categoryNames)
        ).content
    }

    private static let totalKeywords = [
        // Croatian / English
        "za platiti", "za uplatu", "sveukupno", "ukupno", "total",
        // Ukrainian
        "до сплати", "всього", "разом", "сума",
        // Polish (with and without diacritics, as OCR often drops them)
        "do zapłaty", "do zaplaty", "razem", "suma"
    ]

    private static let excludedKeywords = [
        // Croatian
        "pdv", "porez", "osnovica",
        // Ukrainian
        "пдв", "податок",
        // Polish
        "ptu", "vat", "podatek", "opodatk"
    ]

    private static let timeKeywords = [
        // Croatian / Serbian / English
        "vrijeme", "vreme", "time",
        // Ukrainian
        "час",
        // Polish (matches "godz." and "godzina")
        "godz"
    ]

    static func parseWithRules(_ text: String) -> ParsedReceipt {
        let lines = text.lowercased().components(separatedBy: .newlines)
        let merchant = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.contains(where: \.isLetter) }
        return ParsedReceipt(
            total: findTotal(in: lines),
            date: combine(day: findDay(in: text), time: findTime(in: lines)),
            merchant: merchant
        )
    }

    /// Returns the largest amount on any total line, so smaller totals
    /// (e.g. from a VAT table printed after the final amount) are never picked.
    private static func findTotal(in lines: [String]) -> Decimal? {
        var candidates: [Decimal] = []
        for (index, line) in lines.enumerated()
        where totalKeywords.contains(where: { line.containsWord($0) })
            && !excludedKeywords.contains(where: { line.containsWord($0, matchingPrefix: true) }) {
            if let amount = lastAmount(in: line) {
                candidates.append(amount)
            } else if index + 1 < lines.count, let amount = lastAmount(in: lines[index + 1]) {
                candidates.append(amount)
            }
        }
        return candidates.max()
    }

    private static func lastAmount(in line: String) -> Decimal? {
        guard let match = line.matches(of: /\d{1,3}(?:[ .,]?\d{3})*[.,]\d{2}(?!\d)/).last else {
            return nil
        }
        return decimal(from: String(match.output))
    }

    private static func findDay(in text: String) -> DateComponents? {
        guard let match = text.firstMatch(of: /(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4})/),
              let day = Int(match.1), let month = Int(match.2), let year = Int(match.3) else {
            return nil
        }
        return DateComponents(year: year, month: month, day: day)
    }

    /// Prefers a time on (or right after) a line labeled e.g. VRIJEME,
    /// otherwise takes the first time printed anywhere on the receipt.
    static func findTime(in lines: [String]) -> DateComponents? {
        // Opening hours ("radno vrijeme 08:00-21:00") are not the purchase time.
        let lines = lines.filter { !$0.containsWord("radno") }
        for (index, line) in lines.enumerated()
        where timeKeywords.contains(where: { line.containsWord($0, matchingPrefix: true) }) {
            if let time = firstTime(in: line) {
                return time
            } else if index + 1 < lines.count, let time = firstTime(in: lines[index + 1]) {
                return time
            }
        }
        return lines.lazy.compactMap(firstTime(in:)).first
    }

    private static func firstTime(in line: String) -> DateComponents? {
        for match in line.matches(of: /(?:^|\D)(\d{1,2})\s?:\s?(\d{2})(?::\d{2})?(?!\d)/) {
            if let hour = Int(match.1), let minute = Int(match.2), hour < 24, minute < 60 {
                return DateComponents(hour: hour, minute: minute)
            }
        }
        return nil
    }

    /// Joins the receipt day with its time, using the current time when none was found.
    private static func combine(day: DateComponents?, time: DateComponents?) -> Date? {
        guard var components = day else { return nil }
        let time = time ?? Calendar.current.dateComponents([.hour, .minute], from: .now)
        components.hour = time.hour
        components.minute = time.minute
        return Calendar.current.date(from: components)
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

    private static func isoDay(from string: String) -> DateComponents? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(year: parts[0], month: parts[1], day: parts[2])
    }
}

extension String {
    func containsWord(_ word: String, matchingPrefix: Bool = false) -> Bool {
        var searchStart = startIndex
        while let range = range(of: word, range: searchStart..<endIndex) {
            let startsWord = range.lowerBound == startIndex || !self[index(before: range.lowerBound)].isLetter
            let endsWord = matchingPrefix || range.upperBound == endIndex || !self[range.upperBound].isLetter
            if startsWord && endsWord {
                return true
            }
            searchStart = index(after: range.lowerBound)
        }
        return false
    }
}
