//
//  AddSouceView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 18.09.2026..
//

import SwiftUI

struct AddSourceView: View {
    @Environment(\.dismiss) private var dismiss
    let source: Source?
    let onSave: (SourceDraft) -> Void
    @State private var draft: SourceDraft
    @State private var symbolSearch = ""
    
    init(source: Source? = nil, onSave: @escaping (SourceDraft) -> Void) {
        self.source = source
        self.onSave = onSave
        self.draft = source.map { SourceDraft($0) } ?? SourceDraft()
    }
    
    private var isEditing: Bool {
        source != nil
    }
    
    private var navigationTitleKey: LocalizedStringKey {
        isEditing ? "Edit Source" : "Add Source"
    }
    
    private var confirmationTitleKey: LocalizedStringKey {
        isEditing ? "Save" : "Add"
    }
    
    private var filteredSymbols: [String] {
        let query = symbolSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return icons }
        return icons.filter { $0.contains(query) }
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
                Section("Name") {
                    HStack(spacing: 12) {
                        Image(systemName: draft.systemImage)
                            .font(.title3)
                            .foregroundStyle(draft.color.color)
                            .frame(width: 28)
                        TextField("Source name", text: $draft.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                    }
                }
                
                Section("Initial value") {
                    HStack(spacing: 12) {
                        TextField("Initial value", value: $draft.initValue, format: .number)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 12) {
                        ForEach(CategoryColor.allCases) { swatchColor in
                            ColorSwatchView(onSelectColor: onSelectColor, color: swatchColor, selectedColor: draft.color)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Icon") {
                    TextField("Search symbols", text: $symbolSearch)
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
                        onSave(draft)
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .disabled(draft.trimmedName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddSourceView { _ in }
}
