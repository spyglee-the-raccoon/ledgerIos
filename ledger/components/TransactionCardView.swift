//
//  TransactionCardView.swift
//  ledger
//
//  Created by Maksym Bahrov on 27.09.2026..
//

import SwiftUI
import SwiftData

struct TransactionCardView: View {
    let transaction: Transaction

    @State private var isCollectionPickerPresented: Bool = false
    // Collection chosen in the picker; navigation happens once the sheet is dismissed
    @State private var pendingCollection: TransactionCollection?
    @State private var navigationCollection: TransactionCollection?

    init(transaction: Transaction) {
        self.transaction = transaction
    }
    
    var body: some View {
        NavigationLink(destination: AddTransactionView(transaction: transaction)) {
            TransactionCardContent(data: TransactionCardData(transaction), currencyCode: currency)
        }
        .contextMenu {
            Button {
                isCollectionPickerPresented = true
            } label: {
                Label("add_to_collection", systemImage: "folder.badge.plus")
            }
        }
        .sheet(isPresented: $isCollectionPickerPresented, onDismiss: {
            navigationCollection = pendingCollection
            pendingCollection = nil
        }) {
            CollectionPickerView { collection in
                addToCollection(collection)
                pendingCollection = collection
                isCollectionPickerPresented = false
            }
        }
        .navigationDestination(item: $navigationCollection) { collection in
            CollectionView(collection: collection)
        }
    }

    private func addToCollection(_ collection: TransactionCollection) {
        let alreadyAdded = collection.transactions.contains {
            $0.persistentModelID == transaction.persistentModelID
        }
        if !alreadyAdded {
            collection.transactions.append(transaction)
        }
    }
}

private struct CollectionPickerView: View {
    @Query var collections: [TransactionCollection]
    @Environment(\.dismiss) private var dismiss

    let onSelect: (TransactionCollection) -> Void

    var body: some View {
        NavigationStack {
            List(collections) { collection in
                Button {
                    onSelect(collection)
                } label: {
                    HStack {
                        CategoryImageView(systemImage: collection.systemImage, color: collection.color)
                        Text(collection.name)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .overlay {
                if collections.isEmpty {
                    ContentUnavailableView("no_collections", systemImage: "folder")
                }
            }
            .navigationTitle("collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let category: Category = Category(name: "Food", systemImage: "cart", color: .cyan, categoryKind: .expense )
    let transaction: Transaction = Transaction(amount: 40, kind: .expense, note: "Something", date: Date.now, category: category)
    TransactionCardView(transaction: transaction)
}
