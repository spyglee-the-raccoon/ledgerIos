//
//  ledgerApp.swift
//  ledger
//
//  Created by Maksym Bahrov on 09.09.2026..
//

import SwiftData
import SwiftUI

@main
struct budget_trackerApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([Category.self, Source.self, Transaction.self, MerchantCategory.self, TransactionCollection.self, PlannedTransaction.self])
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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
