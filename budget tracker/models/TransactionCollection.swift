//
//  TransactionCollection.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 06.10.2026..
//

import Foundation
import SwiftData
import SwiftUI

struct CollectionDraft {
    var id: UUID = UUID()
    var name: String = ""
    var systemImage: String = "globe"
    var color: CategoryColor = .blue
    var transactions: [Transaction] = []
    
    init() {}
    
    init(_ collection: TransactionCollection) {
        id = collection.id
        name = collection.name
        systemImage = collection.systemImage
        color = collection.color
        transactions = collection.transactions
    }
    
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func apply(to collection: TransactionCollection) {
        collection.name = trimmedName
        collection.id = id
        collection.systemImage = systemImage
        collection.color = color
        collection.transactions = transactions
    }
}

@Model
final class TransactionCollection: Identifiable {
    var id: UUID
    var name: String
    var systemImage: String
    var color: CategoryColor
    var transactions: [Transaction]

    init(id: UUID = UUID(), name: String, systemImage: String, color: CategoryColor, transactions: [Transaction]) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.color = color
        self.transactions = transactions
    }
}
