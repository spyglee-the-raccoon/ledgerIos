//
//  AddCategoryView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 18.09.2026..
//

import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category?
    let onSave: (CategoryDraft) -> Void
    
    @State private var draft: CategoryDraft
    @State private var symbolSearch = ""
    @State private var showCategoryExistsAlert = false

    @Query var categories: [Category]

    init(category: Category? = nil, onSave: @escaping (CategoryDraft) -> Void) {
        self.category = category
        self.onSave = onSave
        self.draft = category.map { CategoryDraft($0) } ?? CategoryDraft()
    }

    private var isEditing: Bool {
        category != nil
    }

    private var navigationTitleKey: LocalizedStringKey {
        isEditing ? "edit_category" : "new_category"
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
        let expistingCategory = categories.firstIndex(where: {
            $0.persistentModelID != category?.persistentModelID
                && $0.name == draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        })
        if expistingCategory != nil {
            showCategoryExistsAlert = true
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
    
    func getKindName(_ kind: CategoryKind) -> LocalizedStringResource {
        switch(kind) {
        case .expense:
            return "expense"
        case .income:
            return "income"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("kind") {
                    Picker("kind", selection: $draft.categoryKind) {
                        ForEach(CategoryKind.allCases) { kind in
                            Text(getKindName(kind))
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("name") {
                    HStack(spacing: 12) {
                        Image(systemName: draft.systemImage)
                            .font(.title3)
                            .foregroundStyle(draft.color.color)
                            .frame(width: 28)
                        TextField("category_name", text: $draft.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                    }
                }
                
                Section("color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 12)], spacing: 12) {
                        ForEach(CategoryColor.allCases) { color in
                            ColorSwatchView(onSelectColor: onSelectColor, color: color, selectedColor: draft.color)
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
            .alert("error", isPresented: $showCategoryExistsAlert) {
            } message: {
                Text("category_exists")
            }
        }
    }
}

#Preview {
    AddCategoryView { _ in }
}
