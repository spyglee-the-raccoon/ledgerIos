//
//  IncomeExpenseStatisticView.swift
//  ledger
//
//  Created by Maksym Bahrov on 01.10.2026..
//

import SwiftUI
import SwiftData
import Charts

struct InExByMonth {
    let month: Date
    var incomes: Decimal
    var expenses: Decimal
}

struct IncomeExpenseStatisticView: View {
    @Query var transactions: [Transaction]
    
    private let incomesLabel = String(localized: "incomes")
    private let expensesLabel = String(localized: "expenses")
    
    private let visibleMonths = 6

    @State private var selectedDate: Date?

    private func selectedEntry(in data: [InExByMonth]) -> InExByMonth? {
        guard let selectedDate,
              let month = Calendar.current.dateInterval(of: .month, for: selectedDate)?.start else { return nil }
        return data.first { $0.month == month }
    }

    var incomesExpensesByMonth: [InExByMonth] {
        let calendar = Calendar.current
        var byMonth: [Date: InExByMonth] = [:]

        for transaction in transactions {
            guard transaction.kind != .transfer,
                  let month = calendar.dateInterval(of: .month, for: transaction.date)?.start else { continue }

            var entry = byMonth[month] ?? InExByMonth(month: month, incomes: 0, expenses: 0)
            if transaction.kind == .expense {
                entry.expenses += transaction.amount
            } else {
                entry.incomes += transaction.amount
            }
            byMonth[month] = entry
        }

        guard let first = byMonth.keys.min(), let last = byMonth.keys.max() else { return [] }
        var result: [InExByMonth] = []
        var month = first
        while month <= last {
            result.append(byMonth[month] ?? InExByMonth(month: month, incomes: 0, expenses: 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                chart
                explanation
            }
        }
        .navigationTitle("income_expense")
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("income_expense_about_title")
                .font(.headline)
            Text("income_expense_about_chart")
            Text("income_expense_about_importance")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.bottom)
    }

    @ViewBuilder
    private var chart: some View {
        let data = incomesExpensesByMonth
        let selected = selectedEntry(in: data)

        Chart {
            ForEach(data, id: \.month) { entry in
                LineMark(
                    x: .value("month", entry.month, unit: .month),
                    y: .value("amount", entry.incomes)
                )
                .foregroundStyle(by: .value("kind", incomesLabel))
                .symbol(by: .value("kind", incomesLabel))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("month", entry.month, unit: .month),
                    y: .value("amount", entry.expenses)
                )
                .foregroundStyle(by: .value("kind", expensesLabel))
                .symbol(by: .value("kind", expensesLabel))
                .interpolationMethod(.catmullRom)
            }

            if let selected {
                RuleMark(x: .value("month", selected.month, unit: .month))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(
                        position: .top,
                        spacing: 0,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        selectionPopover(for: selected)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    proxy.selectXValue(at: value.location.x)
                }
        }
        .chartForegroundStyleScale([
            incomesLabel: Color.green,
            expensesLabel: Color.red
        ])
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 3600 * 24 * 31 * visibleMonths)
        .chartScrollPosition(initialX: data.last?.month ?? .now)
        .chartLegend(position: .top)
        .frame(height: 300)
        .padding()
    }

    private func selectionPopover(for entry: InExByMonth) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.month, format: .dateTime.month(.wide).year())
                .font(.caption.bold())
            Label {
                Text(entry.incomes, format: .currency(code: currency))
            } icon: {
                Circle().fill(Color.green).frame(width: 8, height: 8)
            }
            Label {
                Text(entry.expenses, format: .currency(code: currency))
            } icon: {
                Circle().fill(Color.red).frame(width: 8, height: 8)
            }
        }
        .font(.caption)
        .padding(8)
        .background(.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

@MainActor
func makeStatisticPreviewContainer() -> ModelContainer {
    let container: ModelContainer
    do {
        container = try ModelContainer(
            for: Source.self, Transaction.self, Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
    let calendar = Calendar.current
    let incomes: [Decimal] = [1800, 1800, 2100, 1800, 1950, 1800, 0, 1800, 2400, 1800, 1800, 2000, 1900]
    let expenses: [Decimal] = [1200, 1650, 2300, 1400, 1500, 1350, 0, 1700, 1600, 2100, 1450, 1550, 900]
    for offset in 0..<incomes.count {
        guard let date = calendar.date(byAdding: .month, value: -offset, to: .now) else { continue }
        if incomes[offset] > 0 {
            container.mainContext.insert(Transaction(amount: incomes[offset], kind: .income, note: "", date: date))
        }
        if expenses[offset] > 0 {
            container.mainContext.insert(Transaction(amount: expenses[offset], kind: .expense, note: "", date: date))
        }
    }
    return container
}

#Preview {
    NavigationStack {
        IncomeExpenseStatisticView()
    }
    .modelContainer(makeStatisticPreviewContainer())
}
