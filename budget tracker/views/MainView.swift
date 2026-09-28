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
    @State private var activeSheet: MainViewActiveSheet?
    @State private var userName = "John"
    @State private var currentMonth = DateInterval.month(containing: .now)
    
    @Query private var expenses: [Transaction]
    @Query private var incomes: [Transaction]
    @Query private var sources: [Source]
    @Query private var categories: [Category]

    init() {
        let expense = TransactionKind.expense
        let income = TransactionKind.income

        _expenses = Query(filter: #Predicate<Transaction> { $0.kind == expense })
        _incomes = Query(filter: #Predicate<Transaction> { $0.kind == income })
    }

    var balance: Decimal {
        let initials: Decimal = sources.reduce(0) { $0 + $1.initValue }
        let incomes: Decimal = incomes.reduce(0) { $0 + $1.amount }
        let expenses: Decimal = expenses.reduce(0) { $0 + $1.amount }
        
        return initials + incomes - expenses
    }
    
    var isDark: Bool {
        colorScheme == .dark
    }
    
    func onToggleExpensesSheet() {
        activeSheet = .expenses
    }
    
    func onToggleIncomesSheet() {
        activeSheet = .incomes
    }
    
    func onAddTransaction() {
        activeSheet = .add
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack() {
                    VStack(alignment: .leading) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.callout)
                            .foregroundStyle(Color.secondary)
                        Text("Hello, " + userName)
                    }
                    Spacer()
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                        .buttonStyle(.glass)
                }.padding().background(Color.gray.opacity(0.2))
                Spacer()
                MainChartView(month: currentMonth)
                Spacer()
                Button(action: onAddTransaction) {
                    Text("Add Transaction").padding(10)
                }.buttonStyle(.glassProminent)
                VStack {
                    Text("total balance")
                        .textCase(.uppercase)
                        .font(.callout)
                        .foregroundStyle(Color.secondary)
                    NavigationLink(destination: SourcesCompoundView().navigationTitle("Sources")) {
                        Text(
                            balance,
                            format: .currency(code: currency)
                        )
                    }
                    .font(.largeTitle)
                    .foregroundStyle(.primary)
                    .fontWeight(.bold)
                    
                    HStack {
                        Spacer()
                        SummaryButtonView(action: onToggleExpensesSheet, categoryKind: .expense, month: currentMonth)
                        Spacer()
                        SummaryButtonView(action: onToggleIncomesSheet, categoryKind: .income, month: currentMonth)
                        Spacer()
                    }
                }.padding(.vertical).background(Color.gray.opacity(0.3))
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add: NavigationView { AddTransactionView().navigationTitle("Add transaction") }
                case .expenses: ExpensesView()
                case .incomes: IncomesView()
                }
            }
        }
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
    let expenseCategory = Category(name: "Bill", systemImage: "tag", color: .yellow, categoryKind: CategoryKind.expense )
    let expenseCategory2 = Category(name: "Food", systemImage: "basket", color: .green, categoryKind: CategoryKind.expense )
    let expenseCategory3 = Category(name: "Eating Out", systemImage: "fork.knife", color: .orange, categoryKind: CategoryKind.expense )
    let source = Source(name: "Credit Card", systemImage: "tag", initValue: 50, color: CategoryColor.blue)
    let expense = Transaction(amount: 20, kind: TransactionKind.expense, note: "Some ExpenseNote", date: Date.now, category: expenseCategory)
    let expense2 = Transaction(amount: 50, kind: TransactionKind.expense, note: "", date: Date.now, category: expenseCategory2)
    let expense3 = Transaction(amount: 100.20, kind: TransactionKind.expense, note: "Date", date: Date.now, category: expenseCategory3)
    let income = Transaction(amount: 100, kind: TransactionKind.income, note: "Some Income Note", date: Date.now, category: incomeCategory)

    container.mainContext.insert(source)
    container.mainContext.insert(expense)
    container.mainContext.insert(expense2)
    container.mainContext.insert(expense3)
    container.mainContext.insert(income)
    return container
}

#Preview {
    MainView()
        .modelContainer(makeMainViewPreviewContainer())
}
