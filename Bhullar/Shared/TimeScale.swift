import Foundation

/// An immutable snapshot of a position within a span of time: unit `index` of
/// `total`, e.g. day 183 of 365, or hour 15 of 24.
///
/// Every value derives purely from the date and the user's current calendar, so
/// the app and the widget compute identical results with no shared storage,
/// network calls, or persisted state to keep in sync.
struct ScalePosition: Equatable {
    /// 1-based ordinal of the unit within its span.
    let index: Int

    /// Total number of units in the span. The calendar supplies the real count,
    /// so leap years give 366 days and daylight-saving days give 23 or 25 hours
    /// without any special cases here.
    let total: Int

    init(index: Int, total: Int) {
        self.total = max(total, 1)
        self.index = min(max(index, 1), self.total)
    }

    /// Fraction of the span elapsed, counting the current unit as complete.
    /// Range: `(0, 1]`.
    var fraction: Double { Double(index) / Double(total) }

    /// Whole-percent elapsed, rounded down, so it only reads 100% during the
    /// final unit of the span.
    var percent: Int { Int(fraction * 100) }

    /// Units left in the span, including 0 during the final unit.
    var remaining: Int { total - index }
}

/// The five zoom levels of the time telescope. Three carve up the year at
/// increasing resolution; the last two drop into the current day.
enum TimeScale: String, CaseIterable {
    case months
    case weeks
    case days
    case hours
    case minutes

    /// Singular unit name for captions ("Day 183 of 365").
    var unitName: String {
        switch self {
        case .months: return "Month"
        case .weeks: return "Week"
        case .days: return "Day"
        case .hours: return "Hour"
        case .minutes: return "Minute"
        }
    }

    /// Plural unit name for captions ("182 days left").
    var unitNamePlural: String {
        switch self {
        case .months: return "months"
        case .weeks: return "weeks"
        case .days: return "days"
        case .hours: return "hours"
        case .minutes: return "minutes"
        }
    }

    /// The next scale in the zoom cycle, finer, wrapping at the end.
    var next: TimeScale {
        let all = TimeScale.allCases
        let position = all.firstIndex(of: self) ?? 0
        return all[(position + 1) % all.count]
    }

    /// The previous scale in the zoom cycle, coarser, wrapping at the start.
    var previous: TimeScale {
        let all = TimeScale.allCases
        let position = all.firstIndex(of: self) ?? 0
        return all[(position + all.count - 1) % all.count]
    }

    /// The calendar component one dot stands for at this scale.
    var unit: Calendar.Component {
        switch self {
        case .months: return .month
        case .weeks: return .weekOfYear
        case .days: return .day
        case .hours: return .hour
        case .minutes: return .minute
        }
    }

    /// The span of time that dot number `index` covers, in the year (or the
    /// day) that `date` belongs to. This is the inverse of `position`, and it
    /// is what lets a tapped dot become a question with an answer: what
    /// happened between these two instants.
    ///
    /// Built by walking forward from the start of the span rather than by
    /// arithmetic, so leap years, daylight saving, and short months come out
    /// of the calendar instead of being special-cased here.
    func interval(ofUnit index: Int, containing date: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        guard let anchor = spanStart(containing: date, calendar: calendar),
              let start = calendar.date(byAdding: unit, value: index - 1, to: anchor),
              let end = calendar.date(byAdding: unit, value: 1, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// The first instant of the span this scale divides: the start of the year
    /// for the year scales, the start of the day for the day scales.
    private func spanStart(containing date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .months, .days:
            return calendar.dateInterval(of: .year, for: date)?.start
        case .weeks:
            // Weeks are ordinal within the year but do not start on 1 January,
            // so the first week's own start is the anchor. Without this, week
            // N would be offset by however many days the year began mid-week.
            guard let yearStart = calendar.dateInterval(of: .year, for: date)?.start else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: yearStart)?.start
        case .hours, .minutes:
            return calendar.startOfDay(for: date)
        }
    }

    /// A human label for one dot, used as the title when a dot is opened.
    func label(ofUnit index: Int, containing date: Date = Date(), calendar: Calendar = .current) -> String {
        guard let interval = interval(ofUnit: index, containing: date, calendar: calendar) else {
            return "\(unitName) \(index)"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        switch self {
        case .months:
            formatter.setLocalizedDateFormatFromTemplate("MMMM y")
        case .weeks:
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            let end = interval.end.addingTimeInterval(-1)
            return formatter.string(from: interval.start) + " to " + formatter.string(from: end)
        case .days:
            formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        case .hours:
            formatter.setLocalizedDateFormatFromTemplate("jmm")
        case .minutes:
            formatter.setLocalizedDateFormatFromTemplate("jmm")
        }
        return formatter.string(from: interval.start)
    }

    /// Where `date` falls on this scale, per `calendar`.
    /// Defaults to the current moment and the user's current calendar.
    func position(date: Date = Date(), calendar: Calendar = .current) -> ScalePosition {
        let unit: Calendar.Component
        let span: Calendar.Component
        let fallbackTotal: Int
        switch self {
        case .months:
            unit = .month; span = .year; fallbackTotal = 12
        case .weeks:
            unit = .weekOfYear; span = .year; fallbackTotal = 52
        case .days:
            unit = .day; span = .year; fallbackTotal = 365
        case .hours, .minutes:
            // Count real elapsed units between midnights: on daylight-saving
            // days the day genuinely has 23 or 25 hours (1380 or 1500 minutes),
            // which range(of: .hour, in: .day) does not report (it always
            // says 24).
            let secondsPerUnit: Double = self == .hours ? 3600 : 60
            let start = calendar.startOfDay(for: date)
            let next = calendar.date(byAdding: .day, value: 1, to: start)
                ?? start.addingTimeInterval(86_400)
            let total = Int((next.timeIntervalSince(start) / secondsPerUnit).rounded())
            let index = Int(date.timeIntervalSince(start) / secondsPerUnit) + 1
            return ScalePosition(index: index, total: total)
        }
        let ordinal = calendar.ordinality(of: unit, in: span, for: date) ?? 1
        let total = calendar.range(of: unit, in: span, for: date)?.count ?? fallbackTotal
        return ScalePosition(index: ordinal, total: total)
    }
}
