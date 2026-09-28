//
//  SignUp.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 10.09.2026..
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var isDark: Bool { colorScheme == .dark }
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var didAppear: Bool = false
    
    func onSignUp () {
        
    }
    
    var body: some View {
        ZStack {
            BackgroundView()
            VStack {
                HStack {
                    Button(action: { self.presentationMode.wrappedValue.dismiss() }) {
                        Text("log in")
                            .foregroundStyle((isDark ? Color.black : Color.white).opacity(0.8))
                    }
                    Spacer()
                }
                Spacer()
                VStack {
                    TextField("name", text: $name)
                        .modifier(InputFieldModifier())
                        .keyboardType(.default)
                        .foregroundStyle(Color.primary)
                        .tint(.gray)
                        .padding(.bottom, 10)
                    TextField("email", text: $email)
                        .modifier(InputFieldModifier())
                        .keyboardType(.emailAddress)
                        .padding(.bottom, 10)
                        .foregroundStyle(Color.primary)
                    SecureField("password", text: $password)
                        .modifier(InputFieldModifier())
                        .keyboardType(.default)
                        .padding(.bottom, 10)
                        .foregroundStyle(Color.primary)
                    SecureField("confirm password", text: $confirmPassword)
                        .modifier(InputFieldModifier())
                        .keyboardType(.default)
                        .padding(.bottom, 10)
                        .foregroundStyle(Color.primary)
                    Button(action: onSignUp) {
                        Text("sign up")
                            .foregroundStyle(Color.gray)
                            .padding(.horizontal)
                            .opacity(0.8)
                    }.buttonStyle(.glass)
                }
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 10)
                Spacer()
            }
            .padding()
            .onAppear { withAnimation(.easeIn(duration: 1)) { didAppear = true } }
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    SignUpView()
}

