//
//  PriceComparisonView.swift
//  Ledger
//
//  Created by Maksym Bahrov on 28.10.2026..
//

import SwiftUI
import SwiftData
import Charts

struct PricePoint: Identifiable {
    let id: PersistentIdentifier
    let date: Date
    let unitPrice: Decimal
    let store: String
}

struct PriceHistory: Identifiable {
    static let minimumPurchases = 11
    private static let sampleSize = 3

    let id: String
    let name: String
    let points: [PricePoint]

    var startPrice: Decimal { average(points.prefix(Self.sampleSize)) }
    var currentPrice: Decimal { average(points.suffix(Self.sampleSize)) }

    var change: Double {
        guard startPrice > 0 else { return 0 }
        return NSDecimalNumber(decimal: (currentPrice - startPrice) / startPrice).doubleValue
    }

    private func average(_ slice: ArraySlice<PricePoint>) -> Decimal {
        guard !slice.isEmpty else { return 0 }
        return slice.reduce(0) { $0 + $1.unitPrice } / Decimal(slice.count)
    }

    static func histories(from items: [ReceiptItem]) -> [PriceHistory] {
        Dictionary(grouping: items, by: \.normalizedName)
            .compactMap { key, items -> PriceHistory? in
                let dated = items
                    .compactMap { item -> (ReceiptItem, Date)? in
                        guard let date = item.transaction?.date, item.unitPrice > 0 else { return nil }
                        return (item, date)
                    }
                    .sorted { $0.1 < $1.1 }
                guard dated.count >= minimumPurchases, let latest = dated.last else { return nil }
                return PriceHistory(
                    id: key,
                    name: latest.0.name,
                    points: dated.map { item, date in
                        PricePoint(id: item.persistentModelID, date: date, unitPrice: item.unitPrice, store: item.transaction?.note ?? "")
                    }
                )
            }
            .sorted { abs($0.change) > abs($1.change) }
    }
}

struct PriceComparisonView: View {
    @Query private var items: [ReceiptItem]

    private var histories: [PriceHistory] { PriceHistory.histories(from: items) }

    var body: some View {
        let histories = histories
        List {
            if !histories.isEmpty {
                Section {
                    PersonalInflationView(histories: histories)
                }
                Section("tracked_items") {
                    ForEach(histories) { history in
                        NavigationLink(destination: PriceHistoryView(history: history)) {
                            PriceHistoryRowView(history: history)
                        }
                    }
                }
            }
        }
        .overlay {
            if histories.isEmpty {
                ContentUnavailableView(
                    "no_price_history",
                    systemImage: "cart",
                    description: Text("no_price_history_description")
                )
            }
        }
        .navigationTitle("price_comparison")
    }
}

/// Average price change across all tracked products.
private struct PersonalInflationView: View {
    let histories: [PriceHistory]

    private var average: Double {
        histories.map(\.change).reduce(0, +) / Double(histories.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("personal_inflation")
                .font(.headline)
            Text(average, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                .font(.largeTitle.bold())
                .foregroundStyle(changeColor(average))
            Text("personal_inflation_description \(histories.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct PriceHistoryRowView: View {
    let history: PriceHistory

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(history.name)
                Text("purchases_since \(history.points.count) \(history.points[0].date.formatted(.dateTime.month().year()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(history.change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                    .font(.default.bold())
                    .foregroundStyle(changeColor(history.change))
                Text(verbatim: "\(history.startPrice.formatted(.currency(code: currency))) → \(history.currentPrice.formatted(.currency(code: currency)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PriceHistoryView: View {
    let history: PriceHistory

    var body: some View {
        List {
            Section {
                Chart(history.points) { point in
                    LineMark(
                        x: .value("date", point.date),
                        y: .value("price", point.unitPrice)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("date", point.date),
                        y: .value("price", point.unitPrice)
                    )
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
                .padding(.vertical)
            } footer: {
                Text("price_history_description")
            }

            Section("purchases") {
                ForEach(history.points.reversed()) { point in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(point.date, format: .dateTime.day().month().year())
                            if !point.store.isEmpty {
                                Text(point.store)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(point.unitPrice, format: .currency(code: currency))
                    }
                }
            }
        }
        .navigationTitle(history.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Rising prices are bad for the user, so they're red; falling prices are green.
private func changeColor(_ change: Double) -> Color {
    if change > 0.005 { return .red }
    if change < -0.005 { return .green }
    return .secondary
}

#Preview {
    NavigationStack {
        PriceComparisonView()
    }
    .modelContainer(makeMainViewPreviewContainer())
}
