//
//  ledgerApp.swift
//  ledger
//
//  Created by Maksym Bahrov on 09.09.2026..
//

import SwiftData
import SwiftUI
import UserNotifications

@main
struct budget_trackerApp: App {
    // The notification center holds its delegate weakly, so keep it alive here.
    private let notificationDelegate = ForegroundNotificationDelegate()
    @State private var subscriptionManager = SubscriptionManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    let modelContainer = LedgerStore.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionManager)
                .task { await subscriptionManager.observeEntitlements() }
        }
        .modelContainer(modelContainer)
    }
}
