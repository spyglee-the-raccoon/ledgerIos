//
//  TopCategoriesStatisticView.swift
//  ledger
//
//  Created by Maksym Bahrov on 11.10.2026..
//

import SwiftUI
import SwiftData
import Charts

struct CategorySpending: Hashable {
    let name: String
    let color: Color
    let month: Date
    let amount: Decimal
}

struct TopCategoriesStatisticView: View {
    @Query private var expenses: [Transaction]

    private let topCount = 3
    private let visibleMonths = 6

    @State private var selectedDate: Date?

    init() {
        let expense = TransactionKind.expense
        _expenses = Query(filter: #Predicate<Transaction> { $0.kind == expense })
    }

    /// The categories with the biggest all-time spending, biggest first.
    private var topCategories: [Category] {
        var totals: [PersistentIdentifier: (category: Category, amount: Decimal)] = [:]
        for expense in expenses {
            guard let category = expense.category else { continue }
            let id = category.persistentModelID
            totals[id, default: (category, 0)].amount += expense.amount
        }
        return totals.values
            .sorted { $0.amount > $1.amount }
            .prefix(topCount)
            .map(\.category)
    }

    /// Monthly spending for each top category, with zero-filled gaps between the first and last month.
    private func spendingByMonth(for categories: [Category]) -> [CategorySpending] {
        let calendar = Calendar.current
        let ids = categories.map(\.persistentModelID)
        var byMonth: [Date: [PersistentIdentifier: Decimal]] = [:]

        for expense in expenses {
            guard let id = expense.category?.persistentModelID, ids.contains(id),
                  let month = calendar.dateInterval(of: .month, for: expense.date)?.start else { continue }
            byMonth[month, default: [:]][id, default: 0] += expense.amount
        }

        guard let first = byMonth.keys.min(), let last = byMonth.keys.max() else { return [] }
        var result: [CategorySpending] = []
        var month = first
        while month <= last {
            for category in categories {
                let amount = byMonth[month]?[category.persistentModelID] ?? 0
                result.append(CategorySpending(name: category.name, color: category.color.color, month: month, amount: amount))
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    private func selectedMonth(in data: [CategorySpending]) -> Date? {
        guard let selectedDate,
              let month = Calendar.current.dateInterval(of: .month, for: selectedDate)?.start,
              data.contains(where: { $0.month == month }) else { return nil }
        return month
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                chart
                explanation
            }
        }
        .navigationTitle("top categories")
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("top_categories_about_title")
                .font(.headline)
            Text("top_categories_about_chart")
            Text("top_categories_about_importance")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.bottom)
    }

    @ViewBuilder
    private var chart: some View {
        let categories = topCategories
        let data = spendingByMonth(for: categories)
        let selected = selectedMonth(in: data)

        Chart {
            ForEach(data, id: \.self) { entry in
                LineMark(
                    x: .value("month", entry.month, unit: .month),
                    y: .value("amount", entry.amount)
                )
                .foregroundStyle(by: .value("category", entry.name))
                .symbol(by: .value("category", entry.name))
                .interpolationMethod(.catmullRom)
            }

            if let selected {
                RuleMark(x: .value("month", selected, unit: .month))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(
                        position: .top,
                        spacing: 0,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        selectionPopover(month: selected, entries: data.filter { $0.month == selected })
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
        .chartForegroundStyleScale(
            domain: categories.map(\.name),
            range: categories.map(\.color.color)
        )
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
            }
        }
        .chartYAxis {
            AxisMarks { _ in
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

    private func selectionPopover(month: Date, entries: [CategorySpending]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.caption.bold())
            ForEach(entries, id: \.name) { entry in
                Label {
                    Text(entry.amount, format: .currency(code: currency))
                } icon: {
                    Circle().fill(entry.color).frame(width: 8, height: 8)
                }
            }
        }
        .font(.caption)
        .padding(8)
        .background(.gray.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        TopCategoriesStatisticView()
    }
    .modelContainer(makeMainViewPreviewContainer())
}
