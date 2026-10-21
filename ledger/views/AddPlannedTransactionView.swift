//
//  AddPlannedTransactionView.swift
//  Ledger
//
//  Created by Maksym Bahrov on 16.10.2026..
//

import SwiftUI
import SwiftData

struct AddPlannedTransactionView: View {
    var plannedTransaction: PlannedTransaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PlannedTransactionDraft

    @Query var categories: [Category]
    @Query var sources: [Source]

    init(plannedTransaction: PlannedTransaction? = nil, selectedKind: TransactionKind = .expense) {
        self.plannedTransaction = plannedTransaction
        var draft: PlannedTransactionDraft
        if let plannedTransaction {
            draft = PlannedTransactionDraft(plannedTransaction)
        } else {
            draft = PlannedTransactionDraft()
            draft.kind = selectedKind
        }
        _draft = State(initialValue: draft)
    }

    var isEditing: Bool {
        plannedTransaction != nil
    }

    private var availableCategories: [Category] {
        let kind: CategoryKind = draft.kind == .income ? .income : .expense
        return categories.filter { $0.categoryKind == kind }
    }

    private var hasEndDate: Binding<Bool> {
        Binding(
            get: { draft.endDate != nil },
            set: { enabled in
                draft.endDate = enabled ? Calendar.current.date(byAdding: .year, value: 1, to: draft.startDate) : nil
            }
        )
    }

    private var endDate: Binding<Date> {
        Binding(
            get: { draft.endDate ?? draft.startDate },
            set: { draft.endDate = $0 }
        )
    }

    private var isValid: Bool {
        guard draft.amount > 0, draft.interval > 0 else { return false }
        if let end = draft.endDate, end < draft.startDate { return false }
        switch draft.kind {
        case .expense:
            return draft.category != nil && draft.source != nil
        case .income:
            return draft.category != nil && draft.destination != nil
        case .transfer:
            return draft.source != nil && draft.destination != nil
        }
    }

    private func getTransactionKindName(_ kind: TransactionKind) -> LocalizedStringResource {
        switch kind {
        case .expense:
            return "expense"
        case .income:
            return "income"
        case .transfer:
            return "transfer"
        }
    }

    private func onKindChange() {
        if draft.kind == .income { draft.source = nil }
        if draft.kind == .expense { draft.destination = nil }
        if draft.kind == .transfer { draft.category = nil }
        if let category = draft.category, !availableCategories.contains(category) {
            draft.category = nil
        }
    }

    private func save() {
        if let plannedTransaction {
            draft.apply(to: plannedTransaction)
        } else {
            let newPlanned = PlannedTransaction(
                amount: draft.amount,
                kind: draft.kind,
                source: draft.source,
                destination: draft.destination,
                note: draft.note,
                category: draft.category,
                frequency: draft.frequency,
                interval: draft.interval,
                startDate: draft.startDate,
                endDate: draft.endDate,
                occurrencesGenerated: 0,
                isPaused: draft.isPaused
            )
            modelContext.insert(newPlanned)
        }
        try? RecurrenceEngine.generateDue(in: modelContext)
        Task {
            await PlannedTransactionNotifier.requestAuthorization()
            PlannedTransactionNotifier.reschedule(in: modelContext)
        }
        dismiss()
    }

    var body: some View {
        Form {
            Picker("kind", selection: $draft.kind) {
                ForEach(TransactionKind.allCases) { kind in
                    Text(getTransactionKindName(kind))
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)

            Section("amount") {
                TextField("amount", value: $draft.amount, format: .number)
                    .keyboardType(.decimalPad)
            }

            if draft.kind != .income {
                Section {
                    Picker("source", selection: $draft.source) {
                        Text("none").tag(Source?.none)
                        ForEach(sources) { source in
                            HStack {
                                Image(systemName: source.systemImage)
                                Text(source.name)
                            }
                            .tag(Optional(source))
                        }
                    }
                }
            }

            if draft.kind != .expense {
                Section {
                    Picker("destination", selection: $draft.destination) {
                        Text("none").tag(Source?.none)
                        ForEach(sources) { source in
                            HStack {
                                Image(systemName: source.systemImage)
                                Text(source.name)
                            }
                            .tag(Optional(source))
                        }
                    }
                }
            }

            if draft.kind != .transfer {
                Section {
                    Picker("category", selection: $draft.category) {
                        Text("none").tag(Category?.none)
                        ForEach(availableCategories) { category in
                            HStack {
                                Image(systemName: category.systemImage)
                                Text(category.name)
                            }
                            .tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("schedule") {
                Picker("frequency", selection: $draft.frequency) {
                    ForEach(RecurrenceFrequency.allCases) { frequency in
                        Text(frequency.displayName)
                            .tag(frequency)
                    }
                }
                Stepper(value: $draft.interval, in: 1...365) {
                    Text(draft.frequency.scheduleDescription(interval: draft.interval))
                }
                DatePicker("start_date", selection: $draft.startDate, displayedComponents: .date)
                Toggle("has_end_date", isOn: hasEndDate)
                if draft.endDate != nil {
                    DatePicker("end_date", selection: endDate, in: draft.startDate..., displayedComponents: .date)
                }
                if isEditing {
                    Toggle("paused", isOn: $draft.isPaused)
                }
            }

            Section("note") {
                TextField("note", text: $draft.note)
            }
        }
        .onChange(of: draft.kind, onKindChange)
        .navigationTitle(isEditing ? "edit_planned_transaction" : "add_planned_transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: save) {
                    Image(systemName: "arrow.down.circle")
                }
                .disabled(!isValid)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddPlannedTransactionView()
    }
    .modelContainer(makeMainViewPreviewContainer())
}
