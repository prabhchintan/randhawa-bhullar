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
                    ForEach(Tab.allCases, id: \.self) { t in
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
            if !keyboard { bar }
        }
        // Alone, every page, its shade and the bar step away; the picture stays.
        .opacity(alone ? 0 : 1)
        .allowsHitTesting(!alone)
        .overlay { if alone { looking } }
        .background { Painting(zoom: pinch.zoom, anchor: pinch.anchor) }
        .onChange(of: alone) { _, now in if now { clockAway = true } }
        .onChange(of: clockAway, initial: true) { _, away in Clock.hide(away) }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: alone)
        .sensoryFeedback(.impact(weight: .light), trigger: turned)
        .environment(\.paintingAlone, $alone)
        .sensoryFeedback(.selection, trigger: tab)
        .tint(Theme.giltOnArt)
        .environmentObject(store)
        .environmentObject(gallery)
        .task { await gallery.load() }
        .task {
            // For the house's eyes: `--open alone-back` leaves the painting
            // alone, then brings the wall back, as a tap would;
            // `--open alone-yesterday` swipes back a painting instead, and
            // `alone-yesterday-back` then brings the wall back over it.
            guard let eyes = ContentView.eyes, eyes.hasPrefix("alone-") else { return }
            try? await Task.sleep(for: .seconds(2))
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
    // yesterday's, to the left on to the days ahead; a tap anywhere brings
    // the wall back.
    private var looking: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture { back() }
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
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: walk(1)
                case .decrement: walk(-1)
                @unknown default: break
                }
            }
    }

    private func walk(_ by: Int) {
        Task { if await gallery.turn(by) { turned += 1 } }
    }

    private func back() {
        withAnimation(.smooth) { alone = false } completion: { clockAway = false }
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
        UIApplication.shared.setStatusBarHidden(away, with: .fade)
    }
}

// A page's clip at its left and right edges only; its shade still runs up
// under the clock and down under the bar.
private struct Sides: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -rect.height))
    }
}
