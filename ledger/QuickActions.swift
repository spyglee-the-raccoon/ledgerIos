//
//  QuickActions.swift
//  Ledger
//

import SwiftUI
import UIKit

/// Home Screen quick actions shown when the app icon is long-pressed.
enum QuickAction: String {
    case addTransaction = "work.spyglee.ledger.addTransaction"
    case scanReceipt = "work.spyglee.ledger.scanReceipt"

    /// Registered at runtime rather than in Info.plist so the title uses the app's translations.
    @MainActor
    static func register() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: QuickAction.addTransaction.rawValue,
                localizedTitle: String(localized: "add_transaction"),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: QuickAction.scanReceipt.rawValue,
                localizedTitle: String(localized: "quick_action_scan"),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "doc.viewfinder"),
                userInfo: nil
            ),
        ]
    }

    /// Queues the action for `MainView`; returns `false` for unknown items.
    @MainActor
    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let action = QuickAction(rawValue: item.type) else { return false }
        switch action {
        case .addTransaction: AppRouter.shared.pending = .addTransaction
        case .scanReceipt: AppRouter.shared.pending = .scanReceipt
        }
        return true
    }
}

/// Screens opened from outside the app: quick actions and widgets.
enum AppRoute: Equatable {
    case main, addTransaction, scanReceipt, budgeting, sources

    /// Parses the `WidgetLink` URLs.
    init?(url: URL) {
        guard url.scheme == "ladger" else { return nil }
        switch url.host() {
        case "main": self = .main
        case "budgeting": self = .budgeting
        case "sources": self = .sources
        default: return nil
        }
    }
}

/// Hands the requested route to `MainView`, which opens it once the app is unlocked.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var pending: AppRoute?
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        QuickAction.register()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Cold launch from a quick action: the item arrives with the connection options.
        if let item = options.shortcutItem {
            QuickAction.handle(item)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

/// Receives quick actions while the app is already running.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickAction.handle(shortcutItem))
    }
}
