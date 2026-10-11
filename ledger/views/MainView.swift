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

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var activeSheet: MainViewActiveSheet?
    @State private var currentMonth = DateInterval.month(containing: .now)
    @State private var thisMonth = DateInterval.month(containing: .now)
    @State private var sharedReceiptText: String?

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
            .sheet(item: $activeSheet, onDismiss: { sharedReceiptText = nil }) { sheet in
                switch sheet {
                case .add: NavigationStack {
                    AddTransactionView(sharedReceiptText: sharedReceiptText).navigationTitle("add_transaction")
                }
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
        .onOpenURL(perform: handleSharedReceipt)
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
            for: Source.self, Transaction.self, Category.self, TransactionCollection.self,
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
    return container
}

#Preview {
    MainView()
        .modelContainer(makeMainViewPreviewContainer())
}
