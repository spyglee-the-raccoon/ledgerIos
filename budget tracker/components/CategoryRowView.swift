//
//  CategoryRowView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 22.09.2026..
//

import SwiftUI

struct CategoryRowView: View {
    let category: Category
    var onSelect: () -> Void = {}

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                Image(systemName: category.systemImage)
                    .foregroundStyle(category.color.color)
                Text(category.name)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CategoryRowView(category: Category(name: "Groceries", systemImage: "carrot", color: .green))
}
