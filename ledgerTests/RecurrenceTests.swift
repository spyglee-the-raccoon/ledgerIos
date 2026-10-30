//
//  RecurrenceTests.swift
//  LedgerTests
//

import Foundation
import SwiftData
import Testing
@testable import Ledger

struct PlannedTransactionScheduleTests {
    private func planned(_ frequency: RecurrenceFrequency, interval: Int = 1, start: Date) -> PlannedTransaction {
        PlannedTransaction(
            amount: 10, kind: .expense, note: "", frequency: frequency, interval: interval,
            startDate: start, occurrencesGenerated: 0, isPaused: false
        )
    }

    @Test func firstOccurrenceIsStartDate() {
        let start = date(2026, 3, 15, calendar: utcCalendar)
        #expect(planned(.monthly, start: start).occurrenceDate(0, calendar: utcCalendar) == start)
    }

    @Test(arguments: [
        (.daily, 1, DateComponents(year: 2026, month: 3, day: 16)),
        (.daily, 3, DateComponents(year: 2026, month: 3, day: 18)),
        (.weekly, 1, DateComponents(year: 2026, month: 3, day: 22)),
        (.weekly, 2, DateComponents(year: 2026, month: 3, day: 29)),
        (.monthly, 1, DateComponents(year: 2026, month: 4, day: 15)),
        (.monthly, 3, DateComponents(year: 2026, month: 6, day: 15)),
        (.yearly, 1, DateComponents(year: 2027, month: 3, day: 15)),
    ] as [(RecurrenceFrequency, Int, DateComponents)])
    func secondOccurrenceRespectsFrequencyAndInterval(frequency: RecurrenceFrequency, interval: Int, expected: DateComponents) throws {
        let item = planned(frequency, interval: interval, start: date(2026, 3, 15, calendar: utcCalendar))
        let second = try #require(item.occurrenceDate(1, calendar: utcCalendar))
        #expect(dayComponents(second, calendar: utcCalendar) == expected)
    }

    /// Each occurrence is computed from the start date, so a month-end schedule
    /// clamps to short months without drifting to the 28th afterwards.
    @Test func monthEndDoesNotDrift() throws {
        let item = planned(.monthly, start: date(2026, 1, 31, calendar: utcCalendar))
        let days = try (0...3).map { try #require(item.occurrenceDate($0, calendar: utcCalendar)) }
            .map { dayComponents($0, calendar: utcCalendar) }
        #expect(days == [
            DateComponents(year: 2026, month: 1, day: 31),
            DateComponents(year: 2026, month: 2, day: 28),
            DateComponents(year: 2026, month: 3, day: 31),
            DateComponents(year: 2026, month: 4, day: 30),
        ])
    }

    @Test func leapDayYearlyFallsBackToFebruary28() throws {
        let item = planned(.yearly, start: date(2028, 2, 29, calendar: utcCalendar))
        let next = try #require(item.occurrenceDate(1, calendar: utcCalendar))
        #expect(dayComponents(next, calendar: utcCalendar) == DateComponents(year: 2029, month: 2, day: 28))
        let leap = try #require(item.occurrenceDate(4, calendar: utcCalendar))
        #expect(dayComponents(leap, calendar: utcCalendar) == DateComponents(year: 2032, month: 2, day: 29))
    }

    @Test func nextDueDateAdvancesWithGeneratedOccurrences() {
        let item = planned(.weekly, start: date(2026, 3, 15))
        #expect(item.nextDueDate == date(2026, 3, 15))
        item.occurrencesGenerated = 2
        #expect(item.nextDueDate == date(2026, 3, 29))
    }

    @Test func frequencyComponents() {
        #expect(RecurrenceFrequency.daily.component == .day)
        #expect(RecurrenceFrequency.weekly.component == .weekOfYear)
        #expect(RecurrenceFrequency.monthly.component == .month)
        #expect(RecurrenceFrequency.yearly.component == .year)
    }

    @Test func draftRoundTrip() {
        let original = PlannedTransaction(
            amount: 42, kind: .income, note: "Salary", frequency: .monthly, interval: 2,
            startDate: date(2026, 1, 1), endDate: date(2026, 12, 31), occurrencesGenerated: 3, isPaused: true
        )
        var draft = PlannedTransactionDraft(original)
        #expect(draft.amount == 42)
        #expect(draft.kind == .income)
        #expect(draft.interval == 2)
        #expect(draft.isPaused)

        draft.amount = 50
        draft.frequency = .weekly
        draft.endDate = nil
        draft.apply(to: original)
        #expect(original.amount == 50)
        #expect(original.frequency == .weekly)
        #expect(original.endDate == nil)
        #expect(original.occurrencesGenerated == 3, "Editing must not reset the generated count")
    }
}

@MainActor
struct RecurrenceEngineTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try makeTestContainer()
    }

    @discardableResult
    private func addPlanned(
        start: Date, end: Date? = nil, frequency: RecurrenceFrequency = .monthly,
        paused: Bool = false, category: Ledger.Category? = nil
    ) -> PlannedTransaction {
        let planned = PlannedTransaction(
            amount: 9.99, kind: .expense, note: "Streaming", category: category, frequency: frequency,
            interval: 1, startDate: start, endDate: end, occurrencesGenerated: 0, isPaused: paused
        )
        context.insert(planned)
        return planned
    }

    private func transactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)]))
    }

    @Test func generatesEveryPastOccurrence() throws {
        let category = Category(name: "Subscriptions")
        context.insert(category)
        let planned = addPlanned(start: date(2026, 7, 10), category: category)

        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))

        let generated = try transactions()
        #expect(generated.map { dayComponents($0.date).month } == [7, 8, 9, 10])
        #expect(generated.allSatisfy { $0.amount == 9.99 && $0.kind == .expense && $0.note == "Streaming" })
        #expect(generated.allSatisfy { $0.category === category && $0.plannedTransaction === planned })
        #expect(planned.occurrencesGenerated == 4)
    }

    @Test func occurrenceDueExactlyNowIsGenerated() throws {
        addPlanned(start: date(2026, 10, 15))
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))
        #expect(try transactions().count == 1)
    }

    @Test func runningTwiceDoesNotDuplicate() throws {
        addPlanned(start: date(2026, 7, 10))
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))
        #expect(try transactions().count == 4)
    }

    @Test func laterRunGeneratesOnlyNewOccurrences() throws {
        addPlanned(start: date(2026, 7, 10))
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 8, 1))
        #expect(try transactions().count == 1)
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))
        #expect(try transactions().count == 4)
    }

    @Test func stopsAtEndDate() throws {
        let planned = addPlanned(start: date(2026, 7, 10), end: date(2026, 8, 20))
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))
        #expect(try transactions().count == 2)
        #expect(planned.occurrencesGenerated == 2)
    }

    @Test func pausedTemplatesAreSkipped() throws {
        let planned = addPlanned(start: date(2026, 7, 10), paused: true)
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))
        #expect(try transactions().isEmpty)
        #expect(planned.occurrencesGenerated == 0)
    }

    @Test func futureStartGeneratesNothing() throws {
        addPlanned(start: date(2026, 11, 1))
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 15))
        #expect(try transactions().isEmpty)
    }

    @Test func dailyScheduleCatchesUpAfterLongGap() throws {
        addPlanned(start: date(2026, 10, 1), frequency: .daily)
        try RecurrenceEngine.generateDue(in: context, now: date(2026, 10, 30))
        #expect(try transactions().count == 30)
    }
}
