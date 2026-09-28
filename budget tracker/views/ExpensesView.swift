//
//  ExpensesView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData

func headerTitle(for day: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) { return "Today" }
    if calendar.isDateInYesterday(day) { return "Yesterday" }
    return day.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
}

struct ExpensesView: View {
    @Environment(\.modelContext) var modelContext
    @Query private var expenses: [Transaction]
    
    init() {
        let expense = TransactionKind.expense
        
        _expenses = Query(filter: #Predicate<Transaction> { $0.kind == expense })
    }
    
    func onDelete (_ indexSet: IndexSet) {
        for index in indexSet {
            let income = expenses[index]
            modelContext.delete(income)
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
            .navigationTitle("Expenses")
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
