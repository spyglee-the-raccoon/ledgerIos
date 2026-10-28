//
//  AddBudgetView.swift
//  Ledger
//
//  Created by Maksym Bahrov on 28.10.2026..
//

import SwiftUI
import SwiftData

struct AddBudgetView: View {
    var budget: Budget?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft: BudgetDraft

    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var budgets: [Budget]

    init(budget: Budget? = nil) {
        self.budget = budget
        _draft = State(initialValue: budget.map(BudgetDraft.init) ?? BudgetDraft())
    }

    private var isEditing: Bool { budget != nil }

    private var isGeneral: Bool { budget?.isGeneral ?? false }

    /// Expense categories that don't have a limit yet, plus the one being edited.
    private var availableCategories: [Category] {
        let taken = Set(budgets.compactMap { $0.category?.persistentModelID })
        return categories.filter { category in
            category.categoryKind == .expense
                && (!taken.contains(category.persistentModelID) || category == budget?.category)
        }
    }

    private var isValid: Bool {
        draft.limit > 0 && (isGeneral || draft.category != nil)
    }

    private func save() {
        if let budget {
            draft.apply(to: budget)
        } else {
            modelContext.insert(Budget(limit: draft.limit, isActive: draft.isActive, category: draft.category))
        }
        Task {
            await PlannedTransactionNotifier.requestAuthorization()
            BudgetNotifier.check(in: modelContext)
        }
        dismiss()
    }

    var body: some View {
        Form {
            if !isGeneral {
                Section {
                    Picker("category", selection: $draft.category) {
                        Text("none").tag(Category?.none)
                        ForEach(availableCategories) { category in
                            HStack {
                                Image(systemName: category.systemImage)
                                Text(category.name)
                            }
                            .tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("monthly_limit") {
                TextField("amount", value: $draft.limit, format: .number)
                    .keyboardType(.decimalPad)
            }

            Section {
                Toggle("active", isOn: $draft.isActive)
            }
        }
        .navigationTitle(isGeneral ? "general_budget" : isEditing ? "edit_budget" : "add_budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) {
                    Image(systemName: "arrow.down.circle")
                }
                .disabled(!isValid)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddBudgetView()
    }
    .modelContainer(makeMainViewPreviewContainer())
}
