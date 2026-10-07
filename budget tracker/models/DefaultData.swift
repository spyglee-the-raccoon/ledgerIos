//
//  DefaultData.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 06.10.2026..
//

import Foundation
import SwiftData

enum DefaultData {
    static let storageKey = "didSeedDefaultData"

    static func seedIfNeeded(in container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: storageKey) else { return }

        let context = ModelContext(container)
        let categoryCount = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        let sourceCount = (try? context.fetchCount(FetchDescriptor<Source>())) ?? 0

        if categoryCount == 0 {
            categories.forEach { context.insert($0) }
        }
        if sourceCount == 0 {
            sources.forEach { context.insert($0) }
        }

        do {
            try context.save()
            defaults.set(true, forKey: storageKey)
        } catch {
            print("Failed to seed default data: \(error)")
        }
    }

    private static var categories: [Category] {
        [
            // Expenses
            Category(name: String(localized: "Groceries"), systemImage: "cart", color: .green, categoryKind: .expense),
            Category(name: String(localized: "Restaurants"), systemImage: "fork.knife", color: .orange, categoryKind: .expense),
            Category(name: String(localized: "Transport"), systemImage: "car", color: .blue, categoryKind: .expense),
            Category(name: String(localized: "Housing"), systemImage: "house", color: .brown, categoryKind: .expense),
            Category(name: String(localized: "Utilities"), systemImage: "lightbulb", color: .yellow, categoryKind: .expense),
            Category(name: String(localized: "Health"), systemImage: "cross.case", color: .red, categoryKind: .expense),
            Category(name: String(localized: "Entertainment"), systemImage: "film", color: .purple, categoryKind: .expense),
            Category(name: String(localized: "Shopping"), systemImage: "bag", color: .pink, categoryKind: .expense),
            Category(name: String(localized: "Subscriptions"), systemImage: "tv", color: .indigo, categoryKind: .expense),
            Category(name: String(localized: "Other"), systemImage: "questionmark.circle", color: .gray, categoryKind: .expense),
            // Income
            Category(name: String(localized: "Salary"), systemImage: "briefcase", color: .green, categoryKind: .income),
            Category(name: String(localized: "Freelance"), systemImage: "laptopcomputer", color: .teal, categoryKind: .income),
            Category(name: String(localized: "Gifts"), systemImage: "gift", color: .pink, categoryKind: .income),
            Category(name: String(localized: "Investments"), systemImage: "chart.line.uptrend.xyaxis", color: .mint, categoryKind: .income)
        ]
    }

    private static var sources: [Source] {
        [
            Source(name: String(localized: "Cash"), systemImage: "banknote", color: .green),
            Source(name: String(localized: "Bank Card"), systemImage: "creditcard", color: .blue),
            Source(name: String(localized: "Savings"), systemImage: "building.columns", color: .indigo)
        ]
    }
}
