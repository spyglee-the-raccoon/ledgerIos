//
//  AddCategoryView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 18.09.2026..
//

import SwiftUI

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category?
    let onSave: (CategoryDraft) -> Void
    
    @State private var draft: CategoryDraft
    @State private var symbolSearch = ""

    init(category: Category? = nil, onSave: @escaping (CategoryDraft) -> Void) {
        self.category = category
        self.onSave = onSave
        self.draft = category.map { CategoryDraft($0) } ?? CategoryDraft()
    }

    private var isEditing: Bool {
        category != nil
    }

    private var navigationTitleKey: LocalizedStringKey {
        isEditing ? "Edit Category" : "New Category"
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
                Section("Kind") {
                    Picker("Kind", selection: $draft.categoryKind) {
                        ForEach(CategoryKind.allCases) { kind in
                            Text(kind.rawValue.capitalized)
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Name") {
                    HStack(spacing: 12) {
                        Image(systemName: draft.systemImage)
                            .font(.title3)
                            .foregroundStyle(draft.color.color)
                            .frame(width: 28)
                        TextField("Category name", text: $draft.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 12) {
                        ForEach(CategoryColor.allCases) { color in
                            ColorSwatchView(onSelectColor: onSelectColor, color: color, selectedColor: draft.color)
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
    AddCategoryView { _ in }
}
