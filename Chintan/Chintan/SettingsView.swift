import SwiftUI

// The house address, typed once and kept in the Keychain, a health check
// that says plainly whether the house is home, and where he is. Hung on the
// day's painting like the guest book: each room named on a smoked mount, what
// it holds on a plaque, the picture seen around them.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address: String = Keychain.loadHouseAddress() ?? ""
    @State private var status: String?
    @State private var checking = false

    private var typed: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            head
            ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    SettingsRoom("The house") {
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            TextField("http://100.x.x.x:port", text: $address)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .foregroundStyle(Theme.ink)
                                // The house's eyes never photograph the address.
                                .redacted(reason: Keychain.override == nil ? [] : .placeholder)
                            SettingsAction("Save") {
                                Keychain.saveHouseAddress(typed)
                                status = nil
                            }
                            .disabled(typed.isEmpty)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Theme.ink.opacity(0.18))
                                .frame(height: 0.5)
                                .accessibilityHidden(true)
                        }
                        HStack(spacing: 16) {
                            SettingsAction("Is it home?") {
                                Task { await checkHealth() }
                            }
                            .disabled(checking || typed.isEmpty)
                            if checking {
                                ProgressView()
                            } else if let status {
                                Text(status)
                                    .font(.system(.body, design: .serif).italic())
                                    .foregroundStyle(Theme.ink.opacity(0.8))
                            }
                        }
                    }
                    // What the phone tells the house, gathered: each sense its own
                    // room, each asked for there and each his to stop.
                    Text("The senses")
                        .font(.system(.title, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.bone)
                        .shadow(color: .black.opacity(0.7), radius: 10)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 8)
                        .padding(.bottom, -12)
                        .id("senses")
                    WhereaboutsSection()
                    PhoneWordSection()
                    HealthSection()
                    MotionSection()
                        .id("motion")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .fadedEdges(top: 16, bottom: 24)
            // For the house's eyes: `--open senses` opens on the senses,
            // `--open motion` at the foot, on How you move; `--open apps` on Which app
            // you open.
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                guard let i = args.firstIndex(of: "--open"), i + 1 < args.count else { return }
                switch args[i + 1] {
                case "senses": reader.scrollTo("senses", anchor: .top)
                case "motion": reader.scrollTo("motion", anchor: .bottom)
                case "apps": reader.scrollTo("apps", anchor: .top)
                default: break
                }
            }
            }
        }
        .background {
            ZStack {
                Painting()
                PaintedGround(head: 220, foot: 260, footShade: 0.5)
            }
        }
    }

    // The sheet's head, lettered on the painting above the scroll rather
    // than by a clear navigation bar, so the wall never runs through Done.
    private var head: some View {
        ZStack {
            Text("Settings")
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.bone)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Done") { dismiss() }
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.giltOnArt)
                    .frame(minHeight: 44)
                Spacer()
            }
        }
        .shadow(color: .black.opacity(0.7), radius: 8)
        .padding(.horizontal, 22)
        .frame(minHeight: 56)
        // Held at the system bar's largest size, so Done and the title never meet.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func checkHealth() async {
        checking = true
        defer { checking = false }
        do {
            let health = try await HouseClient(baseAddress: address).health()
            status = health.ok ? "chintan is home." : "The house answered, but not well."
        } catch {
            status = "The house is not answering. Are you on the tailnet?"
        }
    }
}

// A room of the settings wall: its name in gilt small capitals on a mount,
// then a plaque with what it holds and a note in the body's quiet ink.
struct SettingsRoom<Content: View>: View {
    let name: String
    let note: String?
    @ViewBuilder let content: Content

    init(_ name: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.name = name
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(Theme.label())
                .tracking(1)
                .foregroundStyle(Theme.giltOnArt)
                .accessibilityAddTraits(.isHeader)
                .mount()
            VStack(alignment: .leading, spacing: 14) {
                content
                if let note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plaque()
        }
    }
}

// What the house last heard, in the serif, its hour in gilt beside it; at the
// accessibility sizes the hour stands under the words, so neither breaks.
struct HeardLine: View {
    let words: String
    let hour: String
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        let layout = size.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
        layout {
            Text(words)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(hour)
                .font(Theme.label(.subheadline))
                .tracking(0.6)
                .foregroundStyle(Theme.gilt)
        }
        .accessibilityElement(children: .combine)
    }
}

// A thing to press on the wall: its name in small serif capitals inside a
// gilt hairline frame, square cornered like a wall label, or the quiet ink
// for a thing that stops. It darkens under the thumb and ticks.
struct SettingsAction: View {
    let title: String
    var quiet = false
    let run: () -> Void
    @Environment(\.isEnabled) private var enabled
    @State private var pressed = 0

    init(_ title: String, quiet: Bool = false, run: @escaping () -> Void) {
        self.title = title
        self.quiet = quiet
        self.run = run
    }

    var body: some View {
        Button {
            pressed += 1
            run()
        } label: {
            Text(title)
        }
        .buttonStyle(Framed(tone: quiet ? Theme.ink.opacity(0.72) : Theme.gilt))
        .opacity(enabled ? 1 : 0.4)
        .sensoryFeedback(.selection, trigger: pressed)
    }

    private struct Framed: ButtonStyle {
        let tone: Color

        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
            configuration.label
                .font(.system(.subheadline, design: .serif).weight(.semibold).lowercaseSmallCaps())
                .tracking(0.8)
                .foregroundStyle(tone)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(shape.fill(tone.opacity(configuration.isPressed ? 0.2 : 0.07)))
                .overlay(shape.strokeBorder(tone.opacity(0.6), lineWidth: 1))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
    }
}

// A room's things to press, side by side, or one under another when the
// words are too large to share a line.
struct SettingsActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { content }
            VStack(alignment: .leading, spacing: 4) { content }
        }
    }
}
