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
    @State private var isPresentingUnassigned = false
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
            if hasUnassignedTransactions {
                Button(action: { isPresentingUnassigned = true }) {
                    HStack {
                        CategoryImageView(systemImage: "questionmark", color: .gray)
                        Text("No source")
                        Spacer()
                        Text(getAmount(nil), format: .currency(code: currency))
                    }
                }
            }
        }
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
