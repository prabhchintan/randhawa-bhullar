import SwiftUI
import UIKit

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

// The last line of a held plaque, framed like a thing to press: a word for
// the house. Under the thumb it fills with gilt, the plaque's ink on it, as
// a chosen line in a held menu does. It says where it stands in the named
// space, so a slide can find it.
struct WordLine: View {
    let onWord: Bool
    let space: String
    let placed: (CGRect) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.footnote)
            Text("A word for the house")
                .font(.system(.subheadline, design: .serif).weight(.semibold).lowercaseSmallCaps())
                .tracking(0.8)
        }
        .foregroundStyle(onWord ? Theme.plaque : Theme.gilt)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Theme.gilt.opacity(onWord ? 1 : 0.07)))
        .overlay(shape.strokeBorder(Theme.gilt.opacity(onWord ? 1 : 0.5), lineWidth: 1))
        .scaleEffect(onWord ? 1.03 : 1)
        .animation(.snappy(duration: 0.15), value: onWord)
        .padding(.top, 6)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { placed($0) }
        .onDisappear { placed(.zero) }
    }

    // The line and a little around it, so a thumb need not be exact.
    static func over(_ line: CGRect, _ point: CGPoint) -> Bool {
        !line.isEmpty && line.insetBy(dx: -12, dy: -14).contains(point)
    }
}

// The stage for a word: while it is written the screen's own lettering steps
// away and the painting alone stands behind the composer, so the keyboard
// never lifts the screen's lines over the picture. A tap on the painting, or
// the composer's x, puts it away.
struct WordStage: ViewModifier {
    @Binding var wording: Bool
    let screen: String
    let place: String

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                .opacity(wording ? 0 : 1)
            if wording {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture(perform: putAway)
                    .accessibilityHidden(true)
                    .transition(.opacity)
                HouseWord(screen: screen, place: place, close: putAway)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func putAway() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.snappy) { wording = false }
    }
}

extension View {
    // A word for the house, from this screen: "home", "board", "study".
    func wordStage(_ wording: Binding<Bool>, screen: String, place: String) -> some View {
        modifier(WordStage(wording: wording, screen: screen, place: place))
    }
}
