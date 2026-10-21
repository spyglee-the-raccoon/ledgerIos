//
//  CollectionView.swift
//  ledger
//
//  Created by Maksym Bahrov on 07.10.2026..
//

import SwiftUI
import SwiftData

struct CollectionView: View {
    var collection: TransactionCollection
    
    @State private var searchTransactions: String = ""
    
    var currency: String { Locale.current.currency?.identifier ?? "EUR" }

    var topCategories: [(category: Category, total: Decimal)] {
        let categorized = collection.transactions.compactMap { transaction in
            transaction.category.map { (category: $0, transaction: transaction) }
        }
        let grouped = Dictionary(grouping: categorized) { $0.category.persistentModelID }
        return grouped.values
            .compactMap { pairs -> (category: Category, total: Decimal)? in
                guard let category = pairs.first?.category else { return nil }
                return (category, getTotal(for: pairs.map(\.transaction)))
            }
            .sorted { abs($0.total) > abs($1.total) }
            .prefix(3)
            .map { $0 }
    }
    
    func onDelete(_ indexSet: IndexSet, from items: [Transaction]) {
        let removedIDs = Set(indexSet.map { items[$0].persistentModelID })
        collection.transactions.removeAll { removedIDs.contains($0.persistentModelID) }
    }

    private var filteretedTransactions: [Transaction] {
        let query = searchTransactions.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return collection.transactions }
        return collection.transactions.filter { transaction in
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
            Section {
                HStack {
                    CategoryImageView(systemImage: collection.systemImage, color: collection.color)
                    Text(collection.name)
                    Spacer()
                    Text(
                        getTotal(for: collection.transactions),
                        format: .currency(code: currency))
                }
            }

            if !topCategories.isEmpty {
                Section("top categories") {
                    ForEach(topCategories, id: \.category.persistentModelID) { item in
                        HStack {
                            CategoryImageView(systemImage: item.category.systemImage, color: item.category.color)
                            Text(item.category.name)
                            Spacer()
                            Text(item.total, format: .currency(code: currency))
                        }
                    }
                }
            }

            Section("transactions") {
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
        }
        .navigationTitle(collection.name)
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView("no_transactions", systemImage: "receipt")
            }
        }
        .toolbar {
            NavigationLink(destination: AddCollectionView(collection: collection)) {
                Image(systemName: "pencil")
            }
        }
    }
}

#Preview {
    let expenseCategory = Category(name: "Bill", systemImage: "tag", color: .yellow, categoryKind: CategoryKind.expense )
    let expenseCategory2 = Category(name: "Food", systemImage: "basket", color: .green, categoryKind: CategoryKind.expense )
    let source = Source(name: "Credit Card", systemImage: "tag", initValue: 50, color: CategoryColor.blue)
    let expense = Transaction(amount: 20, kind: TransactionKind.expense, source: source, note: "Some ExpenseNote", date: Date.now, category: expenseCategory)
    let expense2 = Transaction(amount: 50, kind: TransactionKind.expense, source: source, note: "", date: Date.now, category: expenseCategory2)
    let collection1 = TransactionCollection(id: UUID(), name: "Trip to Naples", systemImage: "globe", color: .red, transactions: [expense, expense2])
    
    NavigationView {
        CollectionView(collection: collection1)
    }
}
