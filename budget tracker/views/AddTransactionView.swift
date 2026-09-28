//
//  AddTransactionView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    var transaction: Transaction?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var draft: TransactionDraft
    
    @Query var categories: [Category]
    @Query var sources: [Source]
    
    init(transaction: Transaction? = nil, selectedKind: TransactionKind = .expense) {
        self.transaction = transaction
        var draft: TransactionDraft
        if let transaction {
            draft = TransactionDraft(transaction)
        } else {
            draft = TransactionDraft()
            draft.kind = selectedKind
        }
        _draft = State(initialValue: draft)
    }
    
    var isEditing: Bool {
        transaction != nil
    }
    
    private var incomeCategories: [Category] {
        categories.filter { $0.categoryKind == .income }
    }
    
    private var expenseCategories: [Category] {
        categories.filter { $0.categoryKind == .expense }
    }
    
    private var availableCategories: [Category] {
        self.draft.kind == .income ? incomeCategories : expenseCategories
    }
    
    private func editTransaction() {
        guard let transaction else { return }
        draft.apply(to: transaction)
        dismiss()
    }
    
    private func addTransaction() {
        let newTransaction = Transaction(
            amount: draft.amount,
            kind: draft.kind,
            source: draft.source,
            destination: draft.destination,
            note: draft.note,
            date: draft.date,
            category: draft.category
        )
        modelContext.insert(newTransaction)
        dismiss()
    }
    
    private var isValid: Bool {
        switch draft.kind {
        case .expense:
            return draft.amount > 0 && draft.category != nil && draft.source != nil
        case .income:
            return draft.amount > 0 && draft.category != nil && draft.destination != nil
        case .transfer:
            return draft.amount > 0 && draft.source != nil && draft.destination != nil
        }
    }
    
    var body: some View {
        Form {
            Picker("Kind", selection: $draft.kind) {
                ForEach(TransactionKind.allCases) { kind in
                    Text(kind.rawValue.capitalized)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)
            
            Section("Amount") {
                TextField("Amount", value: $draft.amount, format: .number)
                    .keyboardType(.decimalPad)
            }
            
            if draft.kind != .income {
                Section {
                    Picker("Source", selection: $draft.source) {
                        ForEach(sources) { source in
                            HStack {
                                Image(systemName: source.systemImage)
                                Text(source.name)
                            }
                            .tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            if draft.kind != .expense {
                Section {
                    Picker("Destination", selection: $draft.destination) {
                        ForEach(sources) { source in
                            HStack {
                                Image(systemName: source.systemImage)
                                Text(source.name)
                            }
                            .tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            if draft.kind != .transfer {
                Section {
                    Picker("Category", selection: $draft.category) {
                        ForEach(availableCategories) { category in
                            HStack {
                                Image(systemName: category.systemImage)
                                Text(category.name)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            Section("Note") {
                TextField("Note", text: $draft.note)
            }
        }
        .navigationTitle(isEditing ? "Edit transaction" : "Add transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: isEditing ? editTransaction : addTransaction) {
                    Image(systemName: "arrow.down.circle")
                }
                .disabled(!isValid)
            }
        }
    }
}

#Preview {
    AddTransactionView(selectedKind: .income).modelContainer(makeMainViewPreviewContainer())
}
