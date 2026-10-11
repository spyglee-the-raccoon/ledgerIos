//
//  colors.swift
//  ledger
//
//  Created by Maksym Bahrov on 21.09.2026..
//

import SwiftUI

enum CategoryColor: String, Codable, CaseIterable, Identifiable {
    case primary, red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .primary: .primary
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }
}
