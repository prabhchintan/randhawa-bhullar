import AppIntents
import SwiftUI
import WidgetKit

/// A single point on a widget's timeline: where `date` falls on one time scale.
struct ScaleEntry: TimelineEntry {
    let date: Date
    let scale: TimeScale
    let position: ScalePosition
}

/// Supplies the day widget with one entry per hour.
struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScaleEntry {
        ScaleEntry(date: Date(), scale: .hours, position: TimeScale.hours.position())
    }

    func getSnapshot(in context: Context, completion: @escaping (ScaleEntry) -> Void) {
        completion(ScaleEntry(date: Date(), scale: .hours, position: TimeScale.hours.position()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScaleEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let hourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        let startOfHour = calendar.date(from: hourComponents) ?? now

        // One entry per hour for the next full day. WidgetKit advances through
        // them at the top of each hour; `.atEnd` makes it request a fresh window
        // once the last entry is reached, so the grid keeps ticking indefinitely
        // without relying on background refresh budget.
        var entries: [ScaleEntry] = []
        for hourOffset in 0..<24 {
            guard let hour = calendar.date(byAdding: .hour, value: hourOffset, to: startOfHour) else { continue }
            entries.append(ScaleEntry(
                date: hour,
                scale: .hours,
                position: TimeScale.hours.position(date: hour, calendar: calendar)
            ))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// Supplies the year widget with one entry per day.
struct YearProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScaleEntry {
        ScaleEntry(date: Date(), scale: .days, position: TimeScale.days.position())
    }

    func getSnapshot(in context: Context, completion: @escaping (ScaleEntry) -> Void) {
        completion(ScaleEntry(date: Date(), scale: .days, position: TimeScale.days.position()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScaleEntry>) -> Void) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // One entry per day for the next two weeks; same `.atEnd` trick as above,
        // advancing at local midnight instead of the top of the hour.
        var entries: [ScaleEntry] = []
        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            entries.append(ScaleEntry(
                date: day,
                scale: .days,
                position: TimeScale.days.position(date: day, calendar: calendar)
            ))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// One view renders both widgets; the entry's scale supplies the wording.
struct BhullarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScaleEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.scale.unitName) \(entry.position.index) · \(entry.position.percent)%")

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                DotGrid(position: entry.position, palette: .accessory, dotScale: 0.62, unitName: entry.scale.unitName)
                    .padding(2)
            }

        case .accessoryRectangular:
            HStack(spacing: 8) {
                DotGrid(position: entry.position, palette: .accessory, dotScale: 0.7, unitName: entry.scale.unitName)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.position.percent)%")
                        .font(.headline)
                    Text("\(entry.position.remaining) \(entry.scale.unitNamePlural) left")
                        .font(.caption2)
                }
            }

        default: // systemSmall, systemMedium, systemLarge
            DotGrid(position: entry.position, unitName: entry.scale.unitName)
        }
    }
}

/// One dot per hour of the day.
struct BhullarDayWidget: Widget {
    private let kind = "BhullarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            BhullarWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Day in Dots")
        .description("One dot for every hour of the day, filling in as the day passes.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

/// One dot per day of the year.
struct BhullarYearWidget: Widget {
    private let kind = "BhullarYearWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YearProvider()) { entry in
            BhullarWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Year in Dots")
        .description("One dot for every day of the year, filling in as the year passes.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Configurable widget

/// The scales the configurable widget offers. Minutes is deliberately absent:
/// WidgetKit refreshes on a budget measured in minutes, so a minute grid on
/// the Home Screen would read wrong most of the time.
enum WidgetScaleOption: String, AppEnum {
    case months
    case weeks
    case days
    case hours

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Scale"

    static var caseDisplayRepresentations: [WidgetScaleOption: DisplayRepresentation] = [
        .months: DisplayRepresentation(title: "Months", subtitle: "One dot per month of the year"),
        .weeks: DisplayRepresentation(title: "Weeks", subtitle: "One dot per week of the year"),
        .days: DisplayRepresentation(title: "Days", subtitle: "One dot per day of the year"),
        .hours: DisplayRepresentation(title: "Hours", subtitle: "One dot per hour of today"),
    ]

    var timeScale: TimeScale {
        switch self {
        case .months: return .months
        case .weeks: return .weeks
        case .days: return .days
        case .hours: return .hours
        }
    }
}

struct ScaleConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Scale"
    static var description = IntentDescription("Pick which units the dots count.")

    @Parameter(title: "Scale", default: .days)
    var scale: WidgetScaleOption
}

/// One provider serves every scale the user can configure; the entry cadence
/// follows the scale: hourly entries for the day window, daily for the year.
struct ConfigurableScaleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ScaleEntry {
        ScaleEntry(date: Date(), scale: .days, position: TimeScale.days.position())
    }

    func snapshot(for configuration: ScaleConfigurationIntent, in context: Context) async -> ScaleEntry {
        let scale = configuration.scale.timeScale
        return ScaleEntry(date: Date(), scale: scale, position: scale.position())
    }

    func timeline(for configuration: ScaleConfigurationIntent, in context: Context) async -> Timeline<ScaleEntry> {
        let scale = configuration.scale.timeScale
        let calendar = Calendar.current
        let now = Date()
        var entries: [ScaleEntry] = []

        if scale == .hours {
            // Advance at the top of each hour; same `.atEnd` windowing as the
            // fixed widgets.
            let hourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            let startOfHour = calendar.date(from: hourComponents) ?? now
            for hourOffset in 0..<24 {
                guard let hour = calendar.date(byAdding: .hour, value: hourOffset, to: startOfHour) else { continue }
                entries.append(ScaleEntry(
                    date: hour,
                    scale: scale,
                    position: scale.position(date: hour, calendar: calendar)
                ))
            }
        } else {
            // The year scales only change at local midnight.
            let startOfToday = calendar.startOfDay(for: now)
            for dayOffset in 0..<14 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                entries.append(ScaleEntry(
                    date: day,
                    scale: scale,
                    position: scale.position(date: day, calendar: calendar)
                ))
            }
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

/// One widget, any scale. Add it twice at two scales for the telescope feel.
struct BhullarScaleWidget: Widget {
    private let kind = "BhullarScaleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ScaleConfigurationIntent.self,
            provider: ConfigurableScaleProvider()
        ) { entry in
            BhullarWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dots at Any Scale")
        .description("Months, weeks, days, or hours. Edit the widget to choose its scale.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

#Preview(as: .systemSmall) {
    BhullarDayWidget()
} timeline: {
    ScaleEntry(date: Date(), scale: .hours, position: TimeScale.hours.position())
}
