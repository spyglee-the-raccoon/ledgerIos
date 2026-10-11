//
//  MainChartView.swift
//  ledger
//
//  Created by Maksym Bahrov on 28.09.2026..
//

import SwiftUI
import SwiftData
import Charts
import AudioToolbox

private enum SliceID: Hashable {
    case category(PersistentIdentifier)
    case uncategorized
}

private struct CategorySum {
    var id: SliceID
    var name: String
    var amount: Decimal
    var color: CategoryColor
    var systemImage: String
}

struct MainChartView: View {
    @Query private var expenses: [Transaction]
    @Query private var incomes: [Transaction]
    @Query private var categories: [Category]
    
    @State private var selectedID: SliceID?

    private let innerRadiusRatio: CGFloat = 0.618
    private let month: DateInterval

    init(month: DateInterval = .month(containing: .now)) {
        self.month = month
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
            CategorySum(id: .category(category.persistentModelID), name: category.name, amount: 0, color: category.color, systemImage: category.systemImage)
        }
        var uncategorized = CategorySum(id: .uncategorized, name: String(localized: "uncategorized"), amount: 0, color: .gray, systemImage: "questionmark")
        for expense in expenses {
            if let category = expense.category,
               let index = categories.firstIndex(where: { $0.persistentModelID == category.persistentModelID }) {
                spendCategories[index].amount += expense.amount
            } else {
                uncategorized.amount += expense.amount
            }
        }
        if uncategorized.amount > 0 {
            spendCategories.append(uncategorized)
        }
        return spendCategories
    }

    private func slice(at value: Double, in slices: [CategorySum]) -> CategorySum? {
        var cumulative: Double = 0
        for sum in slices {
            cumulative += NSDecimalNumber(decimal: sum.amount).doubleValue
            if value <= cumulative {
                return sum
            }
        }
        return nil
    }

    var body: some View {
        let slices = expensesByCategories
        let selected = slices.first { $0.id == selectedID }

        Chart(slices, id: \.id) { expense in
            SectorMark(
                angle: .value(expense.name, expense.amount),
                innerRadius: .ratio(innerRadiusRatio),
                outerRadius: selected?.id == expense.id ? .ratio(1.0) : .ratio(0.92),
                angularInset: 1
            )
                .cornerRadius(5)
                .foregroundStyle(expense.color.color)
                .opacity(selected == nil || selected?.id == expense.id ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(.rect)
                    .gesture(
                        SpatialTapGesture().onEnded { tap in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let frame = geo[plotFrame]
                            let dx = tap.location.x - frame.midX
                            let dy = tap.location.y - frame.midY
                            let radius = min(frame.width, frame.height) / 2
                            let distance = hypot(dx, dy)

                            guard distance >= radius * innerRadiusRatio,
                                  distance <= radius else {
                                return selectedID = nil
                            }

                            var angle = atan2(dx, -dy)
                            if angle < 0 { angle += 2 * .pi }

                            let total = slices.reduce(0.0) {
                                $0 + NSDecimalNumber(decimal: $1.amount).doubleValue
                            }
                            guard total > 0 else { return }
                            let value = angle / (2 * .pi) * total
                            let hitID = slice(at: value, in: slices)?.id
                            selectedID = (hitID == selectedID) ? nil : hitID
                        }
                    )
            }
        }
        .onChange(of: selectedID) {
            AudioServicesPlaySystemSound(1104)
        }
        .sensoryFeedback(.selection, trigger: selectedID)
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let plotFrame = chartProxy.plotFrame {
                    let frame = geometry[plotFrame]
                    if let selected {
                        let innerDiameter = min(frame.width, frame.height) * innerRadiusRatio
                        ZStack {
                            Image(systemName: selected.systemImage)
                                .resizable()
                                .scaledToFit()
                                .padding(innerDiameter * 0.2)
                                .foregroundStyle(selected.color.color.opacity(0.2))
                                .frame(width: innerDiameter, height: innerDiameter)
                                .background(selected.color.color.opacity(0.1))
                                .clipShape(.circle)
                            VStack {
                                Text(selected.name)
                                    .font(.title2.bold())
                                    .foregroundColor(selected.color.color)
                                
                                Text(selected.amount, format: .currency(code: currency))
                                    .font(.title.bold())
                                    .foregroundColor(.primary)
                            }
                        }
                        .position(x: frame.midX, y: frame.midY)
                    } else {
                        VStack {
                            Group {
                                if month.contains(.now) {
                                    Text("this_month_balance")
                                } else {
                                    Text(month.start, format: .dateTime.month(.wide).year())
                                }
                            }
                                .textCase(.uppercase)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(currentMonthBalance, format: .currency(code: currency))
                                .font(.title.bold())
                                .foregroundColor(.primary)
                        }.position(x: frame.midX, y: frame.midY)
                    }
                }
            }
        }
            .animation(.snappy, value: selected?.id)
            .padding()
    }
}

#Preview {
    MainChartView().modelContainer(makeMainViewPreviewContainer())
}
