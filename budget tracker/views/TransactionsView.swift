//
//  TransactionsView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 27.09.2026..
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    let source: Source
    @Query private var transactions: [Transaction]
    
    init(source: Source) {
        self.source = source
        
        let sourceID = source.persistentModelID
        _transactions = Query(filter: #Predicate<Transaction> {
            $0.destination?.persistentModelID == sourceID || $0.source?.persistentModelID == sourceID
        })
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
            .navigationTitle("Transactions for \(source.name)")
        }
    }
}

#Preview {
    let source = Source(name: "Credit card", systemImage: "note")
    TransactionsView(source: source)
}
