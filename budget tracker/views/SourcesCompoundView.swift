//
//  SourcesCompoundView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 27.09.2026..
//

import SwiftUI
import SwiftData

struct SourcesCompoundView: View {
    @Environment(\.modelContext) var modelContext
    @Query var sources: [Source]
    @Query(sort: \Transaction.date, order: .reverse) var transactions: [Transaction]
    
    @State private var presentedSource: Source? = nil
    @State private var isPresentingUnassigned = false
    @State private var isTransactionListPresented: Bool = true
    @State private var isSourceListPresented: Bool = true
    @State private var searchTransactions: String = ""
    
    private var hasUnassignedTransactions: Bool {
        transactions.contains { transaction in
            (transaction.kind != .income && transaction.source == nil) ||
            (transaction.kind != .expense && transaction.destination == nil)
        }
    }
    
    private func getAmount(_ source: Source?) -> Decimal {
        let initValue = source?.initValue ?? 0
        let incoming = transactions.filter() { transaction in transaction.kind != .expense && transaction.destination == source }.reduce(0) { $0 + $1.amount }
        let outgoing = transactions.filter() { transaction in transaction.kind != .income && transaction.source == source }.reduce(0) { $0 + $1.amount }
        
        return initValue + incoming - outgoing
    }
    
    private func onSource(_ source: Source) {
        self.presentedSource = source
    }
    
    func onDelete (_ indexSet: IndexSet, from items: [Transaction]) {
        for index in indexSet {
            let transaction = items[index]
            modelContext.delete(transaction)
        }
    }
    
    private var filteretedTransactions: [Transaction] {
        let query = searchTransactions.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return transactions }
        return transactions.filter { transaction in
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
        List {
            Section("sources", isExpanded: $isSourceListPresented) {
                ForEach(sources) { source in
                    Button(action: { onSource(source) }) {
                        HStack {
                            CategoryImageView(systemImage: source.systemImage, color: source.color)
                            Text(source.name)
                            Spacer()
                            Text(getAmount(source), format: .currency(code: currency))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("transactions", isExpanded: $isTransactionListPresented) {
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
                            .foregroundStyle(.secondary)
                            .font(.default.bold())
                    }
                }
            }
            if hasUnassignedTransactions {
                Button(action: { isPresentingUnassigned = true }) {
                    HStack {
                        CategoryImageView(systemImage: "questionmark", color: .gray)
                        Text("no_source")
                        Spacer()
                        Text(getAmount(nil), format: .currency(code: currency))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .sheet(item: $presentedSource) { source in
            TransactionsView(source: source)
        }
        .sheet(isPresented: $isPresentingUnassigned) {
            TransactionsView(source: nil)
        }
    }
}

#Preview {
    SourcesCompoundView().modelContainer(makeMainViewPreviewContainer())
}
