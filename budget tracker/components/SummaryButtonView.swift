//
//  SummaryButtonView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 22.09.2026..
//

import SwiftUI
import SwiftData

var currency: String { Locale.current.currency?.identifier ?? "EUR" }

var today = Date.now

var currentMonth = Calendar.current.dateComponents([.month], from: today)

struct SummaryButtonView: View {
    var action: () -> Void
    var categoryKind: CategoryKind
    
    @Query private var transactions: [Transaction]

    init(action: @escaping () -> Void, categoryKind: CategoryKind) {
        self.action = action
        self.categoryKind = categoryKind

        let kind: TransactionKind = categoryKind == .income ? .income : .expense
        _transactions = Query(filter: #Predicate<Transaction> { $0.kind == kind })
    }

    private var isIncome: Bool { categoryKind == .income}

    private var total: Decimal {
        let currentMonthTransactions: [Transaction] = transactions.filter { transaction in
            Calendar.current.dateComponents([.month], from: transaction.date) == currentMonth
        }
        return currentMonthTransactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        Button { action() } label: {
            HStack {
                Image(systemName: isIncome ? "arrow.down" : "arrow.up")
                    .foregroundStyle(isIncome ? Color.green :
                        Color.red)
                    .frame(width: 25, height: 25, alignment: .center)
                    .background(isIncome ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .clipShape(.circle)
                VStack(alignment: .leading) {
                    Text(categoryKind.rawValue)
                        .font(.callout)
                        .foregroundStyle(Color.secondary)
                    Text(total, format: .currency(code: currency))
                        .font(.callout)
                        .foregroundStyle(Color.primary)
                }
                
            }.padding(.horizontal)
        }
        .buttonStyle(.glass)
    }
}

#Preview {
    SummaryButtonView(action: {}, categoryKind: .expense)
        .modelContainer(for: [Category.self, Source.self, Transaction.self], inMemory: true)
}
