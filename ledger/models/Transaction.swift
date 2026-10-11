//
//  Transaction.swift
//  ledger
//
//  Created by Maksym Bahrov on 16.09.2026..
//
import Foundation
import SwiftData

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case income, expense, transfer
    
    var id: String { rawValue }
}

struct TransactionDraft {
    var amount: Decimal = 0
    var kind: TransactionKind = .expense
    var source: Source?
    var destination: Source?
    var note: String = ""
    var date: Date = Date.now
    var category: Category?
    
    init () {}
    
    init(_ transaction: Transaction) {
        amount = transaction.amount
        kind = transaction.kind
        source = transaction.source
        destination = transaction.destination
        note = transaction.note
        date = transaction.date
        category = transaction.category
    }

    func apply(to transaction: Transaction) {
        transaction.amount = amount
        transaction.kind = kind
        transaction.source = source
        transaction.destination = destination
        transaction.note = note
        transaction.date = date
        transaction.category = category
    }
}

@Model
final class Transaction {
    var amount: Decimal = 0
    var kind: TransactionKind = TransactionKind.expense
    var source: Source?
    var destination: Source?
    var note: String = ""
    var date: Date = Date.now
    var category: Category?
    
    init(amount: Decimal, kind: TransactionKind, source: Source? = nil, destination: Source? = nil, note: String, date: Date, category: Category? = nil) {
        self.amount = amount
        self.kind = kind
        self.source = source
        self.destination = destination
        self.note = note
        self.date = date
        self.category = category
    }
}
