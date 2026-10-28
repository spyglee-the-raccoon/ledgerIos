//
//  BudgetingView.swift
//  Ledger
//
//  Created by Maksym Bahrov on 28.10.2026..
//

import SwiftUI
import SwiftData

struct BudgetingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query private var expenses: [Transaction]
    @State private var editingBudget: Budget?

    init(month: DateInterval = .month(containing: .now)) {
        let kind = TransactionKind.expense
        let start = month.start
        let end = month.end
        _expenses = Query(filter: #Predicate<Transaction> {
            $0.kind == kind && $0.date >= start && $0.date < end
        })
    }

    private var generalBudget: Budget? {
        budgets.first(where: \.isGeneral)
    }

    private var categoryBudgets: [Budget] {
        budgets
            .filter { !$0.isGeneral }
            .sorted { ($0.category?.name ?? "").localizedStandardCompare($1.category?.name ?? "") == .orderedAscending }
    }

    private func spent(for budget: Budget) -> Decimal {
        guard let category = budget.category else {
            return expenses.reduce(0) { $0 + $1.amount }
        }
        return expenses
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    /// The general monthly limit always exists so it can be switched on and off.
    private func ensureGeneralBudget() {
        guard generalBudget == nil else { return }
        modelContext.insert(Budget(limit: 0, isActive: false))
    }

    var body: some View {
        List {
            if let generalBudget {
                Section {
                    card(for: generalBudget)
                }
            }
            Section {
                ForEach(categoryBudgets) { budget in
                    card(for: budget)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(budget)
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("categories")
            } footer: {
                if categoryBudgets.isEmpty {
                    Text("no_category_budgets")
                }
            }
        }
        .navigationTitle("budgeting")
        .navigationDestination(item: $editingBudget) { budget in
            AddBudgetView(budget: budget)
        }
        .toolbar {
            NavigationLink(destination: AddBudgetView()) {
                Image(systemName: "plus")
            }
        }
        .onAppear(perform: ensureGeneralBudget)
        // Picks up toggles and deletions made on this screen.
        .onDisappear { BudgetNotifier.check(in: modelContext) }
    }

    private func card(for budget: Budget) -> some View {
        BudgetCardView(budget: budget, spent: spent(for: budget))
            .contentShape(.rect)
            .onTapGesture { editingBudget = budget }
            .swipeActions(edge: .leading) {
                Button {
                    budget.isActive.toggle()
                } label: {
                    if budget.isActive {
                        Label("deactivate", systemImage: "pause")
                    } else {
                        Label("activate", systemImage: "play")
                    }
                }
                .tint(budget.isActive ? .orange : .green)
            }
    }
}

private struct BudgetCardView: View {
    @Bindable var budget: Budget
    let spent: Decimal

    private var usage: Double { budget.usage(of: spent) }

    private var remaining: Decimal { budget.limit - spent }

    private var barColor: Color {
        guard budget.isActive else { return .gray }
        switch usage {
        case ..<0.8: return .green
        case ..<1: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let category = budget.category {
                    CategoryImageView(systemImage: category.systemImage, color: category.color)
                }
                VStack(alignment: .leading) {
                    if let category = budget.category {
                        Text(category.name)
                    } else {
                        Text("general_budget")
                    }
                    if budget.limit > 0 {
                        Group {
                            if remaining >= 0 {
                                Text("budget_left \(remaining, format: .currency(code: currency))")
                            } else {
                                Text("budget_over \(-remaining, format: .currency(code: currency))")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                    }
                }
                .padding(.horizontal, 2)
                Spacer()
                Toggle("active", isOn: $budget.isActive)
                    .labelsHidden()
            }

            HStack {
                Text(spent, format: .currency(code: currency))
                    .font(.default.bold())
                Text(verbatim: "/")
                    .foregroundStyle(.secondary)
                Text(budget.limit, format: .currency(code: currency))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(usage, format: .percent.precision(.fractionLength(0)))
                    .font(.default.bold())
                    .foregroundStyle(barColor)
            }

            ProgressView(value: min(usage, 1))
                .tint(barColor)
        }
        .padding(.vertical, 4)
        .opacity(budget.isActive ? 1 : 0.5)
    }
}

#Preview {
    NavigationStack {
        BudgetingView()
    }
    .modelContainer(makeMainViewPreviewContainer())
}
