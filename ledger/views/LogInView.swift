//
//  ContentView.swift
//  ledger
//
//  Created by Maksym Bahrov on 09.09.2026..
//

import SwiftUI

struct LogInView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var didAppear: Bool = false
    
    var isDark: Bool { colorScheme == .dark }
    
    var onLoggedIn: () -> Void = {}
    
    func onLogIn () {
        onLoggedIn()
    }
    
    var body: some View {
        ZStack {
            BackgroundView()
            VStack {
                Spacer()
                Image(systemName: "eurosign.gauge.chart.lefthalf.righthalf")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle( isDark ? Color.black : Color.white.opacity(0.8))
                
                Spacer()
                VStack {
                    TextField("email", text: $email)
                        .modifier(InputFieldModifier())
                        .keyboardType(.emailAddress)
                        .foregroundStyle(Color.primary)
                    SecureField("password", text: $password)
                        .modifier(InputFieldModifier())
                        .padding(.vertical)
                        .foregroundStyle(Color.primary)
                    Button(action: onLogIn) {
                        Text("log_in")
                            .foregroundStyle(Color.gray)
                            .padding(.horizontal)
                            .opacity(0.8)
                    }.buttonStyle(.glass)
                }
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 10)
                Spacer()
                NavigationLink(destination: SignUpView()) {
                    Text("sign_up")
                        .foregroundStyle(isDark ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                        .padding(.horizontal)
                }
            }
            .padding()
            .onAppear { withAnimation(.easeIn(duration: 1)) { didAppear = true } }
        }
    }
}

#Preview {
    LogInView(onLoggedIn: {})
}
