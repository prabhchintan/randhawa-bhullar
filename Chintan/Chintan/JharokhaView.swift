import SwiftUI
import UIKit

// Home is the day's painting, full bleed, with the day laid over its foot
// the way a museum places a label: the date, the day in a few words, the
// dated things coming up as small calendar tiles, the house's meters as
// rings. Refreshed on open and by pull.
struct JharokhaView: View {
    @EnvironmentObject private var gallery: Gallery
    @State private var day = CockpitDay()
    @State private var dated: [BoardItem] = []
    @State private var pulse: [CockpitDay.Meter] = []
    @State private var errorText: String?
    @State private var showCredit = false
    @State private var openMeter: String?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    overlay
                        .padding(.horizontal, 22)
                        .padding(.top, 80)
                        .padding(.bottom, 20)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            // One shade from the day's line down through the tab bar, no seam.
            .background { PaintedGround(foot: geo.size.height * 0.75, footShade: 0.82) }
        }
        .environment(\.colorScheme, .dark)
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(.subheadline, design: .serif).smallCaps())
                    .foregroundStyle(Theme.bone.opacity(0.88))
                Text(day.headline ?? "The house is quiet.")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.bone)
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
                                        .foregroundStyle(Theme.bone)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, 2)
                            .frame(minHeight: 44, alignment: .top)
                        }
                    }
                }
            }

            if let errorText {
                Label(errorText, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let open = meters.first(where: { $0.key == openMeter }) {
                Text(open.sentence)
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Theme.bone.opacity(0.85))
                    .transition(.opacity)
            }

            HStack(alignment: .bottom) {
                if !meters.isEmpty {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(meters, id: \.key) { meter in
                            MeterRing(meter: meter, open: meter.key == openMeter)
                                .accessibilityIdentifier("ring")
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        openMeter = openMeter == meter.key ? nil : meter.key
                                    }
                                }
                        }
                        Circle()
                            .fill(day.raised ? Theme.saffron : Theme.giltOnArt)
                            .frame(width: 7, height: 7)
                            .padding(.top, 9)
                            // The mark is small; what a finger or VoiceOver finds is not.
                            .frame(width: 44, height: 44, alignment: .top)
                            .contentShape(Rectangle())
                            .accessibilityElement()
                            .accessibilityLabel(day.raised ? "something raised" : "nothing raised")
                    }
                }
                Spacer(minLength: 12)
                museumLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Small and exact, never shouting: the title, the artist, the year, one
    // to a line. The artist's nationality and dates wait with the credit, on tap.
    @ViewBuilder private var museumLabel: some View {
        if let painting = gallery.painting, let title = painting.title {
            let artist = (painting.artist ?? "").plainDashes
            let (name, about) = Self.split(artist)
            VStack(alignment: .trailing, spacing: 2) {
                Text(title.plainDashes)
                    .font(.system(.caption, design: .serif).italic())
                if !name.isEmpty {
                    Text(name)
                        .font(.system(.caption, design: .serif))
                }
                if let year = painting.year, !year.isEmpty {
                    Text(year.plainDashes)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.white.opacity(0.75))
                }
                if showCredit {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let about { Text(about) }
                        if let credit = painting.credit { Text(credit.plainDashes) }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 4)
                    .transition(.opacity)
                }
            }
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.white.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 200, alignment: .trailing)
            .contentShape(Rectangle())
            .accessibilityIdentifier("label")
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showCredit.toggle() } }
        }
    }

    // "Edgar Degas (French, 1834-1917)" is the name on the label and the
    // rest for the credit.
    private static func split(_ artist: String) -> (String, String?) {
        guard let open = artist.range(of: " ("), artist.hasSuffix(")") else { return (artist, nil) }
        let about = artist[open.upperBound...].dropLast()
        return (String(artist[..<open.lowerBound]), about.isEmpty ? nil : String(about))
    }

    // The pulse's meters when the house serves them, else the cockpit's.
    private var meters: [CockpitDay.Meter] { pulse.isEmpty ? day.meters : pulse }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            return
        }
        let house = HouseClient(baseAddress: address)
        async let picture: Void = gallery.load()
        async let cockpit = try? house.cockpit()
        async let board = try? house.board()
        async let beat = try? house.pulse()
        let (_, c, b, p) = await (picture, cockpit, board, beat)
        if let c { day = CockpitDay(c) }
        if let p { pulse = p.meters.map(CockpitDay.Meter.init) }
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
        VStack(spacing: 1) {
            Text(date?.formatted(.dateTime.weekday(.abbreviated)).lowercased() ?? "")
                .font(.system(.caption, design: .serif).weight(.medium).smallCaps())
                .tracking(0.8)
                .foregroundStyle(soon ? Theme.saffron : Theme.giltOnArt)
            Text(date?.formatted(.dateTime.day()) ?? "")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Theme.bone)
        }
        .fixedSize()
        .padding(.vertical, 4)
        .frame(minWidth: 42, minHeight: 46)
        .background(Theme.lampBlack.opacity(0.35), in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.giltOnArt.opacity(0.6), lineWidth: 0.5))
    }
}

// A meter as a ring: how much of the window is spent, saffron past three
// quarters, its name lettered under it. Tapped, its name turns gilt and
// Home says it in words.
private struct MeterRing: View {
    let meter: CockpitDay.Meter
    let open: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(Theme.bone.opacity(0.22), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: min(max(meter.fraction, 0), 1))
                    .stroke(meter.fraction > 0.75 ? Theme.saffron : Theme.bone,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            Text(meter.label)
                .font(.system(.caption, design: .serif).weight(.medium).smallCaps())
                .tracking(0.6)
                .foregroundStyle(open ? Theme.giltOnArt : Theme.bone.opacity(0.85))
                .fixedSize()
        }
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(meter.sentence)
        .accessibilityAddTraits(.isButton)
    }
}

// The few things Home reads out of the house's cockpit text: the day's
// headline (its first sentence), the usage meters, and whether anything
// is raised. Anything it cannot find it leaves out.
struct CockpitDay {
    struct Meter {
        let key: String
        let label: String
        let fraction: Double
        var words: String?
        var resets: Date?

        init(key: String, label: String, fraction: Double) {
            self.key = key; self.label = label; self.fraction = fraction
        }

        init(_ m: HouseClient.Pulse.Meter) {
            key = m.key
            fraction = m.fraction
            words = m.words
            resets = m.resets.flatMap(Self.parse)
            label = Self.names[m.key] ?? Self.shortName(m.name ?? m.key)
        }

        // What the ring says in words, and when the window comes back.
        var sentence: String {
            var line = words ?? "\(Int((fraction * 100).rounded())) percent of \(label)"
            if let resets {
                let when = Calendar.current.isDateInToday(resets)
                    ? resets.formatted(date: .omitted, time: .shortened)
                    : resets.formatted(.dateTime.weekday(.wide).hour().minute())
                line += ", fresh again \(when)"
            }
            return line.prefix(1).uppercased() + line.dropFirst() + "."
        }

        private static let names = ["session": "hours", "weekly": "week", "fable": "fable"]

        private static func shortName(_ name: String) -> String {
            var n = name.hasPrefix("the ") ? String(name.dropFirst(4)) : name
            if let comma = n.range(of: ", ") { n = String(n[comma.upperBound...]) }
            return n.lowercased()
        }

        private static func parse(_ s: String) -> Date? {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }
    }
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
            meters = [("session", "hours", match.1), ("weekly", "week", match.2), ("fable", "fable", match.3)]
                .compactMap { key, label, value in
                    Double(value).map { Meter(key: key, label: label, fraction: $0 / 100) }
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
