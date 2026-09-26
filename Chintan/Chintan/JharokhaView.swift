import SwiftUI
import UIKit

// Home is the day's painting, full bleed, with the day laid over its foot
// the way a museum places a label: the date, the day in a few words, today's
// things in their fewest words; and on the bar itself, under a hairline, the
// house's meters as rings beside the label, so the painting has the height
// of the screen (his word, 2026-09-24). Today only; the week is the Board's.
// Refreshed on open and by pull.
struct JharokhaView: View {
    @EnvironmentObject private var gallery: Gallery
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var day = CockpitDay()
    @State private var dated: [BoardItem] = []
    // The house's own short titles, by the line, when it serves them.
    @State private var titles: [String: BoardItem.Short] = [:]
    @State private var pulse: [CockpitDay.Meter] = []
    @State private var errorText: String?
    @State private var showCredit = false
    @State private var openMeter: String?
    @State private var showVisitors = false
    @State private var turned = 0
    // The ring under a press and hold, its plaque grown over the wall.
    @State private var held: String?
    // The thing under a press and hold, its plaque grown over the wall.
    @State private var heldThing: UUID?
    // The museum label under a press and hold, the whole of it on a plaque,
    // and whether the thumb has slid onto the plaque's word for the house.
    @GestureState(resetTransaction: Transaction(animation: .snappy)) private var hold = LabelHold()
    // Where that line stands on Home, so a slide can find it.
    @State private var wordLine = CGRect.zero
    // A word for the house being written, on its plaque above the keyboard.
    @State private var wording = JharokhaView.eyes == "word"

    private struct LabelHold: Equatable {
        var held = false
        var onWord = false
    }

    private var heldLabel: Bool { hold.held || Self.eyes == "label" || Self.eyes == "onword" }
    private var onWord: Bool { hold.onWord || Self.eyes == "onword" }

    var body: some View {
        ZStack(alignment: .bottom) {
            wall
                // While a word is written the wall's lettering steps away and
                // the painting alone stands behind it; the keyboard would
                // otherwise lift the day's lines over the picture.
                .opacity(wording ? 0 : 1)
            if wording {
                // A tap on the painting puts the word away.
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { putWordAway() }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                HouseWord(screen: "home", place: "Home", close: putWordAway)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func putWordAway() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.snappy) { wording = false }
    }

    // Held, the label grows its plaque; slid onto the plaque's last line and
    // let go there, it opens a word for the house, the way a held icon's menu
    // is chosen from. Let go anywhere else, it folds back.
    private var labelHold: some Gesture {
        LongPressGesture(minimumDuration: 0.3, maximumDistance: 24)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("home")))
            .updating($hold) { value, state, transaction in
                guard case .second(true, let drag) = value else { return }
                if !state.held { transaction.animation = .snappy }
                state.held = true
                state.onWord = drag.map { overWord($0.location) } ?? false
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value, overWord(drag.location) else { return }
                withAnimation(.snappy) { wording = true }
            }
    }

    // The line and a little around it, so a thumb need not be exact.
    private func overWord(_ point: CGPoint) -> Bool {
        !wordLine.isEmpty && wordLine.insetBy(dx: -12, dy: -14).contains(point)
    }

    private var wall: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                GeometryReader { wall in
                    ScrollView {
                        // The day stands on the wall's foot, just above the
                        // hairline (his word, 2026-09-24 04:46: the lines hung
                        // mid-painting; a frame with no alignment had centred
                        // them). Only a day too tall for the wall scrolls.
                        overlay
                            .padding(.horizontal, 22)
                            .padding(.top, 80)
                            // The last line clears the fade whole, above the foot.
                            .padding(.bottom, 40)
                            .frame(minHeight: wall.size.height, alignment: .bottomLeading)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .fadedEdges(top: 0, bottom: 36)
                }
                .overlay(alignment: .bottomTrailing) {
                    // The label held: its plaque stands on the hairline over
                    // the label, and grows up from it.
                    if heldLabel, let painting = gallery.painting, painting.title != nil {
                        let (name, about) = Self.split((painting.artist ?? "").plainDashes)
                        LabelPlaque(painting: painting, name: name, about: about, onWord: onWord) { wordLine = $0 }
                            .padding(.trailing, 22)
                            .padding(.bottom, 12)
                            .transition(.scale(scale: 0.5, anchor: .bottomTrailing).combined(with: .opacity))
                    }
                }
                .zIndex(1)
                foot
            }
            // One shade from the day's line down through the tab bar, no seam.
            .background { PaintedGround(head: 110, foot: geo.size.height * 0.75, footShade: 0.82) }
            .overlay(alignment: .topLeading) { guestBook }
            .coordinateSpace(name: "home")
        }
        .environment(\.colorScheme, .dark)
        .refreshable { await refresh() }
        .task { await refresh() }
        .sensoryFeedback(.impact(weight: .light), trigger: turned)
        // A soft impact as a plaque grows, none as it folds.
        .sensoryFeedback(.impact(flexibility: .soft), trigger: held) { _, now in now != nil }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: heldThing) { _, now in now != nil }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: heldLabel) { _, now in now }
        // A tick as the thumb comes onto the word for the house.
        .sensoryFeedback(.selection, trigger: onWord) { _, now in now }
        .sheet(isPresented: $showVisitors) {
            VisitorsView()
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
        }
    }

    // The guest book, lettered small at the head of the wall: who came to
    // the site. Opens the visitors over the painting.
    private var guestBook: some View {
        Button {
            showVisitors = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.caption)
                Text("Visitors")
                    .font(Theme.label(.caption))
                    .tracking(1)
            }
            .foregroundStyle(Theme.bone.opacity(0.85))
            .shadow(color: .black.opacity(0.7), radius: 5)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("visitors")
        .accessibilityLabel("Visitors to the site")
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 18) {
            dayLabel

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // The date and the day's things read as one label: the date sits as
    // close over the first thing as the things over one another.
    private var dayLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The date alone leads the wall (Prab, 2026-09-25 08:29 and 08:52:
            // the day's sentence, "2 raised this morning", goes entirely; the
            // date and today's things, blank when none).
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(.title2, design: .serif).weight(.medium).smallCaps())
                .tracking(0.4)
                .foregroundStyle(Theme.bone)
                // A thing held names its own day; the date steps aside.
                .opacity(heldThing == nil ? 1 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if let item = dated.first(where: { $0.id == heldThing }) {
                    // It stands just above the leaves, over the day's line and
                    // the painting, the whole width of the wall, and grows up.
                    ThingPlaque(item: item, short: titles[item.line] ?? item.short)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: -8)
                        .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                }
            }

            // Today's things only, each in its fewest words, the hour apart in
            // gilt; a thing whose day has passed says so in saffron.
            if !dated.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(dated) { item in
                        let short = titles[item.line] ?? item.short
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            // A size down from title3 (his word 08:52: "the action
                            // font could be smaller a bit").
                            Text(short.title.plainDashes)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(heldThing == item.id ? Theme.giltOnArt : Theme.bone)
                                .fixedSize(horizontal: false, vertical: true)
                            if let when = item.since ?? short.hour {
                                Text(when)
                                    .font(Theme.label(.subheadline))
                                    .tracking(0.6)
                                    .foregroundStyle(item.since != nil ? Theme.saffron : Theme.giltOnArt)
                                    .fixedSize()
                            }
                        }
                        .frame(minHeight: 32, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("thing")
                        // Pressed and held, the thing grows a plaque with the
                        // whole of it; let go, it folds back.
                        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 24) {
                            withAnimation(.snappy) { heldThing = item.id }
                        } onPressingChanged: { pressing in
                            if !pressing, heldThing != nil { withAnimation(.snappy) { heldThing = nil } }
                        }
                    }
                }
                .onAppear(perform: holdThingOnLaunch)
            }
        }
    }

    // The foot of the wall, standing on the bar so the day's lines and the
    // painting have the rest: under a gilt hairline the rings together at
    // the left, the label and the turn at the right. At the accessibility
    // sizes the label steps under the rings, so the foot never runs off the
    // phone; chosen by the text size, not the label's width, so the credit
    // opening on a tap never throws the foot into the other shape.
    private var foot: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(Theme.giltOnArt.opacity(0.45))
                .frame(height: 0.5)
                .accessibilityHidden(true)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .trailing, spacing: 18) {
                    rings.frame(maxWidth: .infinity, alignment: .leading)
                    museumLabel
                }
            } else {
                HStack(alignment: .top) {
                    rings
                    Spacer(minLength: 12)
                    museumLabel
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 2)
        // No identifier of its own here: one on the foot names every ring and
        // the label "foot", and the walk could find none of them to hold.
    }

    // The house's meters as rings, and the mark for anything raised. The
    // rings are a picture, so they stop growing at the first large size.
    @ViewBuilder private var rings: some View {
        if !meters.isEmpty {
            HStack(alignment: .top, spacing: 16) {
                ForEach(meters, id: \.key) { meter in
                    MeterRing(meter: meter, open: meter.key == openMeter || meter.key == held)
                        .accessibilityIdentifier("ring")
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                openMeter = openMeter == meter.key ? nil : meter.key
                            }
                        }
                        // Pressed and held, the ring grows a plaque with the
                        // whole of it; let go, the plaque folds back.
                        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 24) {
                            withAnimation(.snappy) { held = meter.key }
                        } onPressingChanged: { pressing in
                            if !pressing, held != nil { withAnimation(.snappy) { held = nil } }
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
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .overlay(alignment: .bottomLeading) {
                if let i = meters.firstIndex(where: { $0.key == held }) {
                    // It grows out of the ring pressed, standing just above the
                    // rings (the row is the raised mark's 44 points tall).
                    RingPlaque(meter: meters[i])
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: -(44 + 12))
                        .transition(.scale(scale: 0.4, anchor: UnitPoint(x: (CGFloat(i) * 56 + 22) / RingPlaque.width, y: 1))
                            .combined(with: .opacity))
                }
            }
            .onAppear(perform: holdOnLaunch)
        }
    }

    // For the house's eyes: `--open tN` on Home holds the Nth thing pressed.
    private func holdThingOnLaunch() {
        let args = ProcessInfo.processInfo.arguments
        guard heldThing == nil, Tab.launch == .jharokha, let i = args.firstIndex(of: "--open"), i + 1 < args.count,
              args[i + 1].hasPrefix("t"), let n = Int(args[i + 1].dropFirst()), n < dated.count else { return }
        heldThing = dated[n].id
    }

    // For the house's eyes: `--open N` on Home holds the Nth ring pressed.
    private func holdOnLaunch() {
        let args = ProcessInfo.processInfo.arguments
        guard held == nil, Tab.launch == .jharokha, let i = args.firstIndex(of: "--open"), i + 1 < args.count,
              let n = Int(args[i + 1]), n < meters.count else { return }
        held = meters[n].key
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
            // The label stops growing where the rings do, so at the largest
            // text the day's things keep the wall.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 200, alignment: .trailing)
            .contentShape(Rectangle())
            .accessibilityIdentifier("label")
            // The label behind a held plaque steps back, so the two never read at once.
            .opacity(heldLabel ? 0.25 : 1)
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showCredit.toggle() } }
            // Pressed and held, the label grows a plaque with the whole of
            // it, the way the wall card reads close up; let go, it folds back.
            .gesture(labelHold)
            .overlay(alignment: .bottomTrailing) { nextMark.offset(y: 24) }
            .padding(.bottom, 22)
        }
    }

    // Under the label, the gallery's turn: the next painting on the shelf,
    // the phone's own copy, with a soft tick when it comes.
    @ViewBuilder private var nextMark: some View {
        if gallery.shelf.count > 1 {
            Button {
                Task {
                    if await gallery.next() { turned += 1 }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("next")
                        .font(Theme.label(.caption))
                        .tracking(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.giltOnArt)
                .padding(.vertical, 6)
                .padding(.leading, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("next")
            .accessibilityLabel("Next painting")
        }
    }

    // "Edgar Degas (French, 1834-1917)" is the name on the label and the
    // rest for the credit.
    private static func split(_ artist: String) -> (String, String?) {
        guard let open = artist.range(of: " ("), artist.hasSuffix(")") else { return (artist, nil) }
        let about = artist[open.upperBound...].dropLast()
        return (String(artist[..<open.lowerBound]), about.isEmpty ? nil : String(about))
    }

    // For the house's eyes: `--open cut` on Home letters the phone's own cut
    // as if the house were away; `--open empty` is a day with nothing on it.
    private static var eyes: String? {
        let args = ProcessInfo.processInfo.arguments
        guard Tab.launch == .jharokha, let i = args.firstIndex(of: "--open"), i + 1 < args.count else { return nil }
        return args[i + 1]
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
        async let short = try? house.titles()
        let (_, c, b, p, s) = await (picture, cockpit, board, beat, short)
        if let c { day = CockpitDay(c) }
        if let p { pulse = p.meters.map(CockpitDay.Meter.init) }
        if let s, Self.eyes != "cut" { titles = s }
        if let b, Self.eyes != "empty" { dated = BoardItem.today(BoardParser.parse(b)) }
        errorText = (c == nil && b == nil) ? "The house is not answering. Are you on the tailnet?" : nil
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

// A ring held: the ring itself larger with its number, the window's name in
// gilt, what it says, and when it comes back, on a small plaque.
private struct RingPlaque: View {
    static let width: CGFloat = 248
    let meter: CockpitDay.Meter

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().stroke(Theme.ink.opacity(0.18), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(max(meter.fraction, 0), 1))
                    .stroke(meter.fraction > 0.75 ? Theme.saffron : Theme.gilt,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(meter.percent)")
                    .font(.system(.callout, design: .serif).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(meter.title)
                    .font(Theme.label(.caption))
                    .tracking(0.8)
                    .foregroundStyle(Theme.gilt)
                // The ring has the number and the title the window; the
                // house's words only where they say more than both.
                if let words = meter.words, !words.lowercased().contains(meter.title.lowercased()) {
                    Text(words.prefix(1).uppercased() + words.dropFirst())
                        .font(.footnote)
                        .foregroundStyle(Theme.ink)
                }
                Text(meter.fresh.map { "Fresh again \($0)" } ?? "\(meter.percent) percent used")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.85))
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: Self.width)
        // Whole, not the leaves' 97 percent: the wall's lines stand right under it.
        .background(Theme.plaque, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .plaque(radius: 12)
        .accessibilityElement(children: .combine)
    }
}

// The label held: the wall card read close up, the title in the serif, the
// artist and who they were, the year in gilt, and under a hairline the credit;
// last, framed like a thing to press, a word for the house, which darkens
// when the thumb slides onto it.
private struct LabelPlaque: View {
    let painting: HouseClient.Painting
    let name: String
    let about: String?
    let onWord: Bool
    // Where the word's line stands on Home.
    let placed: (CGRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let year = painting.year, !year.isEmpty {
                Text(year.plainDashes)
                    .font(Theme.label(.caption))
                    .tracking(0.8)
                    .foregroundStyle(Theme.gilt)
            }
            Text((painting.title ?? "").plainDashes)
                .font(.system(.title3, design: .serif).italic())
                .foregroundStyle(Theme.ink)
            if !name.isEmpty || about != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if !name.isEmpty {
                        Text(name)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Theme.ink)
                    }
                    if let about {
                        Text(about)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.75))
                    }
                }
            }
            if let credit = painting.credit, !credit.isEmpty {
                Rectangle()
                    .fill(Theme.gilt.opacity(0.5))
                    .frame(width: 36, height: 0.5)
                    .padding(.top, 2)
                Text(credit.plainDashes)
                    .font(.caption)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.footnote)
                Text("A word for the house")
                    .font(.system(.subheadline, design: .serif).weight(.semibold).lowercaseSmallCaps())
                    .tracking(0.8)
            }
            // Under the thumb it fills with gilt, the plaque's ink on it, as
            // a chosen line in a held menu does.
            .foregroundStyle(onWord ? Theme.plaque : Theme.gilt)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Theme.gilt.opacity(onWord ? 1 : 0.07)))
            .overlay(shape.strokeBorder(Theme.gilt.opacity(onWord ? 1 : 0.5), lineWidth: 1))
            .scaleEffect(onWord ? 1.03 : 1)
            .animation(.snappy(duration: 0.15), value: onWord)
            .padding(.top, 6)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("home")) } action: { placed($0) }
            .onDisappear { placed(.zero) }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 300, alignment: .leading)
        // Whole, like the ring's: the label stands right under it.
        .background(Theme.plaque, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .plaque(radius: 12)
        .accessibilityElement(children: .combine)
    }
}

// A thing held: its day in words, the thing by the name Home gives it, and
// the whole of its why, on a small plaque.
private struct ThingPlaque: View {
    let item: BoardItem
    let short: BoardItem.Short
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let day = item.day {
                let due = Calendar.current.startOfDay(for: day) <= Calendar.current.startOfDay(for: .now)
                Text(Self.when(day))
                    .font(Theme.label(.caption))
                    .tracking(0.8)
                    .foregroundStyle(due ? Theme.saffron : Theme.gilt)
            }
            Text(short.title.plainDashes)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Theme.ink)
            if !item.why.isEmpty {
                Text(item.why.plainDashes)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    // A long why keeps to the painting above the leaves.
                    .lineLimit(typeSize.isAccessibilitySize ? 5 : 12)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Whole, like the ring's: the wall's lines stand right under it.
        .background(Theme.plaque, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .plaque(radius: 12)
        .accessibilityElement(children: .combine)
    }

    private static func when(_ day: Date) -> String {
        let cal = Calendar.current
        let words = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if cal.isDateInToday(day) { return "Today, " + words }
        if cal.isDateInTomorrow(day) { return "Tomorrow, " + words }
        if day < cal.startOfDay(for: .now) { return "Past, " + words }
        return words
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
        var name: String?

        init(key: String, label: String, fraction: Double) {
            self.key = key; self.label = label; self.fraction = fraction
        }

        init(_ m: HouseClient.Pulse.Meter) {
            key = m.key
            fraction = m.fraction
            words = m.words
            resets = m.resets.flatMap(Self.parse)
            name = m.name?.plainDashes
            label = Self.names[m.key] ?? Self.shortName(m.name ?? m.key)
        }

        var percent: Int { Int((min(max(fraction, 0), 1) * 100).rounded()) }

        // The window's own name as the house gives it ("the five hours").
        var title: String { name ?? label }

        // What the ring says in words, and when the window comes back.
        var said: String { words ?? "\(percent) percent of \(label)" }

        var fresh: String? {
            guard let resets else { return nil }
            return Calendar.current.isDateInToday(resets)
                ? resets.formatted(date: .omitted, time: .shortened)
                : resets.formatted(.dateTime.weekday(.wide).hour().minute())
        }

        var sentence: String {
            var line = said
            if let fresh { line += ", fresh again \(fresh)" }
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

    // Home is today (Prab, 2026-09-23 20:05): the open things due today and
    // any already past, the oldest first. The week and later are the Board's.
    static func today(_ sections: [BoardSection]) -> [BoardItem] {
        let end = Calendar.current.startOfDay(for: .now)
        return sections.flatMap(\.items)
            .filter { !$0.done && ($0.day.map { $0 <= end } ?? false) }
            .sorted { $0.day! < $1.day! }
    }

    // A thing in the fewest words that carry the most, and its hour apart.
    struct Short: Decodable {
        let title: String
        let hour: String?
    }

    // A deed as the word that follows the thing ("Caremark call"); an empty
    // one goes, the thing alone says it ("Rent" for "Pay rent").
    private static let deeds: [String: String] = [
        "call": "call", "email": "email", "text": "text", "check": "check", "order": "order",
        "return": "return", "renew": "renewal", "pay": "payment", "book": "", "schedule": "",
        "send": "", "submit": "", "file": "", "confirm": "", "ask": "", "cancel": "", "get": "", "do": ""]

    // Where the reasons begin: the thing is said before them.
    private static let reasons: Set<String> = ["about", "for", "re", "regarding", "with", "before", "by",
                                               "until", "from", "so", "because", "after", "via", "and"]

    // The day and the hour are said apart, never in the title.
    private static let times: Set<String> = [
        "today", "tomorrow", "tonight", "morning", "afternoon", "evening", "noon", "this", "next",
        "am", "pm", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    private static let hourWords = ["morning", "afternoon", "evening", "tonight", "noon"]

    // The house's line cut on the phone when the house is away, the way the
    // house cuts it: the noun of the thing in one to four words, the deed
    // after it only when the noun alone says nothing ("Caremark call", "DMV
    // plates", "Calcium scan"), and the hour apart, a clock time the house
    // wrote ("8:30 AM", "before 5 PM") or a word ("evening").
    var short: Short {
        let hour: String? = {
            if let clock = text.firstMatch(of: /(?:(?:before|by|until) )?\d{1,2}(?::\d{2})? ?[AP]M\b/) {
                return String(clock.output)
            }
            let said = gist.lowercased().split(separator: " ").map(String.init)
            return Self.hourWords.first(where: said.contains)
        }()

        var words = gist.split(separator: " ").map { $0.trimmingCharacters(in: .punctuationCharacters) }
        // The thing is said before its reasons and before its hour.
        let clock = words.indices.first { i in
            words[i].firstMatch(of: /^\d{1,2}(:\d{2}|:\d{2}[ap]m|[ap]m)$/.ignoresCase()) != nil
                || (Int(words[i]) != nil && i + 1 < words.count && ["am", "pm"].contains(words[i + 1].lowercased()))
        }
        let reason = words.firstIndex { Self.reasons.contains($0.lowercased()) }
        if let stop = [clock, reason].compactMap({ $0 }).min(), stop > 0 {
            words = Array(words[..<stop])
        }
        words = words.filter { w in
            let l = w.lowercased()
            return !w.isEmpty && !["the", "a", "an", "his", "my"].contains(l) && !Self.times.contains(l)
        }
        var deed = ""
        if let first = words.first?.lowercased(), let noun = Self.deeds[first], words.count > 1 {
            deed = noun
            words.removeFirst()
        }
        // "Plates at Ogden DMV": the place's own short name leads the thing.
        var place: [String] = []
        if let at = words.firstIndex(where: { $0.lowercased() == "at" }) {
            place = Array(words[(at + 1)...])
            words = Array(words[..<at])
        }
        // "Draw 3 of 3" is the count, for the plaque.
        if words.count > 3, Int(words[words.count - 3]) != nil, words[words.count - 2] == "of",
           Int(words[words.count - 1]) != nil {
            words.removeLast(3)
        }
        // "Tacoma to Utah plates": the thing is after its last small word.
        if let small = words.lastIndex(where: { ["to", "of", "on", "in", "into"].contains($0.lowercased()) }),
           small < words.count - 1 {
            words = Array(words[(small + 1)...])
        }
        if let initials = place.last(where: { $0.count > 1 && $0 == $0.uppercased() && $0.allSatisfy(\.isLetter) }),
           !words.contains(initials), let noun = words.last {
            words = [initials, noun]
        } else if words.count > 3 {
            // "Coronary artery calcium scan": the last two carry it.
            words = Array(words.suffix(2))
        }
        if !deed.isEmpty { words.append(deed) }
        var title = words.isEmpty ? gist : words.joined(separator: " ")
        title = title.prefix(1).uppercased() + title.dropFirst()
        return Short(title: title, hour: hour)
    }

    // A thing whose day has passed says when it fell.
    var since: String? {
        guard let day, day < Calendar.current.startOfDay(for: .now) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: day, to: .now).day ?? 0
        return "since " + (days < 7 ? day.formatted(.dateTime.weekday(.abbreviated))
                                    : day.formatted(.dateTime.month(.abbreviated).day()))
    }
}

extension String {
    // The house's own rule: no long dashes on its screens, even in a museum's label.
    var plainDashes: String {
        replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2014}", with: ", ")
    }
}
