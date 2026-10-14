//
//  IncomesView.swift
//  ledger
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData

struct IncomesView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var incomes: [Transaction]
    @State private var searchTransactions: String = ""
    
    init() {
        let income = TransactionKind.income
        
        _incomes = Query(filter: #Predicate<Transaction> { $0.kind == income })
    }

    func onDelete (_ indexSet: IndexSet, from items: [Transaction]) {
        for index in indexSet {
            let income = items[index]
            modelContext.delete(income)
        }
    }
    
    private var filteretedTransactions: [Transaction] {
        let query = searchTransactions.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return incomes }
        return incomes.filter { transaction in
            transaction.note.localizedStandardContains(query) ||
            (transaction.category?.name.localizedStandardContains(query) ?? false)
        }
    }
    
    private var sections: [(day: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteretedTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
    
    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("search_transactions", text: $searchTransactions)
                }
                ForEach(sections, id: \.day) { section in
                    Section {
                        ForEach(section.items) { transaction in
                            TransactionCardView(transaction: transaction)
                        }
                        .onDelete { onDelete($0, from: section.items) }
                    } header: {
                        Text(headerTitle(for: section.day))
                    }
                }
            }
            .navigationTitle("incomes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink(destination: AddTransactionView(selectedKind: .income)) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    IncomesView().modelContainer(makeMainViewPreviewContainer())
}
