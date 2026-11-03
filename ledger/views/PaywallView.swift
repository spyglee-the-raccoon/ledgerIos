//
//  PaywallView.swift
//  ledger
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    private static let termsOfServiceURL = URL(string: "https://spyglee.work/ledger/terms/")!
    private static let privacyPolicyURL = URL(string: "https://spyglee.work/ledger/privacy/")!

    var body: some View {
        SubscriptionStoreView(productIDs: SubscriptionManager.productIDs) {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 56))
                    .foregroundStyle(.purple)
                Text("paywall_title")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("paywall_subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        // App Review requires links to the terms and privacy policy for auto-renewable subscriptions.
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyDestination(url: Self.termsOfServiceURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: Self.privacyPolicyURL, for: .privacyPolicy)
        .onInAppPurchaseCompletion { _, _ in
            await subscriptionManager.refreshEntitlements()
            if subscriptionManager.isSubscribed {
                dismiss()
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
