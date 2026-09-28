//
//  SourcesCompoundView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 27.09.2026..
//

import SwiftUI
import SwiftData

struct SourcesCompoundView: View {
    @Query var sources: [Source]
    @Query var transactions: [Transaction]
    @State private var presentedSource: Source? = nil
    
    private func getAmount(_ source: Source) -> Decimal {
        let initValue = source.initValue
        let allIncomes = transactions.filter() { transaction in transaction.kind == .income && transaction.destination == source}.reduce(0) { $0 + $1.amount }
        let allExpenses = transactions.filter() { transaction in transaction.kind == .expense && transaction.source == source}.reduce(0) { $0 + $1.amount }
        
        return initValue + allIncomes - allExpenses
    }
    
    private func onSource(_ source: Source) {
        self.presentedSource = source
    }
    
    var body: some View {
        List {
            ForEach(sources) { source in
                Button(action: { onSource(source) }) {
                    HStack {
                        CategoryImageView(systemImage: source.systemImage, color: source.color)
                        Text(source.name)
                        Spacer()
                        Text(getAmount(source), format: .currency(code: currency))
                    }
                }
            }
        }
        .sheet(item: $presentedSource) { source in
            TransactionsView(source: source)
        }
    }
}

#Preview {
    SourcesCompoundView().modelContainer(makeMainViewPreviewContainer())
}
