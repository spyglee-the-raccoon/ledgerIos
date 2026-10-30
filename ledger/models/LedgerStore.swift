//
//  LedgerStore.swift
//  Ledger
//

import Foundation
import SwiftData

/// The app's one SwiftData container, shared by the UI and Siri/Shortcuts actions,
/// so a transaction logged by an action shows up in open screens right away.
enum LedgerStore {
    static let container: ModelContainer = {
        let schema = Schema([Category.self, Source.self, Transaction.self, MerchantCategory.self, TransactionCollection.self, PlannedTransaction.self, Budget.self, ReceiptItem.self, ReceiptPhoto.self])
        let configuration = ModelConfiguration(
            schema: schema,
            // Switch to .private("iCloud.work.spyglee.ledger") once iCloud is enabled on a paid team
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            DefaultData.seedIfNeeded(in: container)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
