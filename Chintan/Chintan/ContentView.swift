import SwiftUI
import UIKit

// The raw values are the names the house's screenshots pass on the command
// line, so they stay as they are even where the tab's own name has moved on.
enum Tab: String, CaseIterable {
    case jharokha, board, study

    // The tab named on the command line, for the house's screenshots.
    static var launch: Tab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tab"), i + 1 < args.count, let tab = Tab(rawValue: args[i + 1]) {
            return tab
        }
        return .jharokha
    }

    // The pages the app turns through. The Mac is a wall: Home alone, no bar.
    static var shown: [Tab] {
        #if targetEnvironment(macCatalyst)
        [.jharokha]
        #else
        allCases
        #endif
    }

    var name: String {
        switch self {
        case .jharokha: return "Home"
        case .board: return "Board"
        case .study: return "Study"
        }
    }

    var symbol: String {
        switch self {
        case .jharokha: return "house"
        case .board: return "checklist"
        case .study: return "bubble.left.and.text.bubble.right"
        }
    }
}

// One painting under the whole app, drawn once; the three screens are pages
// over it, a thumb's swipe or a tap on the bar moving between them, the
// picture staying still behind. A tick of the selection haptic on each arrival.
struct ContentView: View {
    @StateObject private var store = ConversationStore()
    @StateObject private var gallery = Gallery()
    @State private var page: Tab? = Tab.launch
    @State private var keyboard = false
    // The painting alone, asked for by a tap on Home's bare picture.
    @State private var alone = Tab.launch == .jharokha && ContentView.eyes?.hasPrefix("alone") == true
    // The clock goes with the wall and comes back only once the wall has.
    @State private var clockAway = Tab.launch == .jharokha && ContentView.eyes?.hasPrefix("alone") == true
    // A pinch on the painting alone: how far in, and from where.
    @GestureState(resetTransaction: Transaction(animation: .smooth)) private var pinch = Pinch()
    // A turn along the paintings while the painting stands alone.
    @State private var turned = 0
    // What the last hold on the painting alone came to, said for a moment.
    @State private var kept: Gallery.Kept?
    @State private var keeping = 0
    // How often the Mac wall turns to the next painting, from its menu.
    @AppStorage(WallPace.key) private var paceMinutes = WallPace.standard
    #if targetEnvironment(macCatalyst)
    // The lettering the clicks on the painting alone have chosen, over the
    // house's word until the next open; nil on the wall.
    @State private var handLetters: WallLetters?
    // Whether the opening step, the house's word, has been taken.
    @State private var opened = false
    #endif

    private struct Pinch: Equatable {
        var zoom: CGFloat = 1
        var anchor: UnitPoint = .center
    }

    private var tab: Tab { page ?? .jharokha }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // All three built at launch, so a first visit is a slide, not a fetch.
                HStack(spacing: 0) {
                    ForEach(Tab.shown, id: \.self) { t in
                        screen(t)
                            .containerRelativeFrame(.horizontal)
                            // A page keeps to its own width at any text size,
                            // never lettering over its neighbour.
                            .clipShape(Sides())
                            // Only the page in view is read out, by VoiceOver or anything else.
                            .accessibilityHidden(t != tab)
                            .id(t)
                    }
                }
                .scrollTargetLayout()
            }
            // The scroll position is not honoured on the first layout; the
            // launch tab is scrolled to once, without motion.
            .onAppear { proxy.scrollTo(Tab.launch) }
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        // Alone, the painting holds still; no swipe turns a page under it.
        .scrollDisabled(alone)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        // The keyboard covers the bar, as the system's own tab bar lets it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboard && Tab.shown.count > 1 { bar }
        }
        // Alone, every page, its shade and the bar step away; the picture stays.
        .opacity(alone ? 0 : 1)
        .allowsHitTesting(!alone)
        .overlay { if alone { looking } }
        #if targetEnvironment(macCatalyst)
        // On the wall the label never leaves: only the rest of the wall does.
        .overlay { WallLabel(letters: alone ? handLetters ?? WallLetters.of(gallery) : WallLetters.of(gallery)) }
        // The wall opens on the step the house's word names: off, the
        // painting alone and bare; basic or detailed, alone and so lettered.
        // A house that has said nothing opens on the wall.
        .onChange(of: gallery.painting?.key, initial: true) { _, key in
            guard !opened, key != nil else { return }
            opened = true
            guard !WallLetters.onWall, let word = WallLetters.word(gallery) else { return }
            handLetters = WallLetters(word)
            alone = true
        }
        // Onto the painting alone from the wall, bare first.
        .onChange(of: alone) { _, now in if now && handLetters == nil { handLetters = .off } }
        #endif
        .overlay { keptLine }
        // Alone, the home indicator steps back with the clock.
        .persistentSystemOverlays(alone ? .hidden : .automatic)
        .background { Painting(zoom: pinch.zoom, anchor: pinch.anchor) }
        .onChange(of: alone) { _, now in if now { clockAway = true } }
        .onChange(of: clockAway, initial: true) { _, away in Clock.hide(away) }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: alone)
        .sensoryFeedback(.impact(weight: .light), trigger: turned)
        // Success when the house takes the painting, a warning when it cannot.
        .sensoryFeedback(trigger: keeping) { _, _ in
            switch kept {
            case .kept, .already: return .success
            case .noDoor, .unheard: return .warning
            case nil: return nil
            }
        }
        .environment(\.paintingAlone, $alone)
        .sensoryFeedback(.selection, trigger: tab)
        .tint(Theme.giltOnArt)
        .environmentObject(store)
        .environmentObject(gallery)
        .task { await gallery.load() }
        // A tap on the widget (chintan://painting/ID) opens on the painting
        // alone: its work when the phone holds it, else Home's own.
        .onOpenURL { url in
            guard url.scheme == "chintan", url.host == "painting" else { return }
            let id = url.lastPathComponent
            withAnimation(.snappy) { page = .jharokha }
            Task {
                if !id.isEmpty, id != "/" { await gallery.choose(id: id) }
                withAnimation(.smooth) { alone = true }
            }
        }
        #if targetEnvironment(macCatalyst)
        // The wall turns on its own, at the pace set in its menu, each turn a
        // fresh work from the house; a turn by hand starts the wait again.
        .task(id: WallPace.Turn(minutes: paceMinutes, turned: turned)) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(WallPace.seconds(paceMinutes)))
                guard !Task.isCancelled else { return }
                await gallery.turnWall()
            }
        }
        .task {
            // For the house's eyes: `--clicks S` clicks the art every S
            // seconds, the way his hand would, round the four steps.
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "--clicks"), i + 1 < args.count,
                  let every = Double(args[i + 1]), every > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(every))
                if alone { click() } else { withAnimation(.smooth) { alone = true } }
                print("wall-step", alone ? "\(handLetters ?? .off)" : "wall")
                fflush(stdout)
            }
        }
        #endif
        .task {
            // For the house's eyes: `--open alone-back` leaves the painting
            // alone, then brings the wall back, as a tap would;
            // `--open alone-yesterday` swipes back a painting instead, and
            // `alone-yesterday-back` then brings the wall back over it.
            guard let eyes = ContentView.eyes, eyes.hasPrefix("alone-") else { return }
            try? await Task.sleep(for: .seconds(2))
            // `alone-kept` holds the painting as if the house had taken it,
            // asking nothing of the house; `alone-keep` asks it for real.
            // Held at four seconds, so the answer stands when the eyes look at six.
            if eyes == "alone-keep" || eyes == "alone-kept" {
                try? await Task.sleep(for: .seconds(2))
                keep(staged: eyes == "alone-kept")
                return
            }
            if eyes.hasPrefix("alone-yesterday") {
                walk(-1)
                try? await Task.sleep(for: .seconds(1.5))
            }
            if eyes.hasSuffix("back") { back() }
        }
        .task {
            // The hitch meter's walk with no hand; a phone never passes this.
            guard ProcessInfo.processInfo.arguments.contains("--self-walk") else { return }
            await HitchMeter.shared.walk { t in withAnimation(.snappy) { page = t } }
        }
        // Hidden only under a keyboard tall enough to cover it, not a
        // hardware keyboard's thin strip.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboard = UIScreen.main.bounds.height - end.minY > 120
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboard = false }
    }

    @ViewBuilder private func screen(_ t: Tab) -> some View {
        switch t {
        // Each page says when it is unchanged, so a turn letters only what moved.
        case .jharokha: JharokhaView().equatable()
        case .board: BoardView().equatable()
        case .study: StudyView(open: tab == .study).equatable()
        }
    }

    // The painting alone: a pinch looks closer and springs back when let go;
    // a swipe walks the paintings the phone holds, to the right back to
    // yesterday's, to the left on to the days ahead; a press and hold keeps
    // it in the vault's baithak; a tap anywhere brings the wall back.
    private var looking: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            // The walk holds with `--keep-staged`, so its hold never files a work.
            .onLongPressGesture(minimumDuration: 0.6, maximumDistance: 12) {
                keep(staged: ProcessInfo.processInfo.arguments.contains("--keep-staged"))
            }
            .onTapGesture { click() }
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in
                        if state.zoom == 1 { state.anchor = value.startAnchor }
                        state.zoom = min(max(value.magnification, 1), 4)
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard pinch.zoom == 1, abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                        walk(dx > 0 ? -1 : 1)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(gallery.painting?.title ?? "The painting")
            .accessibilityValue(gallery.showingYesterday ? "Yesterday's" : "")
            .accessibilityHint("Double tap to bring the day back. Swipe up or down to turn.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { back() }
            .accessibilityAction(named: "Keep this painting") { keep() }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: walk(1)
                case .decrement: walk(-1)
                @unknown default: break
                }
            }
    }

    // The hold's answer below the work, in the screen's foot where the home
    // indicator stood, over a short shade: gilt when kept, saffron when not,
    // gone after a few seconds. Never on the painting itself.
    private var keptLine: some View {
        GeometryReader { g in
            let foot = max(g.safeAreaInsets.bottom, 20)
            if let kept {
                let (words, gilt): (String, Bool) = switch kept {
                case .kept: ("Kept, in the baithak", true)
                case .already: ("Already in the baithak", true)
                case .noDoor: ("The house cannot keep it yet", false)
                case .unheard: ("The house is not answering", false)
                }
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(words)
                        .font(Theme.label(.caption))
                        .tracking(1)
                        .foregroundStyle(gilt ? Theme.giltOnArt : Theme.saffron)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        // The top of the foot, clear of the indicator a touch brings back.
                        .padding(.top, 2)
                        .frame(maxWidth: .infinity)
                        .frame(height: foot, alignment: .top)
                        .background(alignment: .bottom) {
                            LinearGradient(colors: [Theme.lampBlack.opacity(0.78), Theme.lampBlack.opacity(0)],
                                           startPoint: .bottom, endPoint: .top)
                                .frame(height: foot * 2.4)
                        }
                        .offset(y: g.safeAreaInsets.bottom)
                }
                .transition(.opacity)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
        }
    }

    private func keep(staged: Bool = false) {
        Task {
            let answer = await gallery.keep(staged: staged)
            withAnimation(.smooth) { kept = answer }
            keeping += 1
            let said = switch answer {
            case .kept: "Kept, in the baithak"
            case .already: "Already in the baithak"
            case .noDoor: "Not kept. The house cannot keep paintings yet"
            case .unheard: "Not kept. The house is not answering"
            }
            UIAccessibility.post(notification: .announcement, argument: said)
            let shown = keeping
            try? await Task.sleep(for: .seconds(3.5))
            if keeping == shown { withAnimation(.smooth) { kept = nil } }
        }
    }

    private func walk(_ by: Int) {
        Task {
            if await gallery.turn(by) {
                turned += 1
                return
            }
            #if targetEnvironment(macCatalyst)
            // Past the newest work the wall has hung, the house's next.
            if by > 0, await gallery.turnWall() { turned += 1 }
            #endif
        }
    }

    // A tap on the painting alone brings the wall back. On the Mac a click
    // steps instead (Prab, 2026-09-27 18:18): bare, then the basic label,
    // then the detailed one, then the wall again.
    private func click() {
        #if targetEnvironment(macCatalyst)
        switch handLetters ?? WallLetters.of(gallery) {
        case .off: withAnimation(.smooth) { handLetters = .basic }; return
        case .basic: withAnimation(.smooth) { handLetters = .detailed }; return
        case .detailed: break
        }
        #endif
        back()
    }

    private func back() {
        withAnimation(.smooth) {
            alone = false
            #if targetEnvironment(macCatalyst)
            handLetters = nil
            #endif
        } completion: { clockAway = false }
    }

    // For the house's eyes: `--open alone` on Home opens on the painting alone.
    private static var eyes: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--open"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    // The tab bar lettered on the art: bone icons, the one open in gilt,
    // names in small serif capitals, nothing behind them but the picture.
    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                let open = t == tab
                Button {
                    withAnimation(.snappy) { page = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.symbol)
                            .symbolVariant(open ? .fill : .none)
                            .font(.title3)
                            .frame(minHeight: 26)
                        Text(t.name)
                            .font(.system(.caption2, design: .serif).weight(.medium).lowercaseSmallCaps())
                            .tracking(0.6)
                    }
                    .foregroundStyle(open ? Theme.giltOnArt : Theme.bone.opacity(0.72))
                    .frame(maxWidth: .infinity, minHeight: 49)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.name)
                .accessibilityAddTraits(open ? .isSelected : [])
                // As the system's tab bar does: a press and hold shows the name large.
                .accessibilityShowsLargeContentViewer()
            }
        }
        // The bar holds the system tab bar's size; past it, the large viewer.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.top, 6)
    }
}

// The clock is the app's, not a page's: always bone (Info.plist, light
// content, not asked of each screen), so it never turns black when a page
// comes back in light mode. Hidden the same way, for the painting alone:
// the app's own switch, old but the only one when no screen is asked.
private protocol ClockHiding { static func hide(_ away: Bool) }
private enum Clock: ClockHiding {
    static func hide(_ away: Bool) { (Old.self as ClockHiding.Type).hide(away) }
}
private enum Old: ClockHiding {
    @available(iOS, deprecated: 9.0)
    static func hide(_ away: Bool) {
        // The Mac's wall has no clock of the app's to hide.
        #if !targetEnvironment(macCatalyst)
        UIApplication.shared.setStatusBarHidden(away, with: .fade)
        #endif
    }
}

// How often the Mac wall turns: 5, 15, 30 or 60 minutes, 15 unless changed
// in the wall's menu. `--turn SECONDS` is the house's eyes' own quick pace.
enum WallPace {
    static let key = "wall.minutes"
    static let standard = 15
    static let choices = [5, 15, 30, 60]

    struct Turn: Equatable {
        let minutes: Int
        let turned: Int
    }

    static func seconds(_ minutes: Int) -> Double {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--turn"), i + 1 < args.count, let s = Double(args[i + 1]), s > 0 { return s }
        return Double(choices.contains(minutes) ? minutes : standard) * 60
    }
}

#if targetEnvironment(macCatalyst)
// The wall's label: the title, the artist, the year and the credit, small in
// the bottom right corner over a short shade, the way a museum letters a
// wall. One view over the wall and the painting alone alike, so a click that
// puts the wall away leaves it exactly where it stood (Prab, 2026-09-27
// 13:14: the same view, same place, same size). It changes with the
// painting, as slowly as the painting does, and letters it as the house says.
private struct WallLabel: View {
    @EnvironmentObject private var gallery: Gallery
    let letters: WallLetters

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if letters != .off {
                RadialGradient(colors: [Theme.lampBlack.opacity(0.64), Theme.lampBlack.opacity(0)],
                               center: .bottomTrailing, startRadius: 0,
                               endRadius: WallLettering.unit * (letters == .detailed ? 460 : 320))
                    .transition(.opacity)
            }
            if letters != .off, let p = gallery.painting, p.title != nil {
                WallLettering(painting: p, letters: letters)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(.trailing, WallLettering.trailing)
                    .padding(.bottom, WallLettering.bottom)
                    .id(p.key + "\(letters)")
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 2.6), value: gallery.painting?.key)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// How the wall letters its work, the house's setting, not the Mac's (Prab,
// 2026-09-27 18:05): none at all; basic, the title and the artist and year,
// small; detailed, the medium, the credit and the museum as well. Carried on
// each work the house hangs, so a change shows at the next turn; a work from
// the shelf takes the word of the last one hung, basic before any.
enum WallLetters {
    case off, basic, detailed

    init(_ word: String?) {
        switch word?.lowercased() {
        case "off": self = .off
        case "detailed": self = .detailed
        default: self = .basic
        }
    }

    @MainActor static func of(_ gallery: Gallery) -> WallLetters { WallLetters(word(gallery)) }

    // The house's word, nil when it has said none. `--letters WORD` is the
    // house's eyes' own, to see each lettering.
    @MainActor static func word(_ gallery: Gallery) -> String? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--letters"), i + 1 < args.count { return args[i + 1] }
        return gallery.painting?.label ?? gallery.hung.last?.label
    }

    // `--step wall`: the eyes open on the wall whatever the house's word.
    static var onWall: Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--step"), i + 1 < args.count else { return false }
        return args[i + 1] == "wall"
    }
}

// The label's lettering, at the Linux wall's scale (the house, 2026-09-27:
// the title 14 and the rest 10 at 1080 high, a 3.5 percent margin), so the
// two walls letter alike. Home lays it unseen in its foot as well, so the
// wall keeps the label's room and its hairline stands above it, never through.
struct WallLettering: View {
    let painting: HouseClient.Painting
    var letters: WallLetters = .basic
    // One point of a 1080 high wall, on this screen.
    static var unit: CGFloat { UIScreen.main.bounds.height / 1080 }
    // From the screen's bottom right corner.
    static var trailing: CGFloat { UIScreen.main.bounds.height * 0.035 }
    static var bottom: CGFloat { UIScreen.main.bounds.height * 0.035 }
    private var titleSize: CGFloat { 14 * Self.unit }
    private var restSize: CGFloat { 10 * Self.unit }

    var body: some View {
        switch letters {
        case .off: EmptyView()
        case .basic: basic
        case .detailed: detailed
        }
    }

    private var title: String { (painting.title ?? "").plainDashes }
    private var artist: String { (painting.artist ?? "").plainDashes }
    private var year: String { (painting.year ?? "").plainDashes }

    // The title in italic, the artist and the year under it, small.
    private var basic: some View {
        VStack(alignment: .trailing, spacing: 2 * Self.unit) {
            Text(title)
                .font(.system(size: titleSize, design: .serif).italic())
                .foregroundStyle(Theme.bone)
            if !artist.isEmpty || !year.isEmpty {
                (Text(artist).foregroundStyle(Theme.bone.opacity(0.88))
                 + Text(!artist.isEmpty && !year.isEmpty ? ", " : "").foregroundStyle(Theme.bone.opacity(0.88))
                 + Text(year).foregroundStyle(Theme.giltOnArt))
                    .font(.system(size: restSize, design: .serif))
            }
        }
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.22, alignment: .trailing)
    }

    // The museum's full card: title, artist, the year in gilt, the medium,
    // the credit and the museum, wrapped under 28 percent of the wall.
    private var detailed: some View {
        VStack(alignment: .trailing, spacing: 2 * Self.unit) {
            Text(title)
                .font(.system(size: titleSize, design: .serif).italic())
                .foregroundStyle(Theme.bone)
            if !artist.isEmpty {
                Text(artist)
                    .font(.system(size: restSize, design: .serif))
                    .foregroundStyle(Theme.bone.opacity(0.9))
            }
            if !year.isEmpty {
                Text(year)
                    .font(.system(size: restSize, design: .serif).smallCaps())
                    .tracking(0.6)
                    .foregroundStyle(Theme.giltOnArt)
            }
            if let medium = painting.medium, !medium.isEmpty {
                Text(medium.plainDashes)
                    .font(.system(size: restSize, design: .serif))
                    .foregroundStyle(Theme.bone.opacity(0.78))
                    .padding(.top, 3 * Self.unit)
            }
            if let credit = painting.credit, !credit.isEmpty {
                Text(credit.plainDashes)
                    .font(.system(size: restSize, design: .serif))
                    .foregroundStyle(Theme.bone.opacity(0.66))
            }
            if let museum {
                Text(museum)
                    .font(.system(size: restSize, design: .serif).smallCaps())
                    .tracking(0.8)
                    .foregroundStyle(Theme.bone.opacity(0.66))
            }
        }
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.28, alignment: .trailing)
    }

    // The museum by its name, only when the credit does not already say it.
    private var museum: String? {
        guard let source = painting.source?.trimmingCharacters(in: .whitespaces),
              source.contains(" "), !(painting.credit ?? "").localizedCaseInsensitiveContains(source) else { return nil }
        return source.plainDashes
    }
}
#endif

// A page's clip at its left and right edges only; its shade still runs up
// under the clock and down under the bar.
private struct Sides: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -rect.height))
    }
}
