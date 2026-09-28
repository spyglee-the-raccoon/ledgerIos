//
//  ContentView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 09.09.2026..
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn: Bool = false
    
    var body: some View {
        if isLoggedIn {
            MainView()
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
