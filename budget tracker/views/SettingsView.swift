//
//  SettingsView.swift
//  budget tracker
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
            }
            Section("statistics") {
                NavigationLink(destination: IncomeExpenseStatisticView()) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(.green)
                    Text("income_expense")
                }
                NavigationLink(destination: SavingStatisticView()) {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(.orange)
                    Text("savings")
                }
            }
        }
        .navigationTitle("settings")
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
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { isReminderOn },
            set: { newValue in
                Task {
                    if newValue {
                        isReminderOn = await DailyReminder.enable()
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
    SettingsView().modelContainer(makeMainViewPreviewContainer())
}
