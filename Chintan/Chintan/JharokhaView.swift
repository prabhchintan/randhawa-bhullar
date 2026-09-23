import SwiftUI
import UIKit

// Home is the day's painting, full bleed, with the day laid over its foot
// the way a museum places a label: the date, the day in a few words, the
// dated things coming up as small calendar tiles, the house's meters as
// rings. Refreshed on open and by pull.
struct JharokhaView: View {
    @State private var image: UIImage?
    @State private var painting: HouseClient.Painting?
    @State private var day = CockpitDay()
    @State private var dated: [BoardItem] = []
    @State private var errorText: String?
    @State private var showCredit = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    overlay
                        .padding(.horizontal, 22)
                        .padding(.top, 80)
                        .padding(.bottom, 20)
                        .background(alignment: .bottom) {
                            LinearGradient(
                                stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.8), location: 0.55)],
                                startPoint: .top, endPoint: .bottom
                            )
                        }
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background {
                Color.clear
                    .overlay { canvas }
                    .clipped()
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    // The picture, or while it is missing a warm ground in the house's colours.
    @ViewBuilder private var canvas: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(colors: [Theme.saffron.opacity(0.55), Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(.subheadline, design: .serif).smallCaps())
                    .foregroundStyle(.white.opacity(0.75))
                Text(day.headline ?? "The house is quiet.")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
            }

            if !dated.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(DayGroup.of(dated)) { group in
                        HStack(alignment: .top, spacing: 12) {
                            DateTile(date: group.day)
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(group.items) { item in
                                    Text(item.gist)
                                        .font(.callout)
                                        .foregroundStyle(.white.opacity(0.92))
                                        .lineLimit(1)
                                }
                            }
                            .frame(minHeight: 42)
                        }
                    }
                }
            }

            if let errorText {
                Label(errorText, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(alignment: .bottom) {
                if !day.meters.isEmpty {
                    HStack(spacing: 14) {
                        ForEach(day.meters, id: \.name) { meter in
                            MeterRing(name: meter.name, fraction: meter.fraction)
                        }
                        Circle()
                            .fill(day.raised ? Theme.saffron : Color.green.opacity(0.85))
                            .frame(width: 9, height: 9)
                            .accessibilityLabel(day.raised ? "something raised" : "nothing raised")
                    }
                }
                Spacer(minLength: 12)
                museumLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Small and exact, never shouting; the credit on tap.
    @ViewBuilder private var museumLabel: some View {
        if let painting, let title = painting.title {
            VStack(alignment: .trailing, spacing: 2) {
                Text(title.plainDashes)
                    .font(.system(.caption, design: .serif).italic())
                Text([painting.artist, painting.year].compactMap { $0 }.joined(separator: ", ").plainDashes)
                    .font(.system(.caption2, design: .serif))
                if showCredit, let credit = painting.credit {
                    Text(credit.plainDashes)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(showCredit ? 4 : 1)
            .frame(maxWidth: 200, alignment: .trailing)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showCredit.toggle() } }
        }
    }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            return
        }
        let house = HouseClient(baseAddress: address)
        async let label = try? house.painting()
        async let picture = try? house.paintingImage()
        async let cockpit = try? house.cockpit()
        async let board = try? house.board()
        let (l, p, c, b) = await (label, picture, cockpit, board)
        painting = l
        if let p, let ui = UIImage(data: p) { image = ui }
        if let c { day = CockpitDay(c) }
        if let b { dated = BoardItem.upcoming(BoardParser.parse(b)) }
        errorText = (c == nil && b == nil) ? "The house is not answering. Are you on the tailnet?" : nil
    }
}

// A calendar leaf: the weekday over the day of the month, saffron when it
// is today or past.
private struct DateTile: View {
    let date: Date?

    var body: some View {
        let soon = date.map { Calendar.current.startOfDay(for: $0) <= Calendar.current.startOfDay(for: .now) } ?? false
        VStack(spacing: 0) {
            Text(date?.formatted(.dateTime.weekday(.abbreviated)).uppercased() ?? "")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(soon ? Theme.saffron : .white.opacity(0.7))
            Text(date?.formatted(.dateTime.day()) ?? "")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 40, height: 42)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.18)))
    }
}

// A meter as a ring: how much of the window is spent, saffron past three
// quarters.
private struct MeterRing: View {
    let name: String
    let fraction: Double

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().stroke(.white.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(fraction > 0.75 ? Theme.saffron : .white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            Text(name)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement()
        .accessibilityLabel("\(name) \(Int(fraction * 100)) percent")
    }
}

// The few things Home reads out of the house's cockpit text: the day's
// headline (its first sentence), the usage meters, and whether anything
// is raised. Anything it cannot find it leaves out.
struct CockpitDay {
    struct Meter { let name: String; let fraction: Double }
    var headline: String?
    var meters: [Meter] = []
    var raised = false

    init() {}

    init(_ text: String) {
        // The house wraps long lines with a two space indent; join them back.
        var lines: [String] = []
        for raw in text.components(separatedBy: "\n") {
            if raw.hasPrefix("  "), !lines.isEmpty {
                lines[lines.count - 1] += " " + raw.trimmingCharacters(in: .whitespaces)
            } else {
                lines.append(raw)
            }
        }
        if let first = lines.first, let gap = first.range(of: "  ") {
            let rest = first[gap.upperBound...].trimmingCharacters(in: .whitespaces)
            if let stop = rest.firstIndex(of: ".") {
                headline = String(rest[...stop])
            } else if !rest.isEmpty {
                headline = rest
            }
        }
        raised = !text.contains("nothing raised")
        if let match = text.firstMatch(of: /meters s(\d+) w(\d+) f(\d+)/) {
            meters = [("s", match.1), ("w", match.2), ("f", match.3)].compactMap { name, value in
                Double(value).map { Meter(name: name, fraction: $0 / 100) }
            }
        }
    }
}

extension BoardItem {
    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var day: Date? { date.flatMap { Self.dayFormat.date(from: $0) } }

    // The thing itself, before its reasons.
    var gist: String {
        var cut = text
        for mark in [" (", "; ", ": ", ", "] {
            if let r = cut.range(of: mark) { cut = String(cut[..<r.lowerBound]) }
        }
        return cut
    }

    // The dated, open things inside the coming week, soonest first, three at most.
    static func upcoming(_ sections: [BoardSection]) -> [BoardItem] {
        let horizon = Calendar.current.date(byAdding: .day, value: 8, to: .now) ?? .now
        return sections.flatMap(\.items)
            .filter { !$0.done && ($0.day.map { $0 < horizon } ?? false) }
            .sorted { ($0.day ?? .distantFuture) < ($1.day ?? .distantFuture) }
            .prefix(3)
            .map { $0 }
    }
}

// Things due the same day share one calendar leaf.
struct DayGroup: Identifiable {
    let day: Date?
    let items: [BoardItem]
    var id: String { items.first?.date ?? "" }

    static func of(_ items: [BoardItem]) -> [DayGroup] {
        var groups: [DayGroup] = []
        for item in items {
            if let last = groups.last, last.items.first?.date == item.date {
                groups[groups.count - 1] = DayGroup(day: last.day, items: last.items + [item])
            } else {
                groups.append(DayGroup(day: item.day, items: [item]))
            }
        }
        return groups
    }
}

extension String {
    // The house's own rule: no long dashes on its screens, even in a museum's label.
    var plainDashes: String {
        replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2014}", with: ", ")
    }
}
