//
//  MainChartView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 28.09.2026..
//

import SwiftUI
import SwiftData
import Charts

private struct CategorySum {
    var name: String
    var amount: Decimal
    var color: CategoryColor
    var systemImage: String
}

struct MainChartView: View {
    @Query private var expenses: [Transaction]
    @Query private var incomes: [Transaction]
    @Query private var categories: [Category]
    
    @State private var rawSelection: Double?
    @State private var selected: CategorySum?

    private let innerRadiusRatio: CGFloat = 0.618

    init(month: DateInterval = .month(containing: .now)) {
        let expense = TransactionKind.expense
        let income = TransactionKind.income
        let start = month.start
        let end = month.end

        _expenses = Query(filter: #Predicate<Transaction> {
            $0.kind == expense && $0.date >= start && $0.date < end
        })
        _incomes = Query(filter: #Predicate<Transaction> {
            $0.kind == income && $0.date >= start && $0.date < end
        })
    }
    
    private var currentMonthBalance: Decimal {
        let currentMonthIncomes: Decimal = incomes.reduce(0) { $0 + $1.amount }
        let currentMonthExpenses: Decimal = expenses.reduce(0) { $0 + $1.amount }
        
        return currentMonthIncomes - currentMonthExpenses
    }
    
    private var expensesByCategories: [CategorySum] {
        var spendCategories = categories.map { category in
            CategorySum(name: category.name, amount: 0, color: category.color, systemImage: category.systemImage)
        }
        for expense in expenses {
            guard let category = expense.category,
                  let index = categories.firstIndex(where: { $0.persistentModelID == category.persistentModelID })
            else { continue }
            spendCategories[index].amount += expense.amount
        }
        return spendCategories
    }

    private func category(at value: Double) -> CategorySum? {
        var cumulative: Double = 0
        for sum in expensesByCategories {
            cumulative += NSDecimalNumber(decimal: sum.amount).doubleValue
            if value <= cumulative {
                return sum
            }
        }
        return nil
    }

    var body: some View {
        Chart(expensesByCategories, id: \.name) { expense in
            SectorMark(
                angle: .value(expense.name, expense.amount),
                innerRadius: .ratio(innerRadiusRatio),
                outerRadius: selected?.name == expense.name ? .ratio(1.0) : .ratio(0.92),
                angularInset: 1
            )
                .cornerRadius(5)
                .foregroundStyle(expense.color.color)
                .opacity(selected == nil || selected?.name == expense.name ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $rawSelection)
        .onChange(of: rawSelection) { _, newValue in
            guard let newValue else { return }
            let hit = category(at: newValue)
            selected = (hit?.name == selected?.name) ? nil : hit
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let plotFrame = chartProxy.plotFrame {
                    let frame = geometry[plotFrame]
                    if selected?.name == nil {
                        VStack {
                            Text("This month balance".uppercased())
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(currentMonthBalance, format: .currency(code: currency))
                                .font(.title.bold())
                                .foregroundColor(.primary)
                        }.position(x: frame.midX, y: frame.midY)
                    } else {
                        let innerDiameter = min(frame.width, frame.height) * innerRadiusRatio
                        ZStack {
                            Image(systemName: selected!.systemImage)
                                .resizable()
                                .scaledToFit()
                                .padding(innerDiameter * 0.2)
                                .foregroundStyle(selected!.color.color.opacity(0.2))
                                .frame(width: innerDiameter, height: innerDiameter)
                                .background(selected!.color.color.opacity(0.1))
                                .clipShape(.circle)
                            VStack {
                                Text(selected!.name)
                                    .font(.title2.bold())
                                    .foregroundColor(selected?.color.color)
                                
                                Text(selected!.amount, format: .currency(code: currency))
                                    .font(.title.bold())
                                    .foregroundColor(.primary)
                            }
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
        }
            .animation(.snappy, value: selected?.name)
            .padding()
    }
}

#Preview {
    MainChartView().modelContainer(makeMainViewPreviewContainer())
}
