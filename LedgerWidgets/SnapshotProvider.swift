//
//  SnapshotProvider.swift
//  LedgerWidgets
//

import SwiftUI
import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    /// `nil` until the app has been opened once after installing the widget.
    let snapshot: WidgetSnapshot?
}

/// Reads the snapshot the app writes; the app reloads the timelines whenever it changes.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? .sample : (WidgetSnapshot.load() ?? .sample)
        completion(SnapshotEntry(date: .now, snapshot: snapshot.current(at: .now)))
    }

    /// Adds an entry at the start of next month, when this month's budget and chart reset.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date.now
        let snapshot = WidgetSnapshot.load()
        var entries = [SnapshotEntry(date: now, snapshot: snapshot?.current(at: now))]
        if let nextMonth = Calendar.current.dateInterval(of: .month, for: now)?.end {
            entries.append(SnapshotEntry(date: nextMonth, snapshot: snapshot?.current(at: nextMonth)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// Shown until the app has written its first snapshot.
struct OpenAppPlaceholder: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.pie")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("widget_open_app")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

extension WidgetSnapshot {
    /// Example data for the widget gallery and previews.
    static var sample: WidgetSnapshot {
        let now = Date.now
        let food = CategoryLabel(name: String(localized: "widget_sample_food"), systemImage: "basket", color: .green)
        let eatingOut = CategoryLabel(name: String(localized: "widget_sample_eating_out"), systemImage: "fork.knife", color: .orange)
        return WidgetSnapshot(
            month: Calendar.current.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0),
            currencyCode: Locale.current.currency?.identifier ?? "EUR",
            budget: BudgetCardData(category: nil, limit: 800, spent: 515, isActive: true),
            slices: [
                ChartSlice(name: food.name, amount: 240, color: food.color),
                ChartSlice(name: eatingOut.name, amount: 135, color: eatingOut.color),
                ChartSlice(name: "", amount: 90, color: .blue),
                ChartSlice(name: "", amount: 50, color: .purple),
            ],
            monthBalance: 1285,
            recentTransactions: [
                TransactionCardData(kind: .expense, amount: 23.4, date: now.addingTimeInterval(-3_600), note: "Konzum", category: food),
                TransactionCardData(kind: .expense, amount: 12, date: now.addingTimeInterval(-7_200), note: "", category: eatingOut),
                TransactionCardData(kind: .transfer, amount: 100, date: now.addingTimeInterval(-86_400), note: "", category: nil),
            ]
        )
    }
}
