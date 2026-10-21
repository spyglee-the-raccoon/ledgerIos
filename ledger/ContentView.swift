//
//  ContentView.swift
//  ledger
//
//  Created by Maksym Bahrov on 09.09.2026..
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
//    @State private var isLoggedIn: Bool = false
    @State private var blurRadius: CGFloat = 0
    @AppStorage(AppLock.storageKey) private var isBiometricsRequired: Bool = false
    @State private var isLocked: Bool = UserDefaults.standard.bool(forKey: AppLock.storageKey)
    @State private var isAuthenticating: Bool = false
    @State private var shouldPromptOnActive: Bool = false

    var body: some View {
//        if isLoggedIn {
            MainView()
                .blur(radius: blurRadius)
                .overlay {
                    if isLocked {
                        LockView(onUnlock: unlock)
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .inactive {
                        withAnimation { blurRadius = 20 }
                    } else {
                        withAnimation { blurRadius = 0 }
                    }
                    if newPhase == .background && isBiometricsRequired {
                        isLocked = true
                        shouldPromptOnActive = true
                    } else if newPhase == .active && isLocked && shouldPromptOnActive {
                        shouldPromptOnActive = false
                        unlock()
                    }
                }
                .task {
                    if isLocked { unlock() }
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { try? RecurrenceEngine.generateDue(in: modelContext) }
                }
//        } else {
//            NavigationStack {
//                LogInView(onLoggedIn: { isLoggedIn = true })
//            }
//        }
    }

    private func unlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            if await AppLock.authenticate() {
                withAnimation { isLocked = false }
            }
            isAuthenticating = false
        }
    }
}

#Preview {
    ContentView()
}
