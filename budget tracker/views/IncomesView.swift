//
//  IncomesView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData

struct IncomesView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var incomes: [Transaction]
    
    init() {
        let income = TransactionKind.income
        
        _incomes = Query(filter: #Predicate<Transaction> { $0.kind == income })
    }
    
    func onDelete (_ indexSet: IndexSet) {
        for index in indexSet {
            let income = incomes[index]
            modelContext.delete(income)
        }
    }
    
    private var sections: [(day: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: incomes) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sections, id: \.day) { section in
                    Section {
                        ForEach(section.items) { transaction in
                            TransactionCardView(transaction: transaction)
                        }
                        .onDelete(perform: onDelete)
                    } header: {
                        Text(headerTitle(for: section.day))
                    }
                }
            }
            .navigationTitle("Incomes")
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
