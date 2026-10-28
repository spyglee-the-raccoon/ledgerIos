//
//  Category.swift
//  ledger
//
//  Created by Maksym Bahrov on 17.09.2026..
//

import Foundation
import SwiftData

enum CategoryKind: String, Codable, CaseIterable, Identifiable {
    case income, expense
    
    var id: String { rawValue }
}

struct CategoryDraft {
    var name: String = ""
    var systemImage: String = "tag"
    var color: CategoryColor = .primary
    var categoryKind: CategoryKind = .expense

    init() {}

    init(_ category: Category) {
        name = category.name
        systemImage = category.systemImage
        color = category.color
        categoryKind = category.categoryKind
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(to category: Category) {
        category.name = trimmedName
        category.systemImage = systemImage
        category.color = color
        category.categoryKind = categoryKind
    }
}

@Model
final class Category {
    var name: String = ""
    var systemImage: String = "carrot"
    var color: CategoryColor = CategoryColor.primary
    var categoryKind: CategoryKind = CategoryKind.expense
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category) var transactions: [Transaction]? = []
    @Relationship(deleteRule: .cascade, inverse: \MerchantCategory.category) var merchantMappings: [MerchantCategory]? = []
    @Relationship(deleteRule: .cascade, inverse: \Budget.category) var budgets: [Budget]? = []

    init(name: String = "", systemImage: String = "carrot", color: CategoryColor = .primary, categoryKind: CategoryKind = .expense, transactions: [Transaction] = []) {
        self.name = name
        self.systemImage = systemImage
        self.color = color
        self.categoryKind = categoryKind
    }
}
