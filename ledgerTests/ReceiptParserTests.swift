//
//  ReceiptParserTests.swift
//  kedgerTests
//

import Foundation
import Testing
@testable import Ledger

struct ContainsWordTests {
    @Test(arguments: [
        ("ukupno: 15,89", "ukupno"),
        ("za platiti 15,89", "za platiti"),
        ("сума 120,00", "сума"),
        ("15,89 total", "total"),
    ])
    func matchesWholeWord(line: String, word: String) {
        #expect(line.containsWord(word))
    }

    @Test(arguments: [
        ("sveukupno 15,89", "ukupno"),
        ("subtotal 10,00", "total"),
        ("ukupnoo 15,89", "ukupno"),
    ])
    func rejectsWordGluedToLetters(line: String, word: String) {
        #expect(!line.containsWord(word))
    }

    @Test(arguments: [
        ("iznos poreza 3,18", "porez"),
        ("pdv 25%", "pdv"),
        ("vat 23% 2,30", "vat"),
        ("sprzedaż opodatkowana 10,00", "opodatk"),
    ])
    func prefixMatchesWordStart(line: String, word: String) {
        #expect(line.containsWord(word, matchingPrefix: true))
    }

    @Test(arguments: [
        ("ukupno konzum hrvatska 15,89", "vat"),
        ("kaptur 12,00", "ptu"),
        ("privatni račun", "vat"),
    ])
    func prefixRejectsMatchInsideWord(line: String, word: String) {
        #expect(!line.containsWord(word, matchingPrefix: true))
    }

    @Test func findsLaterOccurrenceAfterGluedOne() {
        #expect("hrvatska vat 2,30".containsWord("vat", matchingPrefix: true))
    }
}

struct ReceiptParserTotalTests {
    @Test func totalLineMentioningHrvatskaIsKept() {
        let receipt = ReceiptParser.parseWithRules("""
            Konzum plus d.o.o.
            UKUPNO KONZUM HRVATSKA 15,89
            """)
        #expect(receipt.total == Decimal(string: "15.89"))
    }

    @Test func vatSummaryLinesAreSkipped() {
        let receipt = ReceiptParser.parseWithRules("""
            Konzum
            UKUPNO 15,89
            PDV 25% UKUPNO 99,99
            Porez ukupno 88,88
            """)
        #expect(receipt.total == Decimal(string: "15.89"))
    }

    @Test func polishVatLinesAreSkipped() {
        let receipt = ReceiptParser.parseWithRules("""
            Biedronka
            SUMA PLN 42,50
            SUMA PTU 99,00
            """)
        #expect(receipt.total == Decimal(string: "42.5"))
    }

    @Test func amountOnNextLineIsUsed() {
        let receipt = ReceiptParser.parseWithRules("""
            Store
            ZA PLATITI
            23,40
            """)
        #expect(receipt.total == Decimal(string: "23.4"))
    }

    @Test func largestTotalWins() {
        let receipt = ReceiptParser.parseWithRules("""
            Store
            UKUPNO 31,20
            TOTAL 6,24
            """)
        #expect(receipt.total == Decimal(string: "31.2"))
    }

    @Test func subtotalIsNotATotal() {
        let receipt = ReceiptParser.parseWithRules("""
            Store
            SUBTOTAL 10,00
            """)
        #expect(receipt.total == nil)
    }
}

struct ReceiptParserTimeTests {
    private func hourAndMinute(_ date: Date?) -> [Int?] {
        guard let date else { return [] }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return [components.hour, components.minute]
    }

    @Test func timeLabeledVrijemeIsUsed() {
        let receipt = ReceiptParser.parseWithRules("""
            Konzum
            Datum: 05.10.2026.
            Vrijeme: 14:35:12
            UKUPNO 15,89
            """)
        #expect(hourAndMinute(receipt.date) == [14, 35])
    }

    @Test func openingHoursAreIgnored() {
        let receipt = ReceiptParser.parseWithRules("""
            Store
            Radno vrijeme 08:00-21:00
            05.10.2026. 18:42
            """)
        #expect(hourAndMinute(receipt.date) == [18, 42])
    }

    @Test func unlabeledTimeNextToDateIsUsed() {
        let receipt = ReceiptParser.parseWithRules("""
            Store
            05.10.2026. 09:07
            """)
        #expect(hourAndMinute(receipt.date) == [9, 7])
    }

    @Test func missingTimeFallsBackToNow() {
        let receipt = ReceiptParser.parseWithRules("""
            Store
            05.10.2026.
            """)
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        #expect(hourAndMinute(receipt.date) == [now.hour, now.minute])
    }
}
