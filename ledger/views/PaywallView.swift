//
//  PaywallView.swift
//  ledger
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

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
