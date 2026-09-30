//
//  CategoriesView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 18.09.2026..
//

import SwiftUI
import SwiftData

private enum CategorySheet: Identifiable {
    case add
    case edit(Category)

    var id: PersistentIdentifier? {
        switch self {
        case .add: nil
        case .edit(let category): category.persistentModelID
        }
    }
}

struct CategoriesView: View {
    @Environment(\.modelContext) var modelContext
    @Query var categories: [Category]
    @State private var presentedSheet: CategorySheet?
    
    var expenseCategories: [Category] {
        categories.filter { $0.categoryKind == .expense }
    }
    
    var incomeCategories: [Category] {
        categories.filter { $0.categoryKind == .income }
    }
    
    func addCategory (_ draft: CategoryDraft) {
        let newCategory = Category()
        draft.apply(to: newCategory)
        modelContext.insert(newCategory)
    }
    
    func updateCategory (_ category: Category, with draft: CategoryDraft) {
        draft.apply(to: category)
    }
    
    func deleteCategory (_ indexSet: IndexSet, from source: [Category]) {
        for index in indexSet {
            let category = source[index]
            modelContext.delete(category)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("expense_categories") {
                    ForEach(expenseCategories) { category in
                        CategoryRowView(category: category) {
                            presentedSheet = .edit(category)
                        }
                    }
                    .onDelete { deleteCategory($0, from: expenseCategories) }
                }
                Section("income_categories") {
                    ForEach(incomeCategories) { category in
                        CategoryRowView(category: category) {
                            presentedSheet = .edit(category)
                        }
                    }
                    .onDelete { deleteCategory($0, from: incomeCategories) }
                }
            }
            .navigationTitle("categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("add_category", systemImage: "plus") {
                    presentedSheet = .add
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .add:
                    AddCategoryView { draft in
                        addCategory(draft)
                    }
                case .edit(let category):
                    AddCategoryView(category: category) { draft in
                        updateCategory(category, with: draft)
                    }
                }
            }
        }
    }
}

#Preview {
    CategoriesView().modelContainer(makeMainViewPreviewContainer())
}
