import SwiftUI

// A word for the house: one line from him about the screen he is on, which
// becomes the next sprint's steer (POST /v1/word). On a plaque above the
// keyboard; a word the house cannot hear is said plainly and stays in the
// field to send again.
struct HouseWord: View {
    // The house's name for the screen, and his.
    let screen: String
    let place: String
    let close: () -> Void
    @State private var text = ""
    @State private var state = Sending.writing
    @State private var heard = 0
    @FocusState private var focused: Bool

    enum Sending: Equatable { case writing, sending, heard, unheard(String) }

    private var words: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("A word for the house")
                    .font(Theme.label(.caption))
                    .tracking(0.8)
                    .foregroundStyle(Theme.gilt)
                Text("on " + place)
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.7))
                Spacer(minLength: 8)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // The mark is small; what a finger finds is not.
                .padding(-14)
                .accessibilityLabel("Put away")
            }
            if state == .heard {
                Text("The house has it.")
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(Theme.ink)
                    .transition(.opacity)
            } else {
                // One line, the send beside it; the words run to four lines
                // before they scroll.
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(spacing: 8) {
                        TextField("", text: $text, prompt: Text("What should change here").foregroundStyle(Theme.ink.opacity(0.45)), axis: .vertical)
                            .font(.system(.body, design: .serif))
                            .lineLimit(1...4)
                            .foregroundStyle(Theme.ink)
                            .tint(Theme.gilt)
                            .focused($focused)
                            .accessibilityIdentifier("word")
                        Rectangle()
                            .fill(Theme.gilt.opacity(0.45))
                            .frame(height: 0.5)
                            .accessibilityHidden(true)
                    }
                    .padding(.bottom, 6)
                    SettingsAction(state == .sending ? "Sending" : "Send", run: send)
                        .disabled(words.isEmpty || state == .sending)
                        .fixedSize()
                }
                if case .unheard(let why) = state {
                    Text(why)
                        .font(.footnote)
                        .foregroundStyle(Theme.saffron)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 440, alignment: .leading)
        .background(Theme.plaque, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .plaque(radius: 12)
        .sensoryFeedback(.success, trigger: heard)
        .onAppear { focused = true }
    }

    private func send() {
        let said = words
        guard !said.isEmpty, state != .sending else { return }
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            state = .unheard("No house address yet. Add it in Settings.")
            return
        }
        state = .sending
        Task {
            do {
                try await HouseClient(baseAddress: address).word(said, on: screen)
                focused = false
                withAnimation(.snappy) { state = .heard }
                heard += 1
                try? await Task.sleep(for: .seconds(1.4))
                close()
            } catch HouseError.noDoor {
                state = .unheard("The house has no door for words yet.")
            } catch {
                state = .unheard("The house is not answering. Are you on the tailnet?")
            }
        }
    }
}
