//
//  TestSupport.swift
//  LedgerTests
//

import Foundation
import SwiftData
@testable import Ledger

/// An in-memory store with the app's full schema. Keep the container alive for
/// as long as its context is used.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([
        Category.self, Source.self, Transaction.self, MerchantCategory.self, TransactionCollection.self,
        PlannedTransaction.self, Budget.self, ReceiptItem.self, ReceiptPhoto.self
    ])
    return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}

/// A local date at noon, so day-based assertions are not affected by time zones.
func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, calendar: Calendar = .current) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

/// An exact decimal; float literals would go through `Double` first.
func decimal(_ string: String) -> Decimal {
    Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
}

func dayComponents(_ date: Date, calendar: Calendar = .current) -> DateComponents {
    calendar.dateComponents([.year, .month, .day], from: date)
}

/// A Gregorian calendar in UTC, for date math that must not depend on the device settings.
var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

/// Writes CSV files into a fresh temporary directory and returns their URLs.
func writeCSVFiles(_ files: [(name: String, text: String)]) throws -> [URL] {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return try files.map { file in
        let url = directory.appendingPathComponent(file.name)
        try Data(file.text.utf8).write(to: url)
        return url
    }
}
