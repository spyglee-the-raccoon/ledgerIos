//
//  CollectionsView.swift
//  ledger
//
//  Created by Maksym Bahrov on 06.10.2026..
//

import SwiftUI
import SwiftData

func getTotal (for transactions: [Transaction]) -> Decimal {
    var sum: Decimal = 0
    
    transactions.forEach { transaction in
        if transaction.kind == .income {
            sum += transaction.amount
        } else if transaction.kind == .expense {
            sum -= transaction.amount
        }
    }
    
    return sum
}

struct CollectionsView: View {
    @Query var collections: [TransactionCollection]
    
    var currency: String { Locale.current.currency?.identifier ?? "EUR" }
    
    var body: some View {
        List {
            ForEach(collections) { collection in
                NavigationLink(destination: CollectionView(collection: collection)) {
                    HStack {
                        CategoryImageView(
                            systemImage: collection.systemImage,
                            color: collection.color)
                        Text(collection.name)
                        Spacer()
                        Text(
                            getTotal(for: collection.transactions),
                            format: .currency(code: currency))
                    }
                }
            }
        }
        .navigationTitle("collections")
        .toolbar {
            NavigationLink(destination: AddCollectionView()) {
                Image(systemName: "plus")
            }
        }
    }
}

#Preview {
    CollectionsView().modelContainer(makeMainViewPreviewContainer())
}
