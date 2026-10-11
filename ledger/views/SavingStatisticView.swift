//
//  SavingStatisticView.swift
//  ledger
//
//  Created by Maksym Bahrov on 03.10.2026..
//

import SwiftUI
import SwiftData
import Charts

struct SavingsByMonth {
    let month: Date
    let startBalance: Decimal
    let endBalance: Decimal

    var difference: Decimal { endBalance - startBalance }
    var base: Decimal { min(startBalance, endBalance) }
    var top: Decimal { max(startBalance, endBalance) }
}

struct SavingStatisticView: View {
    @Query var transactions: [Transaction]
    @Query private var sources: [Source]

    private let visibleMonths = 6

    @State private var selectedDate: Date?

    private func selectedEntry(in data: [SavingsByMonth]) -> SavingsByMonth? {
        guard let selectedDate,
              let month = Calendar.current.dateInterval(of: .month, for: selectedDate)?.start else { return nil }
        return data.first { $0.month == month }
    }

    var savingsByMonth: [SavingsByMonth] {
        let calendar = Calendar.current
        var netByMonth: [Date: Decimal] = [:]

        for transaction in transactions {
            guard transaction.kind != .transfer,
                  let month = calendar.dateInterval(of: .month, for: transaction.date)?.start else { continue }
            let signed = transaction.kind == .expense ? -transaction.amount : transaction.amount
            netByMonth[month, default: 0] += signed
        }

        guard let first = netByMonth.keys.min(), let last = netByMonth.keys.max() else { return [] }

        var balance: Decimal = sources.reduce(0) { $0 + $1.initValue }
        var result: [SavingsByMonth] = []
        var month = first
        while month <= last {
            let end = balance + (netByMonth[month] ?? 0)
            result.append(SavingsByMonth(month: month, startBalance: balance, endBalance: end))
            balance = end
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    private func differenceColor(_ difference: Decimal) -> Color {
        if difference > 0 { return .green }
        if difference < 0 { return .red }
        return .secondary
    }

    private func differenceLabel(_ difference: Decimal) -> some View {
        let style: Decimal.FormatStyle = .number
            .notation(.compactName)
            .sign(strategy: .always(includingZero: false))
        return Text(difference, format: style)
            .font(.caption2.bold())
            .foregroundStyle(differenceColor(difference))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func biggest(_ kind: TransactionKind, in month: Date) -> [Transaction] {
        let calendar = Calendar.current
        return transactions
            .filter { $0.kind == kind && calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .sorted { $0.amount > $1.amount }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        let data = savingsByMonth
        let selected = selectedEntry(in: data)

        List {
            Section {
                chart(data: data, selected: selected)
            }

            if let selected {
                Section {
                    let expenses = biggest(.expense, in: selected.month)
                    if expenses.isEmpty {
                        Text("no_transactions")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(expenses) { transaction in
                        TransactionCardView(transaction: transaction)
                    }
                } header: {
                    Text("biggest_expenses \(selected.month.formatted(.dateTime.month(.wide).year()))")
                }

                Section {
                    let incomes = biggest(.income, in: selected.month)
                    if incomes.isEmpty {
                        Text("no_transactions")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(incomes) { transaction in
                        TransactionCardView(transaction: transaction)
                    }
                } header: {
                    Text("biggest_incomes \(selected.month.formatted(.dateTime.month(.wide).year()))")
                }
            }
        }
        .navigationTitle("savings")
    }

    private func chart(data: [SavingsByMonth], selected: SavingsByMonth?) -> some View {
        let maxTop = data.map(\.top).max() ?? 0
        let minBase = min(data.map(\.base).min() ?? 0, 0)
        let labelY = maxTop + max((maxTop - minBase) * 0.12, 1)

        return Chart {
            ForEach(data, id: \.month) { entry in
                let isDimmed = selected != nil && selected?.month != entry.month

                BarMark(
                    x: .value("month", entry.month, unit: .month),
                    yStart: .value("amount", 0),
                    yEnd: .value("amount", entry.base)
                )
                .foregroundStyle(Color.blue.opacity(isDimmed ? 0.2 : 0.5))

                BarMark(
                    x: .value("month", entry.month, unit: .month),
                    yStart: .value("amount", entry.base),
                    yEnd: .value("amount", entry.top)
                )
                .foregroundStyle(differenceColor(entry.difference).opacity(isDimmed ? 0.3 : 1))

                // Invisible bar up to the top of the chart, used to anchor the difference label in a row above all bars.
                BarMark(
                    x: .value("month", entry.month, unit: .month),
                    yStart: .value("amount", entry.top),
                    yEnd: .value("amount", labelY)
                )
                .foregroundStyle(.clear)
                .annotation(position: .overlay, alignment: .top) {
                    differenceLabel(entry.difference)
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
        .chartYScale(domain: minBase...labelY)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits), centered: true)
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
        .frame(height: 300)
        .padding(.vertical)
    }
}

#Preview {
    NavigationStack {
        SavingStatisticView()
    }.modelContainer(makeStatisticPreviewContainer())
}
