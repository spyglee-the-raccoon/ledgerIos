//
//  LedgerShortcuts.swift
//  Ledger
//
//  Phrases are what people say to Siri; once shipped, add new ones rather than
//  renaming or removing them.
//

import AppIntents

nonisolated struct LedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTransactionIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add an expense in \(.applicationName)",
                "Log \(\.$kind) in \(.applicationName)",
                "Log \(\.$category) in \(.applicationName)",
            ],
            shortTitle: "Log Transaction",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: BudgetLeftIntent(),
            // Money questions like "how much…" or "what's my balance" are claimed by
            // Wallet and Apple Cash, so these phrases lead with the app name.
            phrases: [
                "\(.applicationName) budget",
                "Check my \(.applicationName) budget",
                "Ask \(.applicationName) how much budget is left",
                "\(.applicationName) budget for \(\.$category)",
            ],
            shortTitle: "Budget Left",
            systemImageName: "gauge.with.dots.needle.33percent"
        )
        AppShortcut(
            intent: MonthSummaryIntent(),
            // Siri may treat "this month" as a date rather than part of the phrase,
            // so there are variants without it; the action always covers this month.
            phrases: [
                "\(.applicationName) spending this month",
                "Ask \(.applicationName) how much I spent this month",
                "\(.applicationName) spending on \(\.$category)",
                "\(.applicationName) spending",
                "\(.applicationName) monthly spending",
                "Check my \(.applicationName) spending",
            ],
            shortTitle: "Spending This Month",
            systemImageName: "chart.pie"
        )
        AppShortcut(
            intent: AccountBalanceIntent(),
            phrases: [
                "\(.applicationName) total balance",
                "Ask \(.applicationName) for my total balance",
                "\(.applicationName) balance of \(\.$account)",
            ],
            shortTitle: "Account Balance",
            systemImageName: "creditcard"
        )
        // These ask "Which category?" / "Which account?", so they don't depend on
        // the system having indexed the names used in the phrases above.
        AppShortcut(
            intent: CategoryBudgetLeftIntent(),
            phrases: [
                "\(.applicationName) category budget",
                "\(.applicationName) budget by category",
            ],
            shortTitle: "Category Budget Left",
            systemImageName: "gauge.with.dots.needle.33percent"
        )
        AppShortcut(
            intent: CategorySpendingIntent(),
            phrases: [
                "\(.applicationName) category spending",
                "\(.applicationName) spending by category",
            ],
            shortTitle: "Category Spending",
            systemImageName: "chart.pie"
        )
        AppShortcut(
            intent: AskAccountBalanceIntent(),
            phrases: [
                "\(.applicationName) account balance",
                "Check a \(.applicationName) account",
            ],
            shortTitle: "Balance of an Account",
            systemImageName: "creditcard"
        )
    }
}
