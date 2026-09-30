//
//  ExpensesView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData

func headerTitle(for day: Date) -> LocalizedStringResource {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) { return "today" }
    if calendar.isDateInYesterday(day) { return "yesterday" }
    return "\(day, format: .dateTime.weekday(.wide).day().month(.wide).year())"
}

struct ExpensesView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var expenses: [Transaction]
    
    init() {
        let expense = TransactionKind.expense
        
        _expenses = Query(filter: #Predicate<Transaction> { $0.kind == expense })
    }
    
    func onDelete (_ indexSet: IndexSet, from items: [Transaction]) {
        for index in indexSet {
            let expense = items[index]
            modelContext.delete(expense)
        }
    }
    
    private var sections: [(day: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: expenses) {
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
                        .onDelete { onDelete($0, from: section.items) }
                    } header: {
                        Text(headerTitle(for: section.day))
                    }
                }
            }
            .navigationTitle("expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink(destination: AddTransactionView()) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    ExpensesView().modelContainer(makeMainViewPreviewContainer())
}
