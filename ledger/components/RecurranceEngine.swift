//
//  RecurranceEngine.swift
//  Ledger
//
//  Created by Maksym Bahrov on 20.10.2026..
//
import Foundation
import SwiftData

enum RecurrenceEngine {
    @MainActor
    static func generateDue(in context: ModelContext, now: Date = .now) throws {
        let templates = try context.fetch(FetchDescriptor<PlannedTransaction>(
            predicate: #Predicate { !$0.isPaused }
        ))
        for template in templates {
            while let due = template.nextDueDate, due <= now {
                if let end = template.endDate, due > end { break }
                let transaction = Transaction(
                    amount: template.amount, kind: template.kind,
                    source: template.source, destination: template.destination,
                    note: template.note, date: due, category: template.category
                )
                transaction.plannedTransaction = template
                context.insert(transaction)
                template.occurrencesGenerated += 1
            }
        }
        try context.save()
        PlannedTransactionNotifier.reschedule(in: context, now: now)
        BudgetNotifier.check(in: context, now: now)
    }
}
