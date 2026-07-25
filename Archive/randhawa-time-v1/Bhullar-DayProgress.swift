import Foundation

/// An immutable snapshot of how far through the 24-hour day a given moment is.
///
/// Every value derives purely from the date and the user's current calendar, so
/// the app and the widget compute identical results with no shared storage,
/// network calls, or persisted state to keep in sync.
struct DayProgress: Equatable {
    /// 1-based ordinal of the hour within its day (the 00:00 to 00:59 hour == 1).
    let hourOfDay: Int

    /// Total number of hours in this day. Normally 24, but 23 or 25 on the days
    /// a daylight-saving transition adds or removes an hour; the calendar
    /// handles it for us, exactly as leap years give a year 366 days.
    let totalHours: Int

    /// Builds a snapshot for `date` using `calendar`.
    /// Defaults to the current moment and the user's current calendar.
    init(date: Date = Date(), calendar: Calendar = .current) {
        let ordinal = calendar.ordinality(of: .hour, in: .day, for: date) ?? 1
        let total = calendar.range(of: .hour, in: .day, for: date)?.count ?? 24
        self.totalHours = max(total, 1)
        self.hourOfDay = min(max(ordinal, 1), self.totalHours)
    }

    /// Fraction of the day elapsed, counting the current hour as complete.
    /// Range: `(0, 1]`.
    var fraction: Double { Double(hourOfDay) / Double(totalHours) }

    /// Whole-percent elapsed, rounded down, so it only reads 100% during the
    /// final hour of the day.
    var percent: Int { Int(fraction * 100) }

    /// Hours left in the day, including 0 during the final hour.
    var hoursRemaining: Int { totalHours - hourOfDay }
}
