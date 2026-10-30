//
//  CSVTests.swift
//  LedgerTests
//

import Foundation
import SwiftData
import Testing
@testable import Ledger

@MainActor
struct CSVImporterTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try makeTestContainer()
    }

    @discardableResult
    private func importCSV(_ files: (name: String, text: String)...) throws -> CSVImportResult {
        try CSVImporter.importFiles(try writeCSVFiles(files), into: context)
    }

    private func transactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)]))
    }

    @Test func importsExpensesAndCreatesAccountsAndCategories() throws {
        let result = try importCSV(("expenses.csv", """
            date;amount;source;category;details
            05.10.2026;12,50;Cash;Food;Lunch
            06.10.2026;30.00;Card;Food;Groceries
            """))

        #expect(result.importedCount == 2)
        #expect(result.createdSources == 2)
        #expect(result.createdCategories == 1)
        #expect(result.skippedCount == 0)

        let imported = try transactions()
        #expect(imported.map(\.amount) == [decimal("12.5"), 30])
        #expect(imported.map(\.note) == ["Lunch", "Groceries"])
        #expect(imported.map { $0.source?.name } == ["Cash", "Card"])
        #expect(imported.allSatisfy { $0.kind == .expense && $0.destination == nil })
        #expect(imported.allSatisfy { $0.category?.name == "Food" && $0.category?.categoryKind == .expense })
        #expect(dayComponents(imported[0].date) == DateComponents(year: 2026, month: 10, day: 5))
    }

    @Test func importsIncomesIntoDestination() throws {
        try importCSV(("incomes.csv", """
            date;amount;destination;category;details
            01.10.2026;2000;Bank;Salary;October
            """))

        let income = try #require(try transactions().first)
        #expect(income.kind == .income)
        #expect(income.source == nil)
        #expect(income.destination?.name == "Bank")
        #expect(income.category?.categoryKind == .income)
    }

    @Test func importsTransfersWithoutCategory() throws {
        try importCSV(("transfers.csv", """
            date;amount;source;target;details
            01.10.2026;50;Bank;Cash;ATM
            """))

        let transfer = try #require(try transactions().first)
        #expect(transfer.kind == .transfer)
        #expect(transfer.source?.name == "Bank")
        #expect(transfer.destination?.name == "Cash")
        #expect(transfer.category == nil)
    }

    @Test(arguments: [
        ("12,50", "12.5"),
        ("12.50", "12.5"),
        ("1.234,56", "1234.56"),
        ("-45,00", "45"),
        ("€ 7,99", "7.99"),
    ])
    func parsesAmountFormats(raw: String, expected: String) throws {
        try importCSV(("expenses.csv", "date;amount;source;category;details\n01.10.2026;\(raw);Cash;Food;\n"))
        #expect(try transactions().first?.amount == Decimal(string: expected))
    }

    @Test func acceptsDateWithTrailingDotAndByteOrderMark() throws {
        let result = try importCSV(("expenses.csv", "\u{FEFF}date;amount;source;category;details\n05.10.2026.;1;Cash;Food;\n"))
        #expect(result.importedCount == 1)
        #expect(dayComponents(try #require(try transactions().first).date) == DateComponents(year: 2026, month: 10, day: 5))
    }

    @Test func headerIsCaseInsensitiveAndFieldsAreTrimmed() throws {
        try importCSV(("export.csv", """
            Date;Amount;Source;Category;Details
             05.10.2026 ; "12,50" ; Cash ;Food; Lunch
            """))
        let expense = try #require(try transactions().first)
        #expect(expense.amount == decimal("12.5"))
        #expect(expense.source?.name == "Cash")
        #expect(expense.note == "Lunch")
    }

    @Test func invalidLinesAreReportedWithTheirLineNumbers() throws {
        let result = try importCSV(("expenses.csv", """
            date;amount;source;category;details
            05.10.2026;10;Cash;Food;ok

            not a date;10;Cash;Food;bad date
            05.10.2026;abc;Cash;Food;bad amount
            05.10.2026;10;;Food;no account
            06.10.2026;20;Cash;;no category is fine
            """))

        #expect(result.importedCount == 2)
        #expect(result.skippedLines == ["expenses.csv": [4, 5, 6]])
        #expect(result.skippedCount == 3)
        #expect(try transactions().last?.category == nil)
    }

    @Test func existingAccountsAndCategoriesAreReusedIgnoringCase() throws {
        let cash = Source(name: "Cash")
        let food = Category(name: "Food", categoryKind: .expense)
        context.insert(cash)
        context.insert(food)
        try context.save()

        let result = try importCSV(("expenses.csv", "date;amount;source;category;details\n05.10.2026;10; cash ;FOOD;\n"))

        #expect(result.createdSources == 0)
        #expect(result.createdCategories == 0)
        let expense = try #require(try transactions().first)
        #expect(expense.source === cash)
        #expect(expense.category === food)
    }

    @Test func categoriesWithSameNameAreSeparatedByKind() throws {
        try importCSV(
            ("expenses.csv", "date;amount;source;category;details\n05.10.2026;10;Cash;Other;\n"),
            ("incomes.csv", "date;amount;destination;category;details\n05.10.2026;10;Cash;Other;\n")
        )
        let categories = try context.fetch(FetchDescriptor<Ledger.Category>())
        #expect(Set(categories.map(\.categoryKind)) == [.expense, .income])
        #expect(categories.allSatisfy { $0.name == "Other" })
    }

    @Test(arguments: ["", "foo;bar\n1;2\n", "date;amount;note\n01.10.2026;1;x\n"])
    func unknownFormatThrows(text: String) throws {
        #expect(throws: CSVImportError.self) {
            try importCSV(("mystery.csv", text))
        }
        #expect(try transactions().isEmpty)
    }

    @Test func accountsFileSetsDetails() throws {
        let result = try importCSV(("accounts.csv", """
            name;initial_value;icon;color
            Savings;-1.500,25;banknote;green
            Wallet;;;not-a-color
            """))

        #expect(result.createdSources == 2)
        let sources = try context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.name)]))
        #expect(sources.map(\.name) == ["Savings", "Wallet"])
        #expect(sources[0].initValue == decimal("-1500.25"), "Initial values keep their sign")
        #expect(sources[0].systemImage == "banknote")
        #expect(sources[0].color == .green)
        #expect(sources[1].initValue == 0)
        #expect(sources[1].systemImage == SourceDraft().systemImage)
        #expect(sources[1].color == SourceDraft().color)
    }

    @Test func accountsAreImportedBeforeTransactionsRegardlessOfFileOrder() throws {
        let result = try importCSV(
            ("expenses.csv", "date;amount;source;category;details\n05.10.2026;10;Savings;Food;\n"),
            ("accounts.csv", "name;initial_value;icon;color\nSavings;100;banknote;green\n")
        )
        #expect(result.createdSources == 1)
        let savings = try #require(try transactions().first?.source)
        #expect(savings.initValue == 100)
        #expect(savings.color == .green)
    }

    @Test func categoriesFileRequiresAValidKind() throws {
        let result = try importCSV(("categories.csv", """
            name;kind;icon;color
            Food;expense;fork.knife;orange
            Salary;income;briefcase;green
            Broken;spending;tag;red
            """))
        #expect(result.createdCategories == 2)
        #expect(result.skippedLines["categories.csv"] == [4])
    }

    @Test func budgetsLinkToExpenseCategories() throws {
        try importCSV(("budgets.csv", """
            category;limit;active
            ;500;true
            Food;200;false
            """))

        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let generalBudget = budgets.first(where: \.isGeneral)
        let foodBudget = budgets.first { !$0.isGeneral }
        let general = try #require(generalBudget)
        let food = try #require(foodBudget)
        #expect(general.limit == 500)
        #expect(general.isActive)
        #expect(food.limit == 200)
        #expect(!food.isActive)
        #expect(food.category?.name == "Food")
        #expect(food.category?.categoryKind == .expense)
    }

    @Test func plannedTransactionsMarkPastOccurrencesAsGenerated() throws {
        try importCSV(("planned_transactions.csv", """
            kind;amount;source;destination;category;frequency;interval;start_date;end_date;paused;details
            expense;9,99;Card;;Streaming;monthly;1;01.01.2020;31.12.2020;false;Netflix
            income;100;;Bank;Salary;weekly;2;01.01.2100;;true;Future
            """))

        let planned = try context.fetch(FetchDescriptor<PlannedTransaction>(sortBy: [SortDescriptor(\.startDate)]))
        #expect(planned.count == 2)
        #expect(planned[0].occurrencesGenerated == 12)
        #expect(planned[0].note == "Netflix")
        #expect(planned[0].source?.name == "Card")
        #expect(planned[0].category?.name == "Streaming")
        #expect(planned[1].occurrencesGenerated == 0)
        #expect(planned[1].interval == 2)
        #expect(planned[1].isPaused)
        #expect(planned[1].destination?.name == "Bank")

        // The past occurrences come from the exported transactions, so none are generated again.
        try RecurrenceEngine.generateDue(in: context)
        #expect(try transactions().isEmpty)
    }

    @Test func plannedTransactionsNeedAnAccount() throws {
        let result = try importCSV(("planned_transactions.csv", """
            kind;amount;source;destination;category;frequency;interval;start_date;end_date;paused;details
            expense;10;;;Food;monthly;1;01.01.2100;;false;
            expense;10;Cash;;Food;fortnightly;1;01.01.2100;;false;
            """))
        #expect(result.skippedLines["planned_transactions.csv"] == [2, 3])
    }

    @Test func reimportingDoesNotDuplicateAccountsCategoriesBudgetsOrPlans() throws {
        let files: [(name: String, text: String)] = [
            ("accounts.csv", "name;initial_value;icon;color\nCash;0;banknote;green\n"),
            ("categories.csv", "name;kind;icon;color\nFood;expense;fork.knife;orange\n"),
            ("budgets.csv", "category;limit;active\nFood;200;true\n"),
            ("planned_transactions.csv", """
                kind;amount;source;destination;category;frequency;interval;start_date;end_date;paused;details
                expense;10;Cash;;Food;monthly;1;01.01.2100;;false;Gym
                """),
        ]
        let urls = try writeCSVFiles(files)
        _ = try CSVImporter.importFiles(urls, into: context)
        let second = try CSVImporter.importFiles(urls, into: context)

        #expect(second.createdSources == 0)
        #expect(second.createdCategories == 0)
        #expect(second.skippedCount == 0)
        #expect(try context.fetchCount(FetchDescriptor<Source>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Ledger.Category>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Budget>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PlannedTransaction>()) == 1)
    }

    @Test func collectionTransactionsLinkMatchingTransactions() throws {
        let result = try importCSV(
            ("expenses.csv", """
                date;amount;source;category;details
                05.10.2026;10;Cash;Food;Coffee
                05.10.2026;10;Cash;Food;Coffee
                06.10.2026;99;Cash;Food;Hotel
                """),
            ("collections.csv", "name;icon;color\nTrip;airplane;teal\n"),
            ("collection_transactions.csv", """
                collection;transaction_date;transaction_kind;transaction_amount;transaction_source;transaction_destination;transaction_details
                Trip;05.10.2026;expense;10;Cash;;Coffee
                Trip;05.10.2026;expense;10;Cash;;Coffee
                Trip;05.10.2026;expense;10;Cash;;Coffee
                Trip;07.10.2026;expense;10;Cash;;Missing
                """)
        )

        let collection = try #require(try context.fetch(FetchDescriptor<TransactionCollection>()).first)
        #expect(collection.name == "Trip")
        #expect(collection.systemImage == "airplane")
        #expect(collection.color == .teal)
        // Two identical coffees are each added once; the third line is a duplicate.
        #expect(collection.transactions.count == 2)
        #expect(collection.transactions.allSatisfy { $0.note == "Coffee" })
        #expect(result.skippedLines["collection_transactions.csv"] == [5])
    }

    @Test func receiptItemsAttachToTheirTransaction() throws {
        let result = try importCSV(
            ("expenses.csv", "date;amount;source;category;details\n05.10.2026;3,48;Cash;Food;Konzum\n"),
            ("receipt_items.csv", """
                transaction_date;transaction_kind;transaction_amount;transaction_source;transaction_destination;transaction_details;position;name;quantity;unit_price;total_price
                05.10.2026;expense;3.48;Cash;;Konzum;0;MLIJEKO 1L;2;1,29;2,58
                05.10.2026;expense;3.48;Cash;;Konzum;1;KRUH;;;0,90
                05.10.2026;expense;3.48;Cash;;Konzum;1;KRUH;;;0,90
                05.10.2026;expense;9.99;Cash;;Other;0;ORPHAN;1;1;1
                """)
        )

        let items = try #require(try transactions().first?.receiptItems).sorted { $0.position < $1.position }
        #expect(items.map(\.name) == ["MLIJEKO 1L", "KRUH"])
        #expect(items[0].quantity == 2)
        #expect(items[0].unitPrice == decimal("1.29"))
        #expect(items[0].totalPrice == decimal("2.58"))
        #expect(items[0].normalizedName == "mlijeko 1l")
        #expect(items[1].quantity == 1, "Missing quantity defaults to one")
        #expect(result.skippedLines["receipt_items.csv"] == [5])
    }

    @Test func referencesMatchTransactionsAlreadyInTheStore() throws {
        let existing = Transaction(amount: 10, kind: .expense, source: Source(name: "Cash"), note: "Coffee", date: date(2026, 10, 5, hour: 9))
        context.insert(existing)
        try context.save()

        try importCSV(("collection_transactions.csv", """
            collection;transaction_date;transaction_kind;transaction_amount;transaction_source;transaction_destination;transaction_details
            Morning;05.10.2026;expense;10;cash;;Coffee
            """))

        let collection = try #require(try context.fetch(FetchDescriptor<TransactionCollection>()).first)
        #expect(collection.name == "Morning")
        #expect(collection.transactions.first === existing)
    }
}

@MainActor
struct CSVExporterTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try makeTestContainer()
    }

    private func files() throws -> [String: String] {
        let export = try CSVExporter.makeFiles(from: context)
        return Dictionary(uniqueKeysWithValues: export.files.map { ($0.fileName, $0.text) })
    }

    @Test func emptyStoreExportsNothing() throws {
        let export = try CSVExporter.makeFiles(from: context)
        #expect(export.files.isEmpty)
        #expect(export.count == 0)
    }

    @Test func writesOneFilePerTransactionKind() throws {
        let cash = Source(name: "Cash")
        let bank = Source(name: "Bank")
        let food = Category(name: "Food")
        context.insert(Transaction(amount: decimal("1234.5"), kind: .expense, source: cash, note: "Lunch", date: date(2026, 10, 5), category: food))
        context.insert(Transaction(amount: 50, kind: .transfer, source: bank, destination: cash, note: "", date: date(2026, 10, 6)))
        try context.save()

        let export = try CSVExporter.makeFiles(from: context)
        let texts = Dictionary(uniqueKeysWithValues: export.files.map { ($0.fileName, $0.text) })

        #expect(export.count == 2)
        #expect(texts["incomes.csv"] == nil)
        #expect(texts["expenses.csv"] == "date;amount;source;category;details\n05.10.2026;1234.5;Cash;Food;Lunch\n")
        #expect(texts["transfers.csv"] == "date;amount;source;target;details\n06.10.2026;50;Bank;Cash;\n")
    }

    @Test func escapesSeparatorsQuotesAndNewlines() throws {
        context.insert(Transaction(
            amount: 1, kind: .income, destination: Source(name: "Bank"),
            note: "Gift; from \"Mom\"\nthanks", date: date(2026, 10, 5)
        ))
        try context.save()

        let line = try #require(try files()["incomes.csv"]?.split(separator: "\n").last)
        #expect(line == "05.10.2026;1;Bank;;Gift, from 'Mom' thanks")
    }

    @Test func generalBudgetHasEmptyCategory() throws {
        context.insert(Budget(limit: 500))
        context.insert(Budget(limit: decimal("200.5"), isActive: false, category: Category(name: "Food")))
        try context.save()

        #expect(try files()["budgets.csv"] == "category;limit;active\n;500;true\nFood;200.5;false\n")
    }
}

/// Exports a populated store and imports it into an empty one.
@MainActor
struct CSVRoundTripTests {
    let source: ModelContainer
    let target: ModelContainer

    init() throws {
        source = try makeTestContainer()
        target = try makeTestContainer()
    }

    private func populateSource() throws {
        let context = source.mainContext
        let cash = Source(name: "Cash", systemImage: "banknote", initValue: 100, color: .green)
        let card = Source(name: "Card", systemImage: "creditcard", initValue: decimal("-20.5"), color: .red)
        let food = Category(name: "Food", systemImage: "fork.knife", color: .orange, categoryKind: .expense)
        let salary = Category(name: "Salary", systemImage: "briefcase", color: .mint, categoryKind: .income)
        [cash, card].forEach(context.insert)
        [food, salary].forEach(context.insert)

        let lunch = Transaction(amount: decimal("12.5"), kind: .expense, source: cash, note: "Lunch; with \"friends\"", date: date(2026, 10, 5), category: food)
        let pay = Transaction(amount: 2000, kind: .income, destination: card, note: "October", date: date(2026, 10, 1), category: salary)
        let atm = Transaction(amount: 50, kind: .transfer, source: card, destination: cash, note: "ATM", date: date(2026, 10, 2))
        [lunch, pay, atm].forEach(context.insert)

        let item = ReceiptItem(name: "Soup", quantity: 1, unitPrice: decimal("12.5"), totalPrice: decimal("12.5"), position: 0)
        context.insert(item)
        item.transaction = lunch

        context.insert(TransactionCollection(name: "Trip", systemImage: "airplane", color: .teal, transactions: [lunch, atm]))
        context.insert(Budget(limit: 500))
        context.insert(Budget(limit: 200, isActive: false, category: food))
        context.insert(PlannedTransaction(
            amount: 2000, kind: .income, destination: card, note: "Salary", category: salary,
            frequency: .monthly, interval: 1, startDate: date(2100, 1, 1), occurrencesGenerated: 0, isPaused: false
        ))
        try context.save()
    }

    @Test func everythingSurvivesExportAndImport() throws {
        try populateSource()
        let export = try CSVExporter.makeFiles(from: source.mainContext)
        let urls = try writeCSVFiles(export.files.map { ($0.fileName, $0.text) })

        let context = target.mainContext
        let result = try CSVImporter.importFiles(urls, into: context)

        #expect(result.importedCount == export.count)
        #expect(result.skippedCount == 0)

        let sources = try context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.name)]))
        #expect(sources.map(\.name) == ["Card", "Cash"])
        #expect(sources.map(\.initValue) == [decimal("-20.5"), 100])
        #expect(sources.map(\.color) == [.red, .green])
        #expect(sources.map(\.systemImage) == ["creditcard", "banknote"])

        let categories = try context.fetch(FetchDescriptor<Ledger.Category>(sortBy: [SortDescriptor(\.name)]))
        #expect(categories.map(\.name) == ["Food", "Salary"])
        #expect(categories.map(\.categoryKind) == [.expense, .income])
        #expect(categories.map(\.color) == [.orange, .mint])

        let transactions = try context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)]))
        #expect(transactions.map(\.kind) == [.income, .transfer, .expense])
        #expect(transactions.map(\.amount) == [2000, 50, decimal("12.5")])
        #expect(transactions.map { $0.source?.name } == [nil, "Card", "Cash"])
        #expect(transactions.map { $0.destination?.name } == ["Card", "Cash", nil])
        #expect(transactions.map { $0.category?.name } == ["Salary", nil, "Food"])
        #expect(transactions[2].note == "Lunch, with 'friends'")

        let lunch = transactions[2]
        #expect(lunch.receiptItems?.map(\.name) == ["Soup"])

        let collection = try #require(try context.fetch(FetchDescriptor<TransactionCollection>()).first)
        #expect(collection.name == "Trip")
        #expect(Set(collection.transactions.map(\.note)) == ["ATM", "Lunch, with 'friends'"])

        let budgets = try context.fetch(FetchDescriptor<Budget>())
        #expect(budgets.count == 2)
        #expect(budgets.first(where: \.isGeneral)?.limit == 500)
        #expect(budgets.first { !$0.isGeneral }?.category?.name == "Food")
        #expect(budgets.first { !$0.isGeneral }?.isActive == false)

        let planned = try #require(try context.fetch(FetchDescriptor<PlannedTransaction>()).first)
        #expect(planned.amount == 2000)
        #expect(planned.kind == .income)
        #expect(planned.destination?.name == "Card")
        #expect(planned.category?.name == "Salary")
        #expect(dayComponents(planned.startDate) == DateComponents(year: 2100, month: 1, day: 1))
    }
}
