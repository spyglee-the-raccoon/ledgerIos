//
//  PlannedTransactionsView.swift
//  Ledger
//
//  Created by Maksym Bahrov on 16.10.2026..
//

import SwiftUI
import SwiftData

struct PlannedTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannedTransaction.startDate) private var plannedTransactions: [PlannedTransaction]

    var body: some View {
        List {
            ForEach(plannedTransactions) { planned in
                PlannedTransactionRowView(planned: planned)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(planned)
                            PlannedTransactionNotifier.reschedule(in: modelContext)
                        } label: {
                            Label("delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            togglePause(planned)
                        } label: {
                            if planned.isPaused {
                                Label("resume", systemImage: "play")
                            } else {
                                Label("pause", systemImage: "pause")
                            }
                        }
                        .tint(planned.isPaused ? .green : .orange)
                    }
            }
        }
        .overlay {
            if plannedTransactions.isEmpty {
                ContentUnavailableView("no_planned_transactions", systemImage: "calendar.badge.clock")
            }
        }
        .navigationTitle("planned_transactions")
        .toolbar {
            NavigationLink(destination: AddPlannedTransactionView()) {
                Image(systemName: "plus")
            }
        }
    }

    private func togglePause(_ planned: PlannedTransaction) {
        planned.isPaused.toggle()

        if !planned.isPaused {
            try? RecurrenceEngine.generateDue(in: modelContext)
        } else {
            PlannedTransactionNotifier.reschedule(in: modelContext)
        }
    }
}

private struct PlannedTransactionRowView: View {
    let planned: PlannedTransaction

    private var amountColor: Color {
        switch planned.kind {
        case .expense: .red
        case .income: .green
        case .transfer: .primary
        }
    }

    private var upcomingDate: Date? {
        guard let next = planned.nextDueDate else { return nil }
        if let end = planned.endDate, next > end { return nil }
        return next
    }

    var body: some View {
        NavigationLink(destination: AddPlannedTransactionView(plannedTransaction: planned)) {
            HStack {
                icon
                VStack(alignment: .leading) {
                    title
                    schedule
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)
                Spacer()
                Text(planned.amount, format: .currency(code: currency))
                    .font(.default.bold())
                    .foregroundStyle(amountColor)
            }
            .opacity(planned.isPaused ? 0.5 : 1)
        }
    }

    @ViewBuilder
    private var icon: some View {
        if planned.kind == .transfer {
            CategoryImageView(systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90", color: .gray)
        } else if let category = planned.category {
            CategoryImageView(systemImage: category.systemImage, color: category.color)
        } else {
            CategoryImageView(systemImage: "questionmark", color: .gray)
        }
    }

    @ViewBuilder
    private var title: some View {
        if !planned.note.isEmpty {
            Text(planned.note)
        } else if planned.kind == .transfer {
            Text("transfer")
        } else if let category = planned.category {
            Text(category.name)
        } else {
            Text("uncategorized")
        }
    }

    @ViewBuilder
    private var schedule: some View {
        HStack(spacing: 4) {
            Text(planned.frequency.scheduleDescription(interval: planned.interval))
            Text(verbatim: "·")
            if planned.isPaused {
                Text("paused")
            } else if let upcomingDate {
                Text(upcomingDate, format: .dateTime.day().month().year())
            } else {
                Text("ended")
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlannedTransactionsView()
    }
    .modelContainer(makeMainViewPreviewContainer())
}
