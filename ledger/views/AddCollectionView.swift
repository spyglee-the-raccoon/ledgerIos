//
//  AddCollectionView.swift
//  ledger
//
//  Created by Maksym Bahrov on 06.10.2026..
//

import SwiftUI
import SwiftData

struct AddCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let collection: TransactionCollection?
    @State private var draft: CollectionDraft
    @State private var symbolSearch = ""
    @State private var searchTransactions = ""
    @State private var showCollectionExistsAlert = false

    @Query var collections: [TransactionCollection]
    @Query(sort: \Transaction.date, order: .reverse) var transactions: [Transaction]

    init(collection: TransactionCollection? = nil) {
        self.collection = collection
        self.draft = collection.map { CollectionDraft($0) } ?? CollectionDraft()
    }

    private var isEditing: Bool {
        collection != nil
    }

    private var navigationTitleKey: LocalizedStringKey {
        isEditing ? "edit_collection" : "add_collection"
    }

    private var filteredSymbols: [String] {
        let query = symbolSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return icons }
        return icons.filter { $0.contains(query) }
    }

    private var filteredTransactions: [Transaction] {
        let query = searchTransactions.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return transactions }
        return transactions.filter { $0.matches(query) }
    }

    private var sections: [(day: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private func isSelected(_ transaction: Transaction) -> Bool {
        draft.transactions.contains { $0.persistentModelID == transaction.persistentModelID }
    }

    private func toggle(_ transaction: Transaction) {
        if let index = draft.transactions.firstIndex(where: { $0.persistentModelID == transaction.persistentModelID }) {
            draft.transactions.remove(at: index)
        } else {
            draft.transactions.append(transaction)
        }
    }

    private func validateAndSave() {
        let existingCollection = collections.firstIndex(where: {
            $0.persistentModelID != collection?.persistentModelID
                && $0.name == draft.trimmedName
        })
        if existingCollection != nil {
            showCollectionExistsAlert = true
            return
        }
        if let collection {
            draft.apply(to: collection)
        } else {
            let newCollection = TransactionCollection(name: draft.trimmedName, systemImage: draft.systemImage, color: draft.color, transactions: [])
            draft.apply(to: newCollection)
            modelContext.insert(newCollection)
        }
        dismiss()
    }

    func onSelectColor (_ newColor: CategoryColor) {
        draft.color = newColor
    }

    func onSelectIcon (_ newIcon: String) {
        draft.systemImage = newIcon
    }

    var body: some View {
        Form {
            Section("name") {
                HStack(spacing: 12) {
                    Image(systemName: draft.systemImage)
                        .font(.title3)
                        .foregroundStyle(draft.color.color)
                        .frame(width: 28)
                    TextField("collection_name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
            }

            Section("color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 12) {
                    ForEach(CategoryColor.allCases) { swatchColor in
                        ColorSwatchView(onSelectColor: onSelectColor, color: swatchColor, selectedColor: draft.color)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("icon") {
                TextField("search_symbols", text: $symbolSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if filteredSymbols.isEmpty {
                    ContentUnavailableView.search(text: symbolSearch)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            SymbolButtonView(onSelectIcon: onSelectIcon, symbol: symbol, selected: draft.systemImage)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("transactions") {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("search_transactions", text: $searchTransactions)
                        .autocorrectionDisabled()
                }
                if sections.isEmpty && !searchTransactions.isEmpty {
                    ContentUnavailableView.search(text: searchTransactions)
                }
            }

            ForEach(sections, id: \.day) { section in
                Section {
                    ForEach(section.items) { transaction in
                        Button {
                            toggle(transaction)
                        } label: {
                            SelectableTransactionRow(transaction: transaction, isSelected: isSelected(transaction))
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(headerTitle(for: section.day))
                }
            }
        }
        .navigationTitle(navigationTitleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    validateAndSave()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .disabled(draft.trimmedName.isEmpty)
            }
        }
        .alert("error", isPresented: $showCollectionExistsAlert) {
        } message: {
            Text("collection_exists")
        }
    }
}

/// A compact transaction row with a checkmark, used to pick transactions for a collection.
private struct SelectableTransactionRow: View {
    let transaction: Transaction
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            if transaction.kind == .transfer {
                CategoryImageView(systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90", color: .gray)
                title(Text("transfer"))
            } else if let category = transaction.category {
                CategoryImageView(systemImage: category.systemImage, color: category.color)
                title(Text(category.name))
            } else {
                CategoryImageView(systemImage: "questionmark", color: .gray)
                title(Text("uncategorized"))
            }
            Spacer()
            Text(transaction.amount, format: .currency(code: currency))
                .font(.default.bold())
                .foregroundStyle(amountColor)
        }
        .contentShape(Rectangle())
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .expense: .red
        case .income: .green
        case .transfer: .primary
        }
    }

    private func title(_ text: Text) -> some View {
        VStack(alignment: .leading) {
            text
            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }
}

#Preview {
    NavigationStack {
        AddCollectionView()
    }
    .modelContainer(makeMainViewPreviewContainer())
}
