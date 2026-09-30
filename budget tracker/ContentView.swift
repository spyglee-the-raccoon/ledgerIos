//
//  ContentView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 09.09.2026..
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLoggedIn: Bool = false
    @State private var blurRadius: CGFloat = 0
    
    var body: some View {
        if isLoggedIn {
            MainView()
                .blur(radius: blurRadius)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .inactive {
                        withAnimation { blurRadius = 20 }
                    } else {
                        withAnimation { blurRadius = 0 }
                    }
                }
        } else {
            NavigationStack {
                LogInView(onLoggedIn: { isLoggedIn = true })
            }
        }
    }
}

#Preview {
    ContentView()
}
