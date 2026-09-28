//
//  ColorSwatchView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 18.09.2026..
//
import SwiftUI


struct ColorSwatchView: View {
    var onSelectColor: (_ color: CategoryColor) -> Void = { _ in }

    let color: CategoryColor
    let selectedColor: CategoryColor
    
    var isSelected: Bool { color == selectedColor }
    
    var body: some View {
        Button {
            onSelectColor(color)
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.color)
                .frame(width: 40, height: 40)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.tint, lineWidth: 3)
                        .padding(-4)
                        .opacity(isSelected ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.rawValue)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ColorSwatchView(color: .blue, selectedColor: .red)
}
