import SwiftUI

// The house: the household itself, seen. The painting holds the top of the
// screen; under it, each part of the house named on the art and lettered on
// a leaf: the three voices and whether each is home, the meters as bars of
// ink, and, once the house serves them, the hands with their last run and
// the doctor's word. Marks before words; gilt is well, saffron needs him.
struct HouseView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var voices: [HouseClient.Voices.Entry] = []
    @State private var meters: [CockpitDay.Meter] = []
    @State private var tended: Date?
    @State private var household: HouseClient.Household?
    @State private var errorText: String?
    @State private var loaded = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                        .padding(.top, geo.size.height * 0.30)
                        .padding(.horizontal, 6)
                    rooms
                }
                .padding(.horizontal, 16)
                // The last leaf clears the fade whole, never cut above the tabs.
                .padding(.bottom, Theme.foot + 8)
            }
            .fadedEdges(bottom: Theme.foot)
            .accessibilityIdentifier("household")
        }
        .background { PaintedGround(head: 160) }
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The house")
                .font(Theme.label())
                .tracking(0.8)
                .foregroundStyle(Theme.bone.opacity(0.9))
            Text(summary)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.bone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A pool of shade under the words instead of a shadow on each letter,
        // drawn once and slid with the page.
        .background(alignment: .bottom) {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.45), location: 0.55), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 340)
                .padding(.horizontal, -40)
                .offset(y: 110)
        }
    }

    // The house in a sentence: who is not home, what is failing, or well.
    private var summary: String {
        if !loaded { return " " }
        if errorText != nil && voices.isEmpty && meters.isEmpty { return "Out of reach." }
        let away = voices.filter { $0.home == false }.map(\.name)
        let failing = (household?.hands ?? []).filter { $0.state == "failed" }.map(\.name)
        if !failing.isEmpty {
            let names = Self.list(failing)
            return names.prefix(1).uppercased() + names.dropFirst() + " failed."
        }
        if !away.isEmpty { return Self.list(away) + (away.count == 1 ? " is not home." : " are not home.") }
        if !voices.isEmpty { return "All three home." }
        return "The house is quiet."
    }

    private static func list(_ names: [String]) -> String {
        names.count <= 1 ? names.joined() : names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    @ViewBuilder private var rooms: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorText {
                Label(errorText, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .plaque()
            }
            if !voices.isEmpty {
                shelf("The voices", first: true)
                voicesLeaf
            }
            if !meters.isEmpty {
                shelf("The meters", first: voices.isEmpty)
                leaf(meters) { meterRow($0) }
                if let tended {
                    Text("Last round " + Self.when(tended))
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundStyle(Theme.bone.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.top, 2)
                }
            }
            if let hands = household?.hands, !hands.isEmpty {
                shelf("The hands", first: false)
                leaf(hands) { handRow($0) }
            }
            if let doctor = household?.doctor {
                shelf("The doctor", first: false)
                doctorLeaf(doctor)
            }
        }
    }

    // A shelf's name, on its mount on the art, the way the Board names its days.
    private func shelf(_ name: String, first: Bool) -> some View {
        Text(name)
            .font(Theme.label())
            .tracking(1)
            .foregroundStyle(Theme.giltOnArt)
            .mount()
            .padding(.top, first ? 6 : 18)
            .accessibilityAddTraits(.isHeader)
    }

    private func leaf<T, Row: View>(_ items: [T], @ViewBuilder row: @escaping (T) -> Row) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 {
                    Rectangle().fill(Theme.gilt.opacity(0.28)).frame(height: 0.5)
                }
                row(item)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
    }

    // The three voices on one leaf, side by side, each named in small serif
    // capitals beside its mark: gilt when home, saffron when not. What each
    // is for is the Study's to say; here only whether it is there. At the
    // accessibility sizes they stand one under another.
    private var voicesLeaf: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 0))
        return layout {
            ForEach(voices, id: \.name) { v in
                HStack(spacing: 9) {
                    StateMark(color: v.home == false ? Theme.saffron : Theme.gilt, filled: v.home != nil)
                    Text(v.name)
                        .font(Theme.label(.body))
                        .tracking(1.2)
                        .foregroundStyle(v.home == false ? Theme.saffron : Theme.ink)
                }
                .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(v.name + (v.home == false ? ", not home" : ", home"))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
    }

    // A meter as a bar of ink: the window's name, when it comes back in gilt,
    // and under them the bar, saffron once three quarters are spent.
    private func meterRow(_ m: CockpitDay.Meter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(m.title.prefix(1).uppercased() + m.title.dropFirst())
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                if let fresh = m.fresh {
                    Text(fresh)
                        .font(Theme.label(.caption))
                        .tracking(0.6)
                        .foregroundStyle(Theme.gilt)
                        .accessibilityLabel("fresh again " + fresh)
                }
            }
            Rectangle()
                .fill(Theme.ink.opacity(0.12))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(m.fraction > 0.75 ? Theme.saffron : Theme.gilt)
                        .scaleEffect(x: min(max(m.fraction, 0), 1), anchor: .leading)
                }
                .accessibilityElement()
                .accessibilityLabel("\(m.percent) percent used")
        }
        .accessibilityElement(children: .combine)
    }

    // A hand: its mark by state, its name, its own line, and when it last ran.
    private func handRow(_ h: HouseClient.Household.Hand) -> some View {
        let late = h.state == "late" || h.state == "failed"
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            StateMark(color: late ? Theme.saffron : Theme.gilt, filled: h.state != "off")
            VStack(alignment: .leading, spacing: 3) {
                Text(h.name.plainDashes)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.ink.opacity(h.state == "off" ? 0.55 : 1))
                if let line = h.line, !line.isEmpty {
                    Text(line.plainDashes)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let last = h.last.flatMap(Self.date) {
                Text(Self.when(last))
                    .font(Theme.label(.caption))
                    .tracking(0.6)
                    .foregroundStyle(late ? Theme.saffron : Theme.gilt)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func doctorLeaf(_ d: HouseClient.Household.Doctor) -> some View {
        let words = d.words ?? []
        return leaf(words.isEmpty ? [d.ok ? "Nothing to see to." : "Something is wrong."] : words) { w in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                StateMark(color: d.ok ? Theme.gilt : Theme.saffron, filled: true)
                Text(w.plainDashes)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // Today by the hour, another day by its name.
    private static func when(_ d: Date) -> String {
        Calendar.current.isDateInToday(d)
            ? d.formatted(date: .omitted, time: .shortened)
            : d.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private static func date(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            loaded = true
            return
        }
        let house = HouseClient(baseAddress: address)
        async let v = try? house.voices()
        async let p = try? house.pulse()
        async let h = try? house.household()
        let (found, beat, hold) = await (v, p, h)
        if let found { voices = found.voices }
        if let beat {
            meters = beat.meters.map(CockpitDay.Meter.init)
            tended = beat.tended.flatMap(Self.date)
        }
        household = hold
        errorText = (found == nil && beat == nil) ? "The house is not answering. Are you on the tailnet?" : nil
        loaded = true
    }
}

// A state as a mark, not a word: a small dot, filled when the house knows.
private struct StateMark: View {
    let color: Color
    var filled = true

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 1)
            .background(Circle().fill(filled ? color : .clear))
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }
}
