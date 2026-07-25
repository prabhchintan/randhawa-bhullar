import SwiftUI
import WidgetKit

/// A single point on the widget's timeline: the year's progress as of `date`.
struct YearEntry: TimelineEntry {
    let date: Date
    let progress: YearProgress
}

/// Supplies the widget with one entry per day.
struct YearProvider: TimelineProvider {
    func placeholder(in context: Context) -> YearEntry {
        YearEntry(date: Date(), progress: YearProgress())
    }

    func getSnapshot(in context: Context, completion: @escaping (YearEntry) -> Void) {
        completion(YearEntry(date: Date(), progress: YearProgress()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<YearEntry>) -> Void) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // One entry per day for the next two weeks. WidgetKit advances through
        // them at local midnight; `.atEnd` makes it request a fresh window once
        // the last entry is reached, so the grid keeps ticking indefinitely
        // without relying on background refresh budget.
        var entries: [YearEntry] = []
        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            entries.append(YearEntry(date: day, progress: YearProgress(date: day, calendar: calendar)))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct RandhawaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: YearEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Day \(entry.progress.dayOfYear) · \(entry.progress.percent)%")

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                DotGrid(progress: entry.progress, palette: .accessory, dotScale: 0.62)
                    .padding(2)
            }

        case .accessoryRectangular:
            HStack(spacing: 8) {
                DotGrid(progress: entry.progress, palette: .accessory, dotScale: 0.7)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.progress.percent)%")
                        .font(.headline)
                    Text("\(entry.progress.daysRemaining) days left")
                        .font(.caption2)
                }
            }

        default: // systemSmall, systemMedium, systemLarge
            DotGrid(progress: entry.progress)
        }
    }
}

struct RandhawaWidget: Widget {
    private let kind = "RandhawaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YearProvider()) { entry in
            RandhawaWidgetEntryView(entry: entry)
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

#Preview(as: .systemSmall) {
    RandhawaWidget()
} timeline: {
    YearEntry(date: Date(), progress: YearProgress())
}
