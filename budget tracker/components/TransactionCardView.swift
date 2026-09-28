//
//  TransactionCardView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 27.09.2026..
//

import SwiftUI

struct TransactionCardView: View {
    let transaction: Transaction
    
    init(transaction: Transaction) {
        self.transaction = transaction
    }
    
    var isTransfer: Bool { transaction.kind == .transfer }
    
    var body: some View {
        NavigationLink(destination: AddTransactionView(transaction: transaction)) {
            HStack {
                if isTransfer {
                    CategoryImageView(systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90", color: .gray)
                    title(Text("Transfer"))
                } else if let category = transaction.category {
                    CategoryImageView(systemImage: category.systemImage, color: category.color)
                    title(Text(category.name))
                } else {
                    CategoryImageView(systemImage: "questionmark", color: .gray)
                    title(Text("Uncategorized"))
                }
                Spacer()
                Text(transaction.amount, format: .currency(code: currency))
                    .padding(.horizontal, 2)
                Text(transaction.date .formatted(date: .omitted, time: .shortened))
            }
        }
    }

    private func title(_ text: Text) -> some View {
        VStack(alignment: .leading) {
            text
            if transaction.note != "" {
                Text(transaction.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }
}

#Preview {
    let category: Category = Category(name: "Food", systemImage: "cart", color: .cyan, categoryKind: .expense )
    let transaction: Transaction = Transaction(amount: 40, kind: .expense, note: "Something", date: Date.now, category: category)
    TransactionCardView(transaction: transaction)
}
