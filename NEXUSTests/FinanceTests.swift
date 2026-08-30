import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class FinanceTests: XCTestCase {
    func testMonthlyBalanceBudgetAndDebtSemantics() throws {
        let viewModel = FinanceViewModel()
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let month = try XCTUnwrap(DateComponents(calendar: calendar, year: 2026, month: 8, day: 10).date)
        let entries = [
            FinanceEntry(date: month, title: "Burs", amountMinorUnits: 10_000, type: .income),
            FinanceEntry(date: month, title: "Kira", amountMinorUnits: 4_000, type: .expense),
            FinanceEntry(date: month, title: "Dolar", amountMinorUnits: 99_000, currencyCode: "USD", type: .income),
            FinanceEntry(date: calendar.date(byAdding: .month, value: -1, to: month)!, title: "Eski", amountMinorUnits: 9_000, type: .expense)
        ]
        let debts = [DebtRecord(counterparty: "A", amountMinorUnits: 2_500, direction: .owedToUser), DebtRecord(counterparty: "B", amountMinorUnits: 1_000, direction: .owedByUser), DebtRecord(counterparty: "C", amountMinorUnits: 8_000, direction: .owedByUser, status: .paid)]
        let result = viewModel.summary(entries: entries, debts: debts, budgets: [MonthlyBudget(monthStart: month, amountMinorUnits: 5_000)], month: month, currencyCode: "TRY", calendar: calendar)
        XCTAssertEqual(result.incomeMinorUnits, 10_000); XCTAssertEqual(result.expenseMinorUnits, 4_000)
        XCTAssertEqual(result.balanceMinorUnits, 6_000); XCTAssertEqual(result.budgetRemainingMinorUnits, 1_000)
        XCTAssertEqual(result.receivableMinorUnits, 2_500); XCTAssertEqual(result.payableMinorUnits, 1_000); XCTAssertEqual(result.netDebtPositionMinorUnits, 1_500)
    }

    func testFinanceCRUDValidationAndPersistence() throws {
        let container = try PersistenceController.makeContainer(inMemory: true); let context = container.mainContext; let viewModel = FinanceViewModel()
        try viewModel.saveEntry(nil, title: "Yemek", amount: 125.50, type: .expense, date: .now, currency: "TRY", category: "Yaşam", context: context)
        let entry = try XCTUnwrap(context.fetch(FetchDescriptor<FinanceEntry>()).first)
        XCTAssertEqual(entry.amountMinorUnits, 12_550); XCTAssertEqual(entry.type, .expense)
        try viewModel.saveDebt(nil, counterparty: "Deniz", amount: 200, currency: "TRY", direction: .owedToUser, dueDate: nil, status: .outstanding, note: "", context: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DebtRecord>()).first?.direction, .owedToUser)
        XCTAssertThrowsError(try viewModel.saveEntry(nil, title: "", amount: 1, type: .income, date: .now, currency: "TRY", category: "", context: context))
        XCTAssertThrowsError(try viewModel.saveDebt(nil, counterparty: "A", amount: 0, currency: "TRY", direction: .owedByUser, dueDate: nil, status: .outstanding, note: "", context: context))
        try viewModel.delete(entry, context: context); XCTAssertTrue(try context.fetch(FetchDescriptor<FinanceEntry>()).isEmpty)
    }

    func testVersionFourBackupRoundTripsFinanceEntities() throws {
        let source = try PersistenceController.makeContainer(inMemory: true); let context = source.mainContext
        let category = FinanceCategory(name: "Ulaşım"); context.insert(category)
        context.insert(FinanceEntry(title: "Otobüs", amountMinorUnits: 500, category: "Ulaşım", type: .expense, categoryID: category.id))
        context.insert(MonthlyBudget(monthStart: .now, amountMinorUnits: 50_000)); context.insert(DebtRecord(counterparty: "Ece", amountMinorUnits: 1_000, direction: .owedToUser))
        context.insert(RecurringTransaction(title: "Burs", amountMinorUnits: 20_000, type: .income)); try context.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: context)))
        XCTAssertEqual(backup.schemaVersion, 9); XCTAssertEqual(backup.financeEntries?.count, 1); XCTAssertEqual(backup.debtRecords?.count, 1)
        let destination = try PersistenceController.makeContainer(inMemory: true); try BackupService.apply(backup, mode: .replace, to: destination.mainContext)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<FinanceCategory>()).count, 1); XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<RecurringTransaction>()).count, 1)
    }
}
