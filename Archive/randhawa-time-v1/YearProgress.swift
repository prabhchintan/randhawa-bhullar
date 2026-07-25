import Foundation

/// An immutable snapshot of how far through the calendar year a given date is.
///
/// Every value derives purely from the date and the user's current calendar, so
/// the app and the widget compute identical results with no shared storage,
/// network calls, or persisted state to keep in sync.
struct YearProgress: Equatable {
    /// 1-based ordinal of the day within its year (January 1 == 1).
    let dayOfYear: Int

    /// Total number of days in this year (365, or 366 in a leap year).
    let totalDays: Int

    /// Builds a snapshot for `date` using `calendar`.
    /// Defaults to the current moment and the user's current calendar.
    init(date: Date = Date(), calendar: Calendar = .current) {
        let ordinal = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let total = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
        self.totalDays = max(total, 1)
        self.dayOfYear = min(max(ordinal, 1), self.totalDays)
    }

    /// Fraction of the year elapsed, counting the current day as complete.
    /// Range: `(0, 1]`.
    var fraction: Double { Double(dayOfYear) / Double(totalDays) }

    /// Whole-percent elapsed, rounded down, so it only reads 100% on the
    /// final day of the year.
    var percent: Int { Int(fraction * 100) }

    /// Days left in the year, including 0 on the final day.
    var daysRemaining: Int { totalDays - dayOfYear }
}
