//
//  MonthChartWidget.swift
//  LedgerWidgets
//

import Charts
import SwiftUI
import WidgetKit

/// This month's spending by category around the month balance, like the main screen chart.
struct MonthChartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.monthChart, provider: SnapshotProvider()) { entry in
            MonthChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetLink.main)
        }
        .configurationDisplayName("this_month_balance")
        .description("widget_chart_description")
        .supportedFamilies([.systemSmall])
    }
}

struct MonthChartWidgetView: View {
    let entry: SnapshotEntry

    private let innerRadiusRatio: CGFloat = 0.618

    var body: some View {
        if let snapshot = entry.snapshot {
            chart(snapshot.slices)
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        if let plotFrame = proxy.plotFrame {
                            let frame = geometry[plotFrame]
                            // Keep the text inside the hole of the ring.
                            let innerDiameter = min(frame.width, frame.height) * innerRadiusRatio
                            VStack(spacing: 2) {
                                Text("this_month_balance")
                                    .textCase(.uppercase)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(snapshot.monthBalance, format: .currency(code: snapshot.currencyCode).precision(.fractionLength(0)))
                                    .font(.headline.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .frame(width: innerDiameter * 0.68)
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
        } else {
            OpenAppPlaceholder()
        }
    }

    /// Without expenses the ring is drawn as one gray slice so the widget keeps its shape.
    @ViewBuilder
    private func chart(_ slices: [WidgetSnapshot.ChartSlice]) -> some View {
        if slices.isEmpty {
            Chart {
                SectorMark(angle: .value("", 1), innerRadius: .ratio(innerRadiusRatio), outerRadius: .ratio(0.92))
                    .foregroundStyle(.gray.opacity(0.3))
            }
        } else {
            Chart(Array(slices.enumerated()), id: \.offset) { _, slice in
                SectorMark(
                    angle: .value(slice.name, slice.amount),
                    innerRadius: .ratio(innerRadiusRatio),
                    outerRadius: .ratio(0.92),
                    angularInset: 1
                )
                .cornerRadius(5)
                .foregroundStyle(slice.color.color)
            }
            .chartLegend(.hidden)
        }
    }
}

#Preview(as: .systemSmall) {
    MonthChartWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot.sample.current(at: .now.addingTimeInterval(40 * 86_400)))
}
