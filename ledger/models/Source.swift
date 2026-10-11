//
//  Source.swift
//  ledger
//
//  Created by Maksym Bahrov on 17.09.2026..
//
import Foundation
import SwiftData

struct SourceDraft {
    var name: String = ""
    var systemImage: String = "creditcard"
    var initValue: Decimal = 0
    var color: CategoryColor = .blue

    init() {}

    init(_ source: Source) {
        name = source.name
        systemImage = source.systemImage
        initValue = source.initValue
        color = source.color
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func apply(to source: Source) {
        source.name = trimmedName
        source.systemImage = systemImage
        source.initValue = initValue
        source.color = color
    }
}

@Model
final class Source {
    var name: String = ""
    var systemImage: String = "plus"
    var initValue: Decimal = 0
    var color: CategoryColor = CategoryColor.blue
    var createdAt: Date = Date.now
    
    @Relationship(deleteRule: .nullify, inverse: \Transaction.source)
    var outgoingTransactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.destination)
    var incomingTransactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \MerchantCategory.source)
    var merchantMappings: [MerchantCategory]? = []
    
    init(name: String = "", systemImage: String = "plus", initValue: Decimal = 0.0,  color: CategoryColor = .blue ) {
        self.name = name
        self.systemImage = systemImage
        self.initValue = initValue
        self.color = color
        self.createdAt = .now
    }
}
