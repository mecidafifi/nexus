import Foundation

enum DailyPlanPresentationPolicy {
    static let defaultMode: DailyPlanMode = .week

    static func defaultSelectedDate(now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    /// HAFTA is an operational horizon, not a calendar-week bucket. Manual
    /// previous/next navigation moves this anchor by seven days; a new Home
    /// presentation always starts from the current local day.
    static func upcomingDates(starting anchor: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: anchor)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func rollingRangeTitle(starting anchor: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let dates = upcomingDates(starting: anchor, calendar: calendar)
        guard let first = dates.first, let last = dates.last else { return String(localized: "dailyPlan.weekStrip") }
        let range = "\(first.formatted(.dateTime.day().month(.abbreviated)))–\(last.formatted(.dateTime.day().month(.abbreviated)))"
        let key = calendar.isDate(first, inSameDayAs: now)
            ? "dailyPlan.rollingUpcomingFormat"
            : "dailyPlan.rollingRangeFormat"
        return String(format: String(localized: String.LocalizationValue(key)), range)
    }

    static func showsNetworkBackdrop(route: AppRoute?, controlSystemPresented: Bool) -> Bool {
        route == nil && !controlSystemPresented
    }

    static func pausesNetworkAnimation(reduceMotion: Bool) -> Bool {
        reduceMotion
    }
}

enum PrimaryWindowLaunchPolicy {
    static let didApplyDefaultMaximizeKey = "window.primaryDidApplyDefaultMaximize.v1"

    static func shouldApplyDefaultMaximize(hasAppliedDefault: Bool) -> Bool {
        !hasAppliedDefault
    }
}
