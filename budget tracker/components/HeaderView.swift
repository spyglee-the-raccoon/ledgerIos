//
//  HeaderView.swift
//  budget tracker
//
//  Created by Maksym Bahrov on 02.10.2026..
//

import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack(alignment: .center) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.callout)
                .foregroundStyle(Color.secondary)
            Spacer()
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gear")
                    .padding(.vertical, 5)
            }
            .buttonStyle(.glass)
        }.padding().background(Color.gray.opacity(0.2))
    }
}

#Preview {
    HeaderView()
}
