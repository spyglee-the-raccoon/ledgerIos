//
//  PlannedTransaction.swift
//  Ledger
//
//  Created by Maksym Bahrov on 20.10.2026..
//
import Foundation
import SwiftData

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly
    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .daily: "daily"
        case .weekly: "weekly"
        case .monthly: "monthly"
        case .yearly: "yearly"
        }
    }

    func scheduleDescription(interval: Int) -> LocalizedStringResource {
        guard interval > 1 else { return displayName }
        switch self {
        case .daily: return "every_n_days \(interval)"
        case .weekly: return "every_n_weeks \(interval)"
        case .monthly: return "every_n_months \(interval)"
        case .yearly: return "every_n_years \(interval)"
        }
    }
}

struct PlannedTransactionDraft {
    var amount: Decimal = 0
    var kind: TransactionKind = .expense
    var source: Source?
    var destination: Source?
    var note: String = ""
    var category: Category?
    var frequency: RecurrenceFrequency = .monthly
    var interval: Int = 1
    var startDate: Date = Date.now
    var endDate: Date?
    var isPaused: Bool = false

    init() {}

    init(_ planned: PlannedTransaction) {
        amount = planned.amount
        kind = planned.kind
        source = planned.source
        destination = planned.destination
        note = planned.note
        category = planned.category
        frequency = planned.frequency
        interval = planned.interval
        startDate = planned.startDate
        endDate = planned.endDate
        isPaused = planned.isPaused
    }

    func apply(to planned: PlannedTransaction) {
        planned.amount = amount
        planned.kind = kind
        planned.source = source
        planned.destination = destination
        planned.note = note
        planned.category = category
        planned.frequency = frequency
        planned.interval = interval
        planned.startDate = startDate
        planned.endDate = endDate
        planned.isPaused = isPaused
    }
}

@Model
final class PlannedTransaction {
    var amount: Decimal = 0
    var kind: TransactionKind = TransactionKind.expense
    var source: Source?
    var destination: Source?
    var note: String = ""
    var category: Category?

    var frequency: RecurrenceFrequency = RecurrenceFrequency.monthly
    var interval: Int = 1
    var startDate: Date = Date.now
    var endDate: Date?
    var occurrencesGenerated: Int = 0
    var isPaused: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Transaction.plannedTransaction)
    var transactions: [Transaction]? = []

    func occurrenceDate(_ n: Int, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: frequency.component, value: n * interval, to: startDate)
    }

    var nextDueDate: Date? { occurrenceDate(occurrencesGenerated) }
    
    init(amount: Decimal, kind: TransactionKind, source: Source? = nil, destination: Source? = nil, note: String, category: Category? = nil, frequency: RecurrenceFrequency, interval: Int, startDate: Date, endDate: Date? = nil, occurrencesGenerated: Int, isPaused: Bool, transactions: [Transaction]? = nil) {
        self.amount = amount
        self.kind = kind
        self.source = source
        self.destination = destination
        self.note = note
        self.category = category
        self.frequency = frequency
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.occurrencesGenerated = occurrencesGenerated
        self.isPaused = isPaused
        self.transactions = transactions
    }
}
