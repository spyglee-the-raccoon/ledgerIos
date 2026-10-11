//
//  BackgroudView.swift
//  ledger
//
//  Created by Maksym Bahrov on 10.09.2026..
//

import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var isDark: Bool { colorScheme == .dark }
    
    var color1: Color { Color.indigo.opacity(isDark ? 0.7 : 1) }
    var color2: Color { Color.blue.opacity(isDark ? 0.7 : 1) }
    var color3: Color { Color.mint.opacity(isDark ? 0.7 : 1) }
     
    var body: some View {
        RadialGradient(colors: [color1, color2, color3], center: .topLeading, startRadius: .zero, endRadius: 950)
            .ignoresSafeArea()
    }
}

#Preview {
    BackgroundView()
}
