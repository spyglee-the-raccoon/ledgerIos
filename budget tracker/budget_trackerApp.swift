//
//  budget_trackerApp.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 09.09.2026..
//

import SwiftData
import SwiftUI

@main
struct budget_trackerApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([Category.self, Source.self, Transaction.self, MerchantCategory.self])
        let configuration = ModelConfiguration(
            schema: schema,
            // Switch to .private("iCloud.work.spyglee.budget-tracker") once iCloud is enabled on a paid team
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
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
