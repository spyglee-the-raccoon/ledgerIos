//
//  ActionView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 02.10.2026..
//

import SwiftUI
import SwiftData

struct ActionView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Query private var expenses: [Transaction]
    @Query private var incomes: [Transaction]
    @Query private var sources: [Source]
    
    var currentMonth: DateInterval
    
    @Binding var activeSheet: MainViewActiveSheet?
    
    var isHorizontal: Bool {
        sizeClass == .regular
    }

    init(month: DateInterval, activeSheet: Binding<MainViewActiveSheet?>) {
        self.currentMonth = month
        self._activeSheet = activeSheet
        
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
    
    func onToggleExpensesSheet() {
        activeSheet = .expenses
    }
    
    func onToggleIncomesSheet() {
        activeSheet = .incomes
    }
    
    var body: some View {
        if isHorizontal {
            VStack {
                Spacer()
                Text("total_balance")
                    .textCase(.uppercase)
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                NavigationLink(destination: SourcesCompoundView()) {
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
                Spacer()
            }
            .background(Color.gray.opacity(0.3))
        } else {
            VStack {
                Text("total_balance")
                    .textCase(.uppercase)
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                NavigationLink(destination: SourcesCompoundView()) {
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
            }
            .padding(.vertical)
            .background(Color.gray.opacity(0.3))
        }
    }
}

#Preview {
    ActionView(month: DateInterval.month(containing: .now), activeSheet: .constant(nil))
}
