//
//  TransactionsView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 27.09.2026..
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    let source: Source?
    @Query private var transactions: [Transaction]
    
    init(source: Source?) {
        self.source = source
        
        if let source {
            let sourceID = source.persistentModelID
            _transactions = Query(filter: #Predicate<Transaction> {
                $0.destination?.persistentModelID == sourceID || $0.source?.persistentModelID == sourceID
            })
        } else {
            let income = TransactionKind.income
            let expense = TransactionKind.expense
            _transactions = Query(filter: #Predicate<Transaction> {
                ($0.kind != income && $0.source == nil) || ($0.kind != expense && $0.destination == nil)
            })
        }
    }

    private var title: String {
        if let source {
            String(localized: "transactions_for \(source.name)")
        } else {
            String(localized: "transactions_without_source")
        }
    }
    
    private var sections: [(day: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.day) { section in
                    Section {
                        ForEach(section.items) { transaction in
                            TransactionCardView(transaction: transaction)
                        }
                    } header: {
                        Text(headerTitle(for: section.day))
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let source = Source(name: "Credit card", systemImage: "note")
    TransactionsView(source: source)
}
