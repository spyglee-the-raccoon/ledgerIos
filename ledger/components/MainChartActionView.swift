//
//  MainChartActionView.swift
//  ledger
//
//  Created by Maksym Bahrov on 02.10.2026..
//

import SwiftUI

struct MainChartActionView: View {
    var currentMonth: DateInterval
    
    @Binding var activeSheet: MainViewActiveSheet?

    init(month: DateInterval, activeSheet: Binding<MainViewActiveSheet?>) {
        self.currentMonth = month
        self._activeSheet = activeSheet
    }
    
    func onAddTransaction() {
        activeSheet = .add
    }
    
    var body: some View {
        VStack {
            Spacer()
            MainChartView(month: currentMonth)
                .id(currentMonth)
                .transition(.blurReplace)
            Spacer()
            Button(action: onAddTransaction) {
                Text("add_transaction").padding(10)
            }.buttonStyle(.glass)
        }
    }
}

#Preview {
    MainChartActionView(month: DateInterval.month(containing: .now), activeSheet: .constant(nil))
}
