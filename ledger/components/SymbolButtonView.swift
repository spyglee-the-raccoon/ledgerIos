//
//  SymbolButtonView.swift
//  ledger
//
//  Created by Maksym Bahrov on 19.09.2026..
//

import SwiftUI

struct SymbolButtonView: View {
    var onSelectIcon: (_ icon: String) -> Void = { _ in }
    
    let symbol: String
    let selected: String
    
    var isSelected: Bool { symbol == selected }
    
    var body: some View {
        

        return Button {
            onSelectIcon(symbol)
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(width: 44, height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    SymbolButtonView(symbol: "plus", selected: "tag")
}
