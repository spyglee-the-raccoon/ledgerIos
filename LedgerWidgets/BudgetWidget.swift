//
//  BudgetWidget.swift
//  LedgerWidgets
//

import SwiftUI
import WidgetKit

/// The general monthly limit, or the first active category budget when it's off.
struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.budget, provider: SnapshotProvider()) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetLink.budgeting)
        }
        .configurationDisplayName("budgeting")
        .description("widget_budget_description")
        .supportedFamilies([.systemMedium])
    }
}

struct BudgetWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            if let budget = snapshot.budget {
                BudgetCardContent(data: budget, currencyCode: snapshot.currencyCode)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("widget_no_budget")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            OpenAppPlaceholder()
        }
    }
}

#Preview(as: .systemMedium) {
    BudgetWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: nil)
}
