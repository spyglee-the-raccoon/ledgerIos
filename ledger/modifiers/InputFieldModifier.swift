//
//  InputFieldModifier.swift
//  ledger
//
//  Created by Maksym Bahrov on 10.09.2026..
//

import SwiftUI

struct InputFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            .padding()
            .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.8))
            .cornerRadius(12)
            .keyboardType(.emailAddress)
    }
}
