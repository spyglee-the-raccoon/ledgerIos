//
//  LedgerWidgetsBundle.swift
//  LedgerWidgets
//
//  Created by Maksym Bahrov on 30.10.2026..
//

import WidgetKit
import SwiftUI

@main
struct LedgerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BudgetWidget()
        MonthChartWidget()
        RecentTransactionsWidget()
    }
}
