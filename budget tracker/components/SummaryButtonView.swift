//
//  SummaryButtonView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 22.09.2026..
//

import SwiftUI
import SwiftData

var currency: String { Locale.current.currency?.identifier ?? "EUR" }

extension DateInterval {
    static func month(containing date: Date = .now, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}

struct SummaryButtonView: View {
    var action: () -> Void
    var categoryKind: CategoryKind
    
    @Query private var transactions: [Transaction]

    init(action: @escaping () -> Void, categoryKind: CategoryKind, month: DateInterval = .month(containing: .now)) {
        self.action = action
        self.categoryKind = categoryKind

        let kind: TransactionKind = categoryKind == .income ? .income : .expense
        let start = month.start
        let end = month.end
        _transactions = Query(filter: #Predicate<Transaction> {
            $0.kind == kind && $0.date >= start && $0.date < end
        })
    }

    private var isIncome: Bool { categoryKind == .income}

    private var total: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
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
