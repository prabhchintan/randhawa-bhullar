import SwiftUI

// The house address, typed once and kept in the Keychain, a health check
// that says plainly whether the house is home, and where he is. Lettered as
// a wall: each room named in gilt over a hairline, no grey cards.
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
                VStack(alignment: .leading, spacing: 40) {
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
                        HStack(alignment: .firstTextBaseline, spacing: 20) {
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
                        .font(.system(.title2, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 12)
                        .padding(.bottom, -16)
                        .id("senses")
                    WhereaboutsSection()
                    PhoneWordSection()
                    HealthSection()
                    MotionSection()
                        .id("motion")
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
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
        .background(Theme.ground)
    }

    // The sheet's head, drawn here on the ground rather than by a clear
    // navigation bar, so the wall scrolls under it, never through Done.
    private var head: some View {
        ZStack {
            Text("Settings")
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Done") { dismiss() }
                    .frame(minHeight: 44)
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .frame(minHeight: 56)
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

// A room of the settings wall: its name in gilt small capitals over a
// hairline, what it holds, and a note in the body's quiet ink.
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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(Theme.label(.subheadline))
                    .tracking(1.4)
                    .foregroundStyle(Theme.gilt)
                    .accessibilityAddTraits(.isHeader)
                Rectangle()
                    .fill(Theme.gilt.opacity(0.4))
                    .frame(height: 0.5)
                    .accessibilityHidden(true)
            }
            content
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
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

// A thing to press on the wall: its name in small serif capitals, gilt, or
// the quiet ink for a thing that stops.
struct SettingsAction: View {
    let title: String
    var quiet = false
    let run: () -> Void
    @Environment(\.isEnabled) private var enabled

    init(_ title: String, quiet: Bool = false, run: @escaping () -> Void) {
        self.title = title
        self.quiet = quiet
        self.run = run
    }

    var body: some View {
        Button(action: run) {
            Text(title)
                .font(.system(.body, design: .serif).weight(.medium).lowercaseSmallCaps())
                .tracking(0.8)
                .foregroundStyle(quiet ? Theme.ink.opacity(0.7) : Theme.gilt)
                .opacity(enabled ? 1 : 0.4)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
