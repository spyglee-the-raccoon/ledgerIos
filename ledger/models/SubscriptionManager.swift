//
//  SubscriptionManager.swift
//  ledger
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class SubscriptionManager {
    static let productIDs = [
        "work.spyglee.ledger.pro.monthly",
        "work.spyglee.ledger.pro.yearly"
    ]

    private(set) var isSubscribed = false

    func observeEntitlements() async {
        await refreshEntitlements()
        for await result in StoreKit.Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
            await refreshEntitlements()
        }
    }

    func refreshEntitlements() async {
        var hasEntitlement = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            hasEntitlement = true
        }
        isSubscribed = hasEntitlement
    }
}
