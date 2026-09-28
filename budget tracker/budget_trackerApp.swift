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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Category.self, Source.self, Transaction.self])
    }
}
