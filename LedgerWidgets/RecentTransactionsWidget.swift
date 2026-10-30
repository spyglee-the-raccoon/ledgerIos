//
//  RecentTransactionsWidget.swift
//  LedgerWidgets
//

import SwiftUI
import WidgetKit

/// The three latest transactions, using the same cards as the transaction lists.
struct RecentTransactionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.recentTransactions, provider: SnapshotProvider()) { entry in
            RecentTransactionsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetLink.sources)
        }
        .configurationDisplayName("transactions")
        .description("widget_transactions_description")
        .supportedFamilies([.systemMedium])
    }
}

struct RecentTransactionsWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            if snapshot.recentTransactions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("no_transactions")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.recentTransactions.enumerated()), id: \.offset) { index, transaction in
                        if index > 0 { Divider() }
                        TransactionCardContent(data: transaction, currencyCode: snapshot.currencyCode, showsDate: true)
                            .lineLimit(1)
                            .frame(maxHeight: .infinity)
                    }
                }
                // Shrinks the cards a little so three fit with a note line each.
                .dynamicTypeSize(...DynamicTypeSize.medium)
                .font(.subheadline)
            }
        } else {
            OpenAppPlaceholder()
        }
    }
}

#Preview(as: .systemMedium) {
    RecentTransactionsWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}
