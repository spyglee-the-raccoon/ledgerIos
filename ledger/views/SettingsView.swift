//
//  SettingsView.swift
//  ledger
//
//  Created by Maksym Bahrov on 14.09.2026..
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum ActiveSheet: Identifiable {
    case categories, sources
    var id: Self { self }
}


struct SettingsView: View {
    @AppStorage(DailyReminder.storageKey) private var isReminderOn: Bool = false
    @AppStorage(AppLock.storageKey) private var isBiometricsRequired: Bool = false
    @Environment(\.modelContext) private var modelContext
    @State private var isImporterPresented = false
    @State private var importResult: CSVImportResult?
    @State private var importError: String?
    @State private var isExporterPresented = false
    @State private var exportFiles: [CSVFile] = []
    @State private var exportTransactionCount = 0
    @State private var exportedCount: Int?
    @State private var exportError: String?
    @State private var isPaywallPresented = false
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        List {
            Section {
                NavigationLink(destination: CategoriesView()) {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(.blue)
                    Text("categories")
                }
                NavigationLink(destination: SourcesView()) {
                    Image(systemName: "creditcard")
                        .foregroundStyle(.green)
                    Text("sources")
                }
                NavigationLink(destination: CollectionsView()) {
                    Image(systemName: "rectangle.3.group")
                        .foregroundStyle(.cyan)
                    Text("collections")
                }
                NavigationLink(destination: PlannedTransactionsView()) {
                    Image(systemName: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
                        .foregroundStyle(.yellow)
                    Text("planned_transactions")
                }
                NavigationLink(destination: BudgetingView()) {
                    Image(systemName: "bookmark")
                        .foregroundStyle(.purple)
                    Text("budgeting")
                }
                Toggle(isOn: reminderBinding) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.red)
                        Text("remind_me")
                    }
                }
                Toggle(isOn: biometricsBinding) {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundStyle(.indigo)
                        Text("lock_the_app")
                    }
                }
                Button {
                    isImporterPresented = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(.orange)
                        Text("import_csv")
                            .foregroundStyle(.primary)
                    }
                }
                Button(action: prepareExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.teal)
                        Text("export_csv")
                            .foregroundStyle(.primary)
                    }
                }
            }
            Section("statistics") {
                statisticLink("income_expense", systemImage: "arrow.up.arrow.down", color: .green) {
                    IncomeExpenseStatisticView()
                }
                statisticLink("savings", systemImage: "tray.and.arrow.down", color: .orange) {
                    SavingStatisticView()
                }
                statisticLink("top categories", systemImage: "chart.line.uptrend.xyaxis", color: .purple) {
                    TopCategoriesStatisticView()
                }
                statisticLink("price_comparison", systemImage: "cart", color: .teal) {
                    PriceComparisonView()
                }
            }
        }
        .navigationTitle("settings")
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: true
        ) { result in
            do {
                importResult = try CSVImporter.importFiles(result.get(), into: modelContext)
            } catch {
                modelContext.rollback()
                importError = error.localizedDescription
            }
        }
        .alert("import_finished", isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        ), presenting: importResult) { _ in
            Button("OK") {}
        } message: { result in
            Text("import_summary \(result.importedCount) \(result.createdSources) \(result.createdCategories) \(result.skippedCount)")
        }
        .alert("import_failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        ), presenting: importError) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
        .fileExporter(
            isPresented: $isExporterPresented,
            documents: exportFiles,
            contentType: .commaSeparatedText
        ) { result in
            switch result {
            case .success(let urls) where !urls.isEmpty:
                exportedCount = exportTransactionCount
            case .success:
                break
            case .failure(let error):
                exportError = error.localizedDescription
            }
        }
        .alert("export_finished", isPresented: Binding(
            get: { exportedCount != nil },
            set: { if !$0 { exportedCount = nil } }
        ), presenting: exportedCount) { _ in
            Button("OK") {}
        } message: { count in
            Text("export_summary \(count)")
        }
        .alert("export_failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        ), presenting: exportError) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private func statisticLink<Destination: View>(
        _ title: LocalizedStringKey,
        systemImage: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        if subscriptionManager.isSubscribed {
            NavigationLink(destination: destination()) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Text(title)
            }
        } else {
            Button {
                isPaywallPresented = true
            } label: {
                HStack {
                    Image(systemName: systemImage)
                        .foregroundStyle(color)
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func prepareExport() {
        do {
            let export = try CSVExporter.makeFiles(from: modelContext)
            guard !export.files.isEmpty else {
                exportError = String(localized: "export_nothing")
                return
            }
            exportFiles = export.files
            exportTransactionCount = export.count
            isExporterPresented = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { isReminderOn },
            set: { newValue in
                Task {
                    if newValue {
                        isReminderOn = await DailyReminder.enable(in: modelContext)
                    } else {
                        DailyReminder.disable()
                        isReminderOn = false
                    }
                }
            }
        )
    }

    private var biometricsBinding: Binding<Bool> {
        Binding(
            get: { isBiometricsRequired },
            set: { newValue in
                Task {
                    if await AppLock.authenticate() {
                        isBiometricsRequired = newValue
                    }
                }
            }
        )
    }
}


#Preview {
    SettingsView()
        .modelContainer(makeMainViewPreviewContainer())
        .environment(SubscriptionManager())
}
