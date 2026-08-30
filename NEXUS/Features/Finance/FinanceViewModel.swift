import Foundation
import SwiftData

struct FinanceSummary: Equatable {
    let incomeMinorUnits: Int
    let expenseMinorUnits: Int
    let budgetMinorUnits: Int?
    let receivableMinorUnits: Int
    let payableMinorUnits: Int
    var balanceMinorUnits: Int { incomeMinorUnits - expenseMinorUnits }
    var budgetRemainingMinorUnits: Int? { budgetMinorUnits.map { $0 - expenseMinorUnits } }
    var netDebtPositionMinorUnits: Int { receivableMinorUnits - payableMinorUnits }
}

enum FinanceSection: String, CaseIterable, Identifiable { case overview, transactions, debts, recurring, settings; var id: String { rawValue }; var titleKey: String { "finance.section.\(rawValue)" } }
enum FinanceSort: String, CaseIterable, Identifiable { case newest, oldest, amount; var id: String { rawValue }; var titleKey: String { "finance.sort.\(rawValue)" } }

@MainActor
final class FinanceViewModel: ObservableObject {
    @Published var section: FinanceSection = .overview
    @Published var searchText = ""
    @Published var typeFilter: FinanceTransactionType?
    @Published var debtStatusFilter: DebtStatus?
    @Published var recurringActiveOnly = false
    @Published var sort: FinanceSort = .newest
    @Published var selectedMonth = Date.now
    @Published var errorMessage: String?
    @Published var statusMessageKey = "status.ready"

    func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }

    func summary(entries: [FinanceEntry], debts: [DebtRecord], budgets: [MonthlyBudget], month: Date, currencyCode: String? = nil, calendar: Calendar = .current) -> FinanceSummary {
        let interval = monthInterval(containing: month, calendar: calendar)
        let monthly = entries.filter { interval.contains($0.date) && (currencyCode == nil || $0.currencyCode == currencyCode) }
        let income = monthly.filter { $0.type == .income }.reduce(0) { $0 + $1.normalizedAmountMinorUnits }
        let expense = monthly.filter { $0.type == .expense }.reduce(0) { $0 + $1.normalizedAmountMinorUnits }
        let budget = budgets.first { interval.contains($0.monthStart) && (currencyCode == nil || $0.currencyCode == currencyCode) }?.amountMinorUnits
        let active = debts.filter { $0.status == .outstanding && (currencyCode == nil || $0.currencyCode == currencyCode) }
        let receivable = active.filter { $0.direction == .owedToUser }.reduce(0) { $0 + abs($1.amountMinorUnits) }
        let payable = active.filter { $0.direction == .owedByUser }.reduce(0) { $0 + abs($1.amountMinorUnits) }
        return FinanceSummary(incomeMinorUnits: income, expenseMinorUnits: expense, budgetMinorUnits: budget, receivableMinorUnits: receivable, payableMinorUnits: payable)
    }

    func filtered(_ entries: [FinanceEntry]) -> [FinanceEntry] {
        let interval = monthInterval(containing: selectedMonth)
        return entries.filter { entry in
            interval.contains(entry.date) && (typeFilter == nil || entry.type == typeFilter) &&
            (searchText.isEmpty || entry.title.localizedCaseInsensitiveContains(searchText) || entry.category.localizedCaseInsensitiveContains(searchText))
        }.sorted { lhs, rhs in
            switch sort { case .newest: lhs.date > rhs.date; case .oldest: lhs.date < rhs.date; case .amount: lhs.normalizedAmountMinorUnits > rhs.normalizedAmountMinorUnits }
        }
    }

    func saveEntry(_ entry: FinanceEntry?, title: String, amount: Double, type: FinanceTransactionType, date: Date, currency: String, category: String, context: ModelContext) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FinanceValidationError.titleRequired }
        guard amount > 0, amount.isFinite else { throw FinanceValidationError.positiveAmountRequired }
        let minor = Int((amount * 100).rounded())
        if let entry { entry.title = title; entry.amountMinorUnits = minor; entry.type = type; entry.date = date; entry.currencyCode = currency; entry.category = category; entry.updatedAt = .now }
        else { context.insert(FinanceEntry(date: date, title: title, amountMinorUnits: minor, currencyCode: currency, category: category, type: type)) }
        try commit(context)
    }

    func saveDebt(_ debt: DebtRecord?, counterparty: String, amount: Double, currency: String, direction: DebtDirection, dueDate: Date?, status: DebtStatus, note: String, context: ModelContext) throws {
        guard !counterparty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FinanceValidationError.counterpartyRequired }
        guard amount > 0, amount.isFinite else { throw FinanceValidationError.positiveAmountRequired }
        let minor = Int((amount * 100).rounded())
        if let debt { debt.counterparty = counterparty; debt.amountMinorUnits = minor; debt.currencyCode = currency; debt.direction = direction; debt.dueDate = dueDate; debt.status = status; debt.note = note; debt.updatedAt = .now }
        else { context.insert(DebtRecord(counterparty: counterparty, amountMinorUnits: minor, currencyCode: currency, direction: direction, dueDate: dueDate, status: status, note: note)) }
        try commit(context)
    }

    func saveBudget(_ existing: MonthlyBudget?, amount: Double, month: Date, currency: String, context: ModelContext) throws {
        guard amount >= 0, amount.isFinite else { throw FinanceValidationError.nonnegativeAmountRequired }
        let start = Calendar.current.dateInterval(of: .month, for: month)?.start ?? month
        if let existing { existing.monthStart = start; existing.amountMinorUnits = Int((amount * 100).rounded()); existing.currencyCode = currency; existing.updatedAt = .now }
        else { context.insert(MonthlyBudget(monthStart: start, amountMinorUnits: Int((amount * 100).rounded()), currencyCode: currency)) }
        try commit(context)
    }

    func saveCategory(name: String, type: FinanceTransactionType, context: ModelContext) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FinanceValidationError.titleRequired }
        context.insert(FinanceCategory(name: name, type: type)); try commit(context)
    }

    func saveRecurring(_ record: RecurringTransaction?, title: String, amount: Double, currency: String, type: FinanceTransactionType, nextDate: Date, cadence: RecurrenceCadence, active: Bool, note: String, context: ModelContext) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FinanceValidationError.titleRequired }
        guard amount > 0, amount.isFinite else { throw FinanceValidationError.positiveAmountRequired }
        let minor = Int((amount * 100).rounded())
        if let record { record.title = title; record.amountMinorUnits = minor; record.currencyCode = currency; record.type = type; record.nextDate = nextDate; record.cadence = cadence; record.isActive = active; record.note = note; record.updatedAt = .now }
        else { context.insert(RecurringTransaction(title: title, amountMinorUnits: minor, currencyCode: currency, type: type, startDate: .now, nextDate: nextDate, cadence: cadence, isActive: active, note: note)) }
        try commit(context)
    }

    func delete<T: PersistentModel>(_ model: T, context: ModelContext) throws { context.delete(model); try commit(context) }
    private func commit(_ context: ModelContext) throws { do { try context.save(); errorMessage = nil; statusMessageKey = "status.saved" } catch { errorMessage = error.localizedDescription; statusMessageKey = "status.saveFailed"; throw error } }
}

enum FinanceValidationError: LocalizedError {
    case titleRequired, counterpartyRequired, positiveAmountRequired, nonnegativeAmountRequired
    var errorDescription: String? { switch self { case .titleRequired: String(localized: "finance.validation.title"); case .counterpartyRequired: String(localized: "finance.validation.counterparty"); case .positiveAmountRequired: String(localized: "finance.validation.amount"); case .nonnegativeAmountRequired: String(localized: "finance.validation.nonnegative") } }
}
