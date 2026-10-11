//
//  AddSouceView.swift
//  ledger
//
//  Created by Maksym Bahrov on 18.09.2026..
//

import SwiftUI
import SwiftData

struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    let source: Source?
    let onSave: (SourceDraft) -> Void
    @State private var draft: SourceDraft
    @State private var symbolSearch = ""
    @State private var showSourceExistsAlert = false

    @Query var sources: [Source]
    
    init(source: Source? = nil, onSave: @escaping (SourceDraft) -> Void) {
        self.source = source
        self.onSave = onSave
        self.draft = source.map { SourceDraft($0) } ?? SourceDraft()
    }
    
    private var isEditing: Bool {
        source != nil
    }
    
    private var navigationTitleKey: LocalizedStringKey {
        isEditing ? "edit_source" : "add_source"
    }
    
    private var confirmationTitleKey: LocalizedStringKey {
        isEditing ? "save" : "add"
    }
    
    private var filteredSymbols: [String] {
        let query = symbolSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return icons }
        return icons.filter { $0.contains(query) }
    }
    
    private func validateAndSave() {
        let existingSource = sources.firstIndex(where: {
            $0.persistentModelID != source?.persistentModelID
                && $0.name == draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        })
        if existingSource != nil {
            showSourceExistsAlert = true
        } else {
            onSave(draft)
            dismiss()
        }
    }
    
    func onSelectColor (_ newColor: CategoryColor) {
        draft.color = newColor
    }
    
    func onSelectIcon (_ newIcon: String) {
        draft.systemImage = newIcon
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("name") {
                    HStack(spacing: 12) {
                        Image(systemName: draft.systemImage)
                            .font(.title3)
                            .foregroundStyle(draft.color.color)
                            .frame(width: 28)
                        TextField("source_name", text: $draft.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                    }
                }
                
                Section("initial_value") {
                    HStack(spacing: 12) {
                        Button {
                            draft.initValue = -draft.initValue
                        } label: {
                            Image(systemName: "plus.forwardslash.minus")
                                .font(.title3)
                                .foregroundStyle(draft.initValue < 0 ? .red : .accentColor)
                                .frame(width: 28)
                        }
                        .buttonStyle(.borderless)
                        TextField("initial_value", value: $draft.initValue, format: .number)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                    }
                }
                
                Section("color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 12) {
                        ForEach(CategoryColor.allCases) { swatchColor in
                            ColorSwatchView(onSelectColor: onSelectColor, color: swatchColor, selectedColor: draft.color)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("icon") {
                    TextField("search_symbols", text: $symbolSearch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if filteredSymbols.isEmpty {
                        ContentUnavailableView.search(text: symbolSearch)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                            ForEach(filteredSymbols, id: \.self) { symbol in
                                SymbolButtonView(onSelectIcon: onSelectIcon, symbol: symbol, selected: draft.systemImage)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        validateAndSave()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .disabled(draft.trimmedName.isEmpty)
                }
            }
            .alert("error", isPresented: $showSourceExistsAlert) {
            } message: {
                Text("source_exists")
            }
        }
    }
}

#Preview {
    AddSourceView { _ in }
}
