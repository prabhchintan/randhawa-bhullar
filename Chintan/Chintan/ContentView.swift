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
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        // The keyboard covers the bar, as the system's own tab bar lets it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboard { bar }
        }
        .background { Painting() }
        .sensoryFeedback(.selection, trigger: tab)
        .tint(Theme.giltOnArt)
        .environmentObject(store)
        .environmentObject(gallery)
        .task { await gallery.load() }
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
        case .jharokha: JharokhaView()
        case .board: BoardView()
        case .study: StudyView(open: tab == .study)
        }
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

// A page's clip at its left and right edges only; its shade still runs up
// under the clock and down under the bar.
private struct Sides: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -rect.height))
    }
}
