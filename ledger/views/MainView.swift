//
//  MainView.swift
//  ledger
//
//  Created by Maksym Bahrov on 10.09.2026..
//

import SwiftUI
import SwiftData

enum MainViewActiveSheet: Identifiable {
    case expenses, incomes, add
    var id: Self { self }
}

/// Screens pushed when opened from a widget.
enum MainViewDestination: Hashable {
    case budgeting, sources
}

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) var sizeClass

    /// While the app lock is shown, quick actions wait instead of opening a sheet over it.
    var isLocked = false
    
    @State private var activeSheet: MainViewActiveSheet?
    @State private var destination: MainViewDestination?
    @State private var currentMonth = DateInterval.month(containing: .now)
    @State private var thisMonth = DateInterval.month(containing: .now)
    @State private var sharedReceiptText: String?
    /// Set by the Scan quick action so the add sheet opens straight into the scanner.
    @State private var startsScanning = false

    /// Only the oldest transaction is needed to know how far back the user can swipe.
    @Query(MainView.earliestTransactionDescriptor) private var earliestTransactions: [Transaction]

    private static var earliestTransactionDescriptor: FetchDescriptor<Transaction> {
        var descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    private var canShowPreviousMonth: Bool {
        guard let earliest = earliestTransactions.first?.date else { return false }
        return earliest < currentMonth.start
    }

    private var canShowNextMonth: Bool {
        currentMonth.start < thisMonth.start
    }

    var body: some View {
        NavigationStack {
            VStack {
                HeaderView()
                if sizeClass == .compact {
                    MainChartActionView(month: currentMonth, activeSheet: $activeSheet)
                        .contentShape(.rect)
                        .simultaneousGesture(monthSwipeGesture)
                    ActionView(month: currentMonth, activeSheet: $activeSheet)
                } else {
                    HStack {
                        MainChartActionView(month: currentMonth, activeSheet: $activeSheet)
                            .contentShape(.rect)
                            .simultaneousGesture(monthSwipeGesture)
                        ActionView(month: currentMonth, activeSheet: $activeSheet)
                    }
                }
            }
            .sheet(item: $activeSheet, onDismiss: {
                sharedReceiptText = nil
                startsScanning = false
            }) { sheet in
                switch sheet {
                case .add: NavigationStack {
                    AddTransactionView(sharedReceiptText: sharedReceiptText, startsScanning: startsScanning)
                        .navigationTitle("add_transaction")
                }
                case .expenses: ExpensesView()
                case .incomes: IncomesView()
                }
            }
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .budgeting: BudgetingView()
                case .sources: SourcesCompoundView()
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
        .onOpenURL { url in
            if let route = AppRoute(url: url) {
                AppRouter.shared.pending = route
            } else {
                handleSharedReceipt(url)
            }
        }
        .onChange(of: AppRouter.shared.pending, initial: true) { performPendingRoute() }
        .onChange(of: isLocked) { performPendingRoute() }
    }

    /// Opens what a quick action or widget asked for, once the app is unlocked.
    private func performPendingRoute() {
        guard !isLocked, let route = AppRouter.shared.pending else { return }
        AppRouter.shared.pending = nil
        switch route {
        case .addTransaction:
            activeSheet = .add
        case .scanReceipt:
            startsScanning = true
            activeSheet = .add
        case .main:
            activeSheet = nil
            destination = nil
        case .budgeting:
            activeSheet = nil
            destination = .budgeting
        case .sources:
            activeSheet = nil
            destination = .sources
        }
    }

    /// Handles `ladger://scan?text=...` sent by the share extension after it recognized a receipt photo.
    private func handleSharedReceipt(_ url: URL) {
        guard url.scheme == "ladger", url.host() == "scan",
              let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "text" })?.value,
              !text.isEmpty else { return }
        sharedReceiptText = text
        activeSheet = .add
    }
    
    /// Swipe right → previous month, swipe left → next month.
    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) else { return }
                if dx > 0, canShowPreviousMonth {
                    shiftMonth(by: -1)
                } else if dx < 0, canShowNextMonth {
                    shiftMonth(by: 1)
                }
            }
    }

    private func shiftMonth(by value: Int) {
        guard let date = Calendar.current.date(byAdding: .month, value: value, to: currentMonth.start) else { return }
        withAnimation(.snappy) {
            currentMonth = DateInterval.month(containing: date)
        }
    }

    private func refreshCurrentMonth() {
        let month = DateInterval.month(containing: .now)
        guard month != thisMonth else { return }
        // Follow the month rollover only if the user was looking at the current month.
        if currentMonth == thisMonth { currentMonth = month }
        thisMonth = month
    }
}

@MainActor
func makeMainViewPreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: Source.self, Transaction.self, Category.self, TransactionCollection.self, PlannedTransaction.self, Budget.self, ReceiptItem.self, ReceiptPhoto.self,
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
    let collection1 = TransactionCollection(id: UUID(), name: "Trip to Naples", systemImage: "globe", color: .red, transactions: [expense, expense2])
    let collection2 = TransactionCollection(id: UUID(), name: "Busines trip", systemImage: "wallet.pass", color: .blue, transactions: [expense3])
    
    container.mainContext.insert(source)
    container.mainContext.insert(expense)
    container.mainContext.insert(expense2)
    container.mainContext.insert(expense3)
    container.mainContext.insert(income)
    container.mainContext.insert(incomeCategory)
    container.mainContext.insert(incomeCategory2)
    container.mainContext.insert(collection1)
    container.mainContext.insert(collection2)

    // Demo planned transactions covering the different card states.
    let savings = Source(name: "Savings", systemImage: "building.columns", initValue: 1000, color: CategoryColor.indigo)
    let calendar = Calendar.current
    func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: .now) ?? .now }

    let plannedTransactions = [
        // Monthly expense with a note
        PlannedTransaction(amount: 12.99, kind: .expense, source: source, note: "Netflix", category: expenseCategory, frequency: .monthly, interval: 1, startDate: daysAgo(20), occurrencesGenerated: 1, isPaused: false),
        // Monthly expense without a note (falls back to category name)
        PlannedTransaction(amount: 850, kind: .expense, source: source, note: "", category: expenseCategory, frequency: .monthly, interval: 1, startDate: daysAgo(3), occurrencesGenerated: 1, isPaused: false),
        // Weekly expense
        PlannedTransaction(amount: 65.40, kind: .expense, source: source, note: "Weekly groceries", category: expenseCategory2, frequency: .weekly, interval: 1, startDate: daysAgo(2), occurrencesGenerated: 1, isPaused: false),
        // Monthly income
        PlannedTransaction(amount: 3200, kind: .income, destination: source, note: "", category: incomeCategory, frequency: .monthly, interval: 1, startDate: daysAgo(25), occurrencesGenerated: 1, isPaused: false),
        // Custom interval income
        PlannedTransaction(amount: 450, kind: .income, destination: source, note: "Freelance retainer", category: incomeCategory2, frequency: .weekly, interval: 2, startDate: daysAgo(10), occurrencesGenerated: 1, isPaused: false),
        // Transfer
        PlannedTransaction(amount: 200, kind: .transfer, source: source, destination: savings, note: "", frequency: .monthly, interval: 1, startDate: daysAgo(15), occurrencesGenerated: 1, isPaused: false),
        // Yearly expense with a long note
        PlannedTransaction(amount: 129, kind: .expense, source: source, note: "Annual software license renewal that has a really long description", category: expenseCategory, frequency: .yearly, interval: 1, startDate: daysAgo(300), occurrencesGenerated: 1, isPaused: false),
        // Paused
        PlannedTransaction(amount: 39.90, kind: .expense, source: source, note: "Gym membership", category: expenseCategory3, frequency: .monthly, interval: 1, startDate: daysAgo(40), occurrencesGenerated: 2, isPaused: true),
        // Ended (next due date is past the end date)
        PlannedTransaction(amount: 75, kind: .expense, source: source, note: "Car loan", category: expenseCategory, frequency: .monthly, interval: 1, startDate: daysAgo(120), endDate: daysAgo(10), occurrencesGenerated: 4, isPaused: false),
        // Uncategorized, every 3 days
        PlannedTransaction(amount: 5, kind: .expense, source: source, note: "", frequency: .daily, interval: 3, startDate: daysAgo(1), occurrencesGenerated: 1, isPaused: false)
    ]

    container.mainContext.insert(savings)
    plannedTransactions.forEach { container.mainContext.insert($0) }

    // Demo budgets: under, near and over the limit, plus an inactive one.
    let budgets = [
        Budget(limit: 500),
        Budget(limit: 100, category: expenseCategory2),
        Budget(limit: 22, category: expenseCategory),
        Budget(limit: 80, isActive: false, category: expenseCategory3)
    ]
    budgets.forEach { container.mainContext.insert($0) }

    // Demo receipts: the same products bought monthly over a year, so price comparison has data.
    for month in 0..<12 {
        let date = calendar.date(byAdding: .month, value: month - 11, to: .now) ?? .now
        let milk = Decimal(119 + month * 2) / 100
        let bread = Decimal(149 + (month / 4) * 10) / 100
        let receipt = Transaction(amount: milk * 2 + bread, kind: .expense, source: source, note: "Konzum", date: date, category: expenseCategory2)
        receipt.receiptItems = [
            ReceiptItem(name: "MLIJEKO 2,8% 1L", quantity: 2, unitPrice: milk, totalPrice: milk * 2, position: 0),
            ReceiptItem(name: "KRUH POLUBIJELI", quantity: 1, unitPrice: bread, totalPrice: bread, position: 1)
        ]
        container.mainContext.insert(receipt)
    }
    return container
}

#Preview {
    MainView()
        .modelContainer(makeMainViewPreviewContainer())
}
