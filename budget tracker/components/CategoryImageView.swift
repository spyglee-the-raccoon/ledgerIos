//
//  CategoryImageView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 27.09.2026..
//

import SwiftUI

struct CategoryImageView: View {
    var systemImage: String
    var color: CategoryColor
    
    init(systemImage: String, color: CategoryColor) {
        self.systemImage = systemImage
        self.color = color
    }
    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(color.color)
            .frame(width: 35, height: 35, alignment: .center)
            .background(color.color.opacity(0.2))
            .clipShape(.circle)
    }
}

#Preview {
    CategoryImageView(systemImage: "basket", color: .indigo)
}
