//
//  MainView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 10.09.2026..
//

import SwiftUI
import SwiftData

enum MainViewActiveSheet: Identifiable {
    case expenses, incomes, add
    var id: Self { self }
}

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var activeSheet: MainViewActiveSheet?
    @State private var currentMonth = DateInterval.month(containing: .now)
    
    var body: some View {
        NavigationStack {
            VStack {
                HeaderView()
                if sizeClass == .compact {
                    MainChartActionView(month: currentMonth, activeSheet: $activeSheet)
                    ActionView(month: currentMonth, activeSheet: $activeSheet)
                } else {
                    HStack {
                        MainChartActionView(month: currentMonth, activeSheet: $activeSheet)
                        ActionView(month: currentMonth, activeSheet: $activeSheet)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add: NavigationStack { AddTransactionView().navigationTitle("add_transaction") }
                case .expenses: ExpensesView()
                case .incomes: IncomesView()
                }
            }
        }.toolbarVisibility(.visible)
            .toolbarBackground(.blue)
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                refreshCurrentMonth()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refreshCurrentMonth() }
        }
    }
    
    private func refreshCurrentMonth() {
        let month = DateInterval.month(containing: .now)
        if month != currentMonth { currentMonth = month }
    }
}

@MainActor
func makeMainViewPreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: Source.self, Transaction.self, Category.self,
            configurations: config
        )
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
    let incomeCategory = Category(name: "Salary", systemImage: "note", color: .green, categoryKind: CategoryKind.income )
    let incomeCategory2 = Category(name: "Deposit", systemImage: "dollarsign.circle", color: .orange, categoryKind: CategoryKind.income )
    let expenseCategory = Category(name: "Bill", systemImage: "tag", color: .yellow, categoryKind: CategoryKind.expense )
    let expenseCategory2 = Category(name: "Food", systemImage: "basket", color: .green, categoryKind: CategoryKind.expense )
    let expenseCategory3 = Category(name: "Eating Out", systemImage: "fork.knife", color: .orange, categoryKind: CategoryKind.expense )
    let source = Source(name: "Credit Card", systemImage: "tag", initValue: 50, color: CategoryColor.blue)
    let expense = Transaction(amount: 20, kind: TransactionKind.expense, source: source, note: "Some ExpenseNote", date: Date.now, category: expenseCategory)
    let expense2 = Transaction(amount: 50, kind: TransactionKind.expense, source: source, note: "", date: Date.now, category: expenseCategory2)
    let expense3 = Transaction(amount: 100.20, kind: TransactionKind.expense, source: source, note: "Date", date: Date.now, category: expenseCategory3)
    let income = Transaction(amount: 100, kind: TransactionKind.income, destination: source, note: "Some Income Note, what if it gets very long long long long", date: Date.now, category: incomeCategory)
    
    container.mainContext.insert(source)
    container.mainContext.insert(expense)
    container.mainContext.insert(expense2)
    container.mainContext.insert(expense3)
    container.mainContext.insert(income)
    container.mainContext.insert(incomeCategory)
    container.mainContext.insert(incomeCategory2)
    return container
}

#Preview {
    MainView()
        .modelContainer(makeMainViewPreviewContainer())
}
