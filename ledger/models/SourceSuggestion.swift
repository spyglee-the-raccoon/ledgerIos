//
//  SourceSuggestion.swift
//  ledger
//
//  Created by Maksym Bahrov on 29.09.2026..
//

import Foundation
import SwiftData

enum SourceSuggestion {
    enum Role {
        case source, destination
    }

    private static let historySize = 30

    static func mostLikely(
        _ role: Role,
        for kind: TransactionKind,
        excluding excluded: Source? = nil,
        in context: ModelContext
    ) -> Source? {
        var descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 200
        guard let recent = try? context.fetch(descriptor) else { return nil }

        let used = recent
            .filter { $0.kind == kind }
            .compactMap { role == .source ? $0.source : $0.destination }
            .filter { $0 != excluded }
            .prefix(historySize)

        var counts: [Source: Int] = [:]
        var lastUsed: [Source: Int] = [:]
        for (index, source) in used.enumerated() {
            counts[source, default: 0] += 1
            lastUsed[source] = lastUsed[source] ?? index
        }
        return counts.max { lhs, rhs in
            lhs.value != rhs.value
                ? lhs.value < rhs.value
                : lastUsed[lhs.key, default: 0] > lastUsed[rhs.key, default: 0]
        }?.key
    }
}
