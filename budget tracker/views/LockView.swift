//
//  LockView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 30.09.2026..
//

import SwiftUI
import LocalAuthentication

enum AppLock {
    static let storageKey = "isBiometricsRequired"

    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "unlock_reason")
            )
        } catch {
            return false
        }
    }
}

struct LockView: View {
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.primary)
                Text("app_locked")
                    .font(.title2.bold())
                Button("unlock", systemImage: "faceid", action: onUnlock)
                    .buttonStyle(.glassProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    LockView(onUnlock: {})
}
