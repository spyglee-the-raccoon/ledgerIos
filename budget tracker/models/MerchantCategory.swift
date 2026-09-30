//
//  MerchantCategory.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 29.09.2026..
//

import Foundation
import SwiftData

@Model
final class MerchantCategory {
    var merchantKey: String = ""
    var category: Category?
    var source: Source?
    var updatedAt: Date = Date.now

    init(merchantKey: String, category: Category?, source: Source?) {
        self.merchantKey = merchantKey
        self.category = category
        self.source = source
    }

    static func normalize(_ merchant: String) -> String {
        let legalForms: Set<String> = ["d", "o", "dd", "doo", "jdoo", "obrt", "vl", "ltd", "llc", "inc", "gmbh"]
        let words = merchant
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: ".")))
            .map { $0.replacingOccurrences(of: ".", with: "") }
            .filter { !$0.isEmpty && !legalForms.contains($0) }
        return words.joined(separator: " ")
    }

    static func learned(for merchant: String, in context: ModelContext) -> MerchantCategory? {
        let key = normalize(merchant)
        guard !key.isEmpty else { return nil }
        let descriptor = FetchDescriptor<MerchantCategory>(predicate: #Predicate { $0.merchantKey == key })
        if let exact = (try? context.fetch(descriptor))?.first {
            return exact
        }

        let recent = FetchDescriptor<MerchantCategory>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(recent))?.first { mapping in
            key.hasPrefix(mapping.merchantKey + " ") || mapping.merchantKey.hasPrefix(key + " ")
        }
    }

    static func learn(merchant: String, category: Category, source: Source?, in context: ModelContext) {
        let key = normalize(merchant)
        guard !key.isEmpty else { return }
        let descriptor = FetchDescriptor<MerchantCategory>(predicate: #Predicate { $0.merchantKey == key })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.category = category
            existing.source = source
            existing.updatedAt = .now
        } else {
            context.insert(MerchantCategory(merchantKey: key, category: category, source: source))
        }
    }
}
