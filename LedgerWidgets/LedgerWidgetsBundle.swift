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
        // The app icon's long-press menu only offers the first widget's families,
        // so lead with the one that supports both small and medium.
        MonthChartWidget()
        BudgetWidget()
        RecentTransactionsWidget()
    }
}
