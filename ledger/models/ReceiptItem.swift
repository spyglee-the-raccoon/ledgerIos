//
//  ReceiptItem.swift
//  Ledger
//
//  Created by Maksym Bahrov on 28.10.2026..
//

import Foundation
import SwiftData

/// A product line recognized on a scanned receipt. Date and store come from the
/// owning transaction, so editing the transaction keeps the price history correct.
@Model
final class ReceiptItem {
    var name: String = ""
    /// Grouping key for price comparison, see `ReceiptItem.normalize(_:)`.
    var normalizedName: String = ""
    var quantity: Decimal = 1
    var unitPrice: Decimal = 0
    var totalPrice: Decimal = 0
    /// Order of the line on the receipt.
    var position: Int = 0
    var transaction: Transaction?

    init(name: String, quantity: Decimal, unitPrice: Decimal, totalPrice: Decimal, position: Int) {
        self.name = name
        self.normalizedName = Self.normalize(name)
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.position = position
    }

    /// Case-, diacritic- and spacing-insensitive name, so OCR differences such as
    /// "Mlijeko  1L" and "MLIJEKO 1l" count as the same product.
    static func normalize(_ name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// A scanned receipt page attached to a transaction.
@Model
final class ReceiptPhoto {
    @Attribute(.externalStorage) var imageData: Data = Data()
    var pageIndex: Int = 0
    var transaction: Transaction?

    init(imageData: Data, pageIndex: Int) {
        self.imageData = imageData
        self.pageIndex = pageIndex
    }
}
