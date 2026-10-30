//
//  TransactionCardContent.swift
//  Ledger
//
//  Shared with the widget extension.
//

import SwiftUI

/// The transaction row shown in transaction lists and in the recent transactions widget.
struct TransactionCardContent: View {
    let data: TransactionCardData
    let currencyCode: String
    /// Lists are grouped by day and show only the time; elsewhere older
    /// transactions show their date instead.
    var showsDate = false

    private var amountColor: Color {
        switch data.kind {
        case .expense: .red
        case .income: .green
        case .transfer: .primary
        }
    }

    private var dateText: String {
        if showsDate && !Calendar.current.isDateInToday(data.date) {
            data.date.formatted(.dateTime.day().month(.abbreviated))
        } else {
            data.date.formatted(date: .omitted, time: .shortened)
        }
    }

    var body: some View {
        HStack {
            if data.kind == .transfer {
                CategoryImageView(systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90", color: .gray)
                title(Text("transfer"))
            } else if let category = data.category {
                CategoryImageView(systemImage: category.systemImage, color: category.color)
                title(
                    Text(category.name)
                        .font(.default)
                        .foregroundStyle(.primary)
                )
            } else {
                CategoryImageView(systemImage: "questionmark", color: .gray)
                title(
                    Text("uncategorized")
                        .font(.default)
                        .foregroundStyle(.primary)
                )
            }
            Spacer()
            Text(data.amount, format: .currency(code: currencyCode))
                .font(.default.bold())
                .foregroundStyle(amountColor)
                .padding(.horizontal, 2)
            Text(dateText)
                .font(.default)
                .foregroundStyle(.primary)
        }
    }

    private func title(_ text: Text) -> some View {
        VStack(alignment: .leading) {
            text
            if data.note != "" {
                Text(data.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }
}
