import SwiftUI

// His marks (Prab, 2026-11-21 13:01: "more of something or less of something
// or upvote or downvote or bookmark ... capture my feedback and incorporate
// it in your cycles"). One small row under a thing: more, less, keep, and a
// few words of his own. The house never asks for a mark; the row is there
// when he wants it. What he marked is held on the phone so the row shows it,
// and told to the house (POST /v1/mark); a mark the house did not hear waits
// and goes with the next.
@MainActor final class Marks: ObservableObject {
    static let shared = Marks()

    @Published private(set) var held: Set<String>
    private var waiting: [Data]

    private static let heldKey = "marks.held"
    private static let waitingKey = "marks.waiting"
    // The house's eyes leave no marks.
    private static let quiet = ProcessInfo.processInfo.arguments.contains("--house")
        || ProcessInfo.processInfo.arguments.contains("--self-walk")

    private init() {
        held = Set(UserDefaults.standard.stringArray(forKey: Self.heldKey) ?? [])
        waiting = (UserDefaults.standard.array(forKey: Self.waitingKey) as? [Data]) ?? []
    }

    private static func key(_ surface: String, _ thing: String, _ mark: String) -> String { surface + "\u{1F}" + thing + "\u{1F}" + mark }

    func has(_ surface: String, _ thing: String, _ mark: String) -> Bool { held.contains(Self.key(surface, thing, mark)) }

    private struct Body: Encodable {
        let surface: String
        let thing: String
        let mark: String
        let on: Bool
        let title: String
        let words: String
        let url: String
    }

    // More and less are one dial: the one put on takes the other off.
    func toggle(_ surface: String, _ thing: String, _ mark: String, title: String, url: String = "") {
        let k = Self.key(surface, thing, mark)
        let on = !held.contains(k)
        if on {
            held.insert(k)
            if mark == "more" { held.remove(Self.key(surface, thing, "less")) }
            if mark == "less" { held.remove(Self.key(surface, thing, "more")) }
        } else {
            held.remove(k)
        }
        // A year of marks is a few hundred keys; the oldest are let go past that.
        UserDefaults.standard.set(Array(held.prefix(2000)), forKey: Self.heldKey)
        if mark == "more", on { send(Body(surface: surface, thing: thing, mark: "less", on: false, title: title, words: "", url: "")) }
        if mark == "less", on { send(Body(surface: surface, thing: thing, mark: "more", on: false, title: title, words: "", url: "")) }
        send(Body(surface: surface, thing: thing, mark: mark, on: on, title: title, words: "", url: url))
    }

    // A mark told at once and its answer awaited, for a gesture that must say
    // what came of it (the like on the painting alone). Held only once the
    // house has heard, so the phone never shows a mark the house lacks.
    // `staged` answers as the house would, unasked, for the house's own eyes.
    func tell(_ surface: String, _ thing: String, _ mark: String, on: Bool, title: String, staged: Bool = false) async -> HouseClient.Told {
        if !staged {
            guard !Self.quiet, let address = Keychain.loadHouseAddress(), !address.isEmpty,
                  let data = try? JSONEncoder().encode(Body(surface: surface, thing: thing, mark: mark, on: on, title: title, words: "", url: ""))
            else { return .unheard }
            let told = await HouseClient(baseAddress: address).mark(data)
            guard told == .heard else { return told }
        }
        let k = Self.key(surface, thing, mark)
        if on { held.insert(k) } else { held.remove(k) }
        if on, mark == "more" { held.remove(Self.key(surface, thing, "less")) }
        UserDefaults.standard.set(Array(held.prefix(2000)), forKey: Self.heldKey)
        return .heard
    }

    func say(_ surface: String, _ thing: String, title: String, words: String) {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        send(Body(surface: surface, thing: thing, mark: "say", on: true, title: title, words: text, url: ""))
    }

    private func send(_ body: Body) {
        guard !Self.quiet, let data = try? JSONEncoder().encode(body) else { return }
        waiting.append(data)
        if waiting.count > 200 { waiting.removeFirst(waiting.count - 200) }
        UserDefaults.standard.set(waiting, forKey: Self.waitingKey)
        flush()
    }

    // Everything waiting, in order; what the house did not hear stays.
    func flush() {
        guard !waiting.isEmpty, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        let batch = waiting
        Task {
            let house = HouseClient(baseAddress: address)
            var heard = 0
            for data in batch {
                if await house.mark(data) == .unheard { break }
                heard += 1
            }
            if heard > 0 {
                waiting.removeFirst(min(heard, waiting.count))
                UserDefaults.standard.set(waiting, forKey: Self.waitingKey)
            }
        }
    }
}

// The row itself: three small glyphs and a pencil, quiet until touched.
struct MarkRow: View {
    let surface: String
    let thing: String
    let title: String
    var url: String = ""
    var ink: Color = Theme.ink

    @ObservedObject private var marks = Marks.shared
    @State private var writing = false
    @State private var words = ""
    @State private var said = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                glyph("more", "arrow.up", "More of this")
                glyph("less", "arrow.down", "Less of this")
                glyph("keep", marks.has(surface, thing, "keep") ? "bookmark.fill" : "bookmark", "Keep")
                Button {
                    withAnimation(.snappy) { writing.toggle() }
                    focused = writing
                } label: {
                    Image(systemName: said ? "checkmark" : "pencil.line")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(writing || said ? Theme.gilt : ink.opacity(0.38))
                        .frame(width: 38, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Say something about this")
            }
            .padding(.leading, -12)
            if writing {
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("A word on this", text: $words, axis: .vertical)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(1...5)
                        .focused($focused)
                    Button("Send") {
                        marks.say(surface, thing, title: title, words: words)
                        words = ""
                        focused = false
                        withAnimation(.snappy) { writing = false; said = true }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.gilt)
                    .buttonStyle(.plain)
                    .disabled(words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.gilt.opacity(0.5), lineWidth: 0.5))
            }
        }
        .sensoryFeedback(.selection, trigger: marks.held.count)
    }

    private func glyph(_ mark: String, _ symbol: String, _ label: String) -> some View {
        let on = marks.has(surface, thing, mark)
        return Button {
            marks.toggle(surface, thing, mark, title: title, url: url)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.gilt : ink.opacity(0.38))
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
