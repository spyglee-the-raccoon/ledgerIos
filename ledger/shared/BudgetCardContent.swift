//
//  BudgetCardContent.swift
//  Ledger
//
//  Shared with the widget extension.
//

import SwiftUI

/// The budget card shown in Budgeting and in the budget widget.
/// `accessory` sits at the trailing edge of the title row, e.g. the on/off toggle.
struct BudgetCardContent<Accessory: View>: View {
    let data: BudgetCardData
    let currencyCode: String
    @ViewBuilder var accessory: Accessory

    private var remaining: Decimal { data.limit - data.spent }

    private var barColor: Color {
        guard data.isActive else { return .gray }
        switch data.usage {
        case ..<0.8: return .green
        case ..<1: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let category = data.category {
                    CategoryImageView(systemImage: category.systemImage, color: category.color)
                }
                VStack(alignment: .leading) {
                    if let category = data.category {
                        Text(category.name)
                    } else {
                        Text("general_budget")
                    }
                    if data.limit > 0 {
                        Group {
                            if remaining >= 0 {
                                Text("budget_left \(remaining, format: .currency(code: currencyCode))")
                            } else {
                                Text("budget_over \(-remaining, format: .currency(code: currencyCode))")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(remaining >= 0 ? Color.secondary : Color.red)
                    }
                }
                .padding(.horizontal, 2)
                Spacer()
                accessory
            }

            HStack {
                Text(data.spent, format: .currency(code: currencyCode))
                    .font(.default.bold())
                Text(verbatim: "/")
                    .foregroundStyle(.secondary)
                Text(data.limit, format: .currency(code: currencyCode))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(data.usage, format: .percent.precision(.fractionLength(0)))
                    .font(.default.bold())
                    .foregroundStyle(barColor)
            }

            ProgressView(value: min(data.usage, 1))
                .tint(barColor)
        }
        .padding(.vertical, 4)
        .opacity(data.isActive ? 1 : 0.5)
    }
}

extension BudgetCardContent where Accessory == EmptyView {
    init(data: BudgetCardData, currencyCode: String) {
        self.init(data: data, currencyCode: currencyCode) { EmptyView() }
    }
}
