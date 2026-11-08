import SwiftUI
import Observation

// Your word: the decisions the house has drawn up for him, on a shelf at the
// head of the Board, shown only while one waits. Three shapes: haan (a yes
// or a no), chon (a choice among the house's options, none of these always
// among them) and raay (his opinion in his own words). Every card carries a
// comment, which the house reads as closely as the answer.
struct Faisla: Decodable, Identifiable, Equatable {
    struct Option: Decodable, Equatable {
        let key: String
        let label: String
        let line: String?
        enum CodingKeys: String, CodingKey { case key, label, line = "case" }
    }

    struct Evidence: Decodable, Equatable {
        let url: String
        let kind: String?
        let caption: String?
        var picture: Bool {
            let k = (kind ?? "").lowercased()
            if k.isEmpty { return [".jpg", ".jpeg", ".png", ".heic", ".gif"].contains { url.lowercased().hasSuffix($0) } }
            return k.hasPrefix("image") || k == "picture" || k == "photo" || k == "screenshot"
        }
    }

    let id: String
    let shape: String
    let title: String
    let question: String
    let options: [Option]?
    let house: String?
    let evidence: [Evidence]?
    let due: String?
    let fallback: String?
    enum CodingKeys: String, CodingKey {
        case id, shape, title, question, options, house, evidence, due, fallback = "default"
    }

    // The choices as drawn, with none of these closing them when the house
    // left it off.
    var choices: [Option] {
        let given = options ?? []
        if given.contains(where: { $0.key == "none" }) { return given }
        return given + [Option(key: "none", label: "None of these", line: nil)]
    }

    // The house's own lean, in a line.
    var lean: String? {
        guard let house, !house.isEmpty else { return nil }
        switch shape {
        case "haan": return "The house leans " + (house.lowercased() == "yes" ? "yes." : house.lowercased() == "no" ? "no." : house + ".")
        case "chon": return "The house leans to " + (choices.first { $0.key == house }?.label ?? house) + "."
        default: return "The house's own: " + house
        }
    }

    var dueDay: Date? {
        guard let due else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(due.prefix(10)))
    }
}

// The open queue as the house last said it. A house without the door, or
// out of reach, leaves the shelf as it stood; an empty queue puts it away.
@MainActor @Observable
final class FaislaQueue {
    var items: [Faisla] = []

    func read(_ house: HouseClient) async {
        guard let url = house.houseURL("/v1/faisla") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        struct Queue: Decodable { let faisla: [Faisla] }
        guard let fresh = try? JSONDecoder().decode(Queue.self, from: data).faisla else { return }
        if fresh != items { withAnimation(.snappy) { items = fresh } }
    }

    func taken(_ id: String) {
        withAnimation(.snappy(duration: 0.4)) { items.removeAll { $0.id == id } }
    }
}

// What the door says when it will not take an answer, in its own words.
struct FaislaRefusal: Error { let text: String }

extension HouseClient {
    // {id, decision, comment, via: "app"}; 200 when the house has it. A 4xx
    // carries the door's reason, said on the card as the door said it.
    func answer(_ id: String, decision: String, comment: String) async throws {
        guard let url = houseURL("/v1/faisla/answer") else { throw HouseError.noAddress }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["id": id, "decision": decision, "comment": comment, "via": "app"])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HouseError.unreachable }
        if (200..<300).contains(http.statusCode) { return }
        if http.statusCode == 404 || http.statusCode == 405 {
            throw FaislaRefusal(text: "The house cannot take a decision from the phone yet.")
        }
        throw FaislaRefusal(text: Self.reason(data) ?? "The house would not take it (\(http.statusCode)).")
    }

    private static func reason(_ data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["error", "detail", "message", "why", "reason"] {
                if let s = object[key] as? String, !s.isEmpty { return s.prefix(1).uppercased() + s.dropFirst() }
            }
        }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text.count > 200 || text.hasPrefix("<") ? nil : text
    }
}

// The shelf: its name on a mount, the first card whole, and the ones after
// it as edges under it, so how many wait is seen and not counted.
struct FaislaShelf: View {
    let queue: FaislaQueue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your word")
                .font(Theme.label())
                .tracking(1)
                .foregroundStyle(Theme.giltOnArt)
                .mount()
                .padding(.top, 6)
            if let first = queue.items.first {
                VStack(spacing: 0) {
                    FaislaCard(item: first, queue: queue)
                        .id(first.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 14)),
                            removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)).combined(with: .offset(y: -18))))
                    ForEach(1..<min(3, queue.items.count), id: \.self) { i in
                        UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                            .fill(Theme.plaque.opacity(i == 1 ? 0.82 : 0.6))
                            .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                                .strokeBorder(Theme.gilt.opacity(0.4), lineWidth: 0.5))
                            .frame(height: 7)
                            .padding(.horizontal, CGFloat(i) * 12)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("faisla")
            }
        }
    }
}

// One decision on a plaque: when it is due, the title in the serif, the
// question, the house's lean in gilt, the evidence, then the answer by its
// shape, and the comment under it all.
struct FaislaCard: View {
    let item: Faisla
    let queue: FaislaQueue
    @State private var comment = ""
    @State private var opinion = ""
    @State private var sending: String?
    @State private var refusal: String?
    @State private var shown: Faisla.Evidence?
    @State private var told = 0
    @State private var whole = false
    @FocusState private var commenting: Bool
    @FocusState private var writing: Bool
    // For the house's eyes: `--open faisla-answer` gives the first card the
    // house's own lean a moment after it is drawn, so the fold is seen.
    private static var eyesAnswered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let day = item.dueDay {
                let come = Calendar.current.startOfDay(for: day) <= Calendar.current.startOfDay(for: .now)
                Text("By " + day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Theme.label(.caption))
                    .tracking(0.8)
                    .foregroundStyle(come ? Theme.saffron : Theme.gilt)
            }
            Text(item.title.plainDashes)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            // A long question stands at four lines, whole on tap, so the
            // answer is never pushed off the screen.
            Text(item.question.plainDashes)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.ink.opacity(0.86))
                .lineLimit(whole ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { whole.toggle() } }
            if item.lean != nil || item.fallback != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let lean = item.lean {
                        Text(lean.plainDashes)
                            .font(.system(.footnote, design: .serif).italic())
                            .foregroundStyle(Theme.gilt)
                    }
                    if let fallback = item.fallback, !fallback.isEmpty {
                        Text(("Left alone: " + fallback + (".!?".contains(fallback.last ?? ".") ? "" : ".")).plainDashes)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.6))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if let evidence = item.evidence, !evidence.isEmpty {
                strip(evidence)
            }
            controls
                .padding(.top, 4)
            commentField
            if let refusal {
                Text(refusal.plainDashes)
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Theme.saffron)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("faisla-refused")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            shape.fill(Theme.plaque.opacity(0.97))
                .overlay(shape.strokeBorder(Theme.gilt.opacity(0.55), lineWidth: 0.5))
        }
        .sensoryFeedback(.success, trigger: told)
        .fullScreenCover(item: Binding(get: { shown.map(Shown.init) }, set: { shown = $0?.evidence })) { s in
            EvidenceFull(evidence: s.evidence)
        }
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "--open"), i + 1 < args.count,
                  args[i + 1] == "faisla-answer" || args[i + 1] == "faisla-refused", !Self.eyesAnswered else { return }
            Self.eyesAnswered = true
            try? await Task.sleep(for: .seconds(1.5))
            await give(item.house ?? item.choices.first?.key ?? "yes")
        }
    }

    @ViewBuilder private var controls: some View {
        switch item.shape {
        case "haan":
            HStack(spacing: 10) {
                plaque("Yes", key: "yes")
                plaque("No", key: "no")
            }
        case "chon":
            VStack(spacing: 8) {
                ForEach(item.choices, id: \.key) { option in
                    plaque(option.label, key: option.key, line: option.line)
                }
            }
        default:
            VStack(alignment: .trailing, spacing: 8) {
                TextField("In your own words", text: $opinion, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2...8)
                    .focused($writing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.gilt.opacity(writing ? 0.8 : 0.45), lineWidth: 0.6)
                    }
                    .accessibilityIdentifier("faisla-opinion")
                plaque("Give it", key: opinion.trimmingCharacters(in: .whitespacesAndNewlines), wide: false)
                    .disabled(opinion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(opinion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
        }
    }

    // A plaque to press: the word in the serif on a gilt hairline, square
    // cornered like a label, the house's case under it where there is one.
    private func plaque(_ label: String, key: String, line: String? = nil, wide: Bool = true) -> some View {
        Button {
            Task { await give(key) }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.plainDashes)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.ink)
                    if let line, !line.isEmpty {
                        Text(line.plainDashes)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.62))
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: wide ? .infinity : nil, alignment: line == nil ? .center : .leading)
                if sending == key {
                    ProgressView().controlSize(.mini).tint(Theme.gilt)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: wide ? .infinity : nil)
            .background {
                let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                shape.fill(Theme.gilt.opacity(sending == key ? 0.16 : 0.06))
                    .overlay(shape.strokeBorder(Theme.gilt.opacity(0.6), lineWidth: 0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(sending != nil)
        .accessibilityIdentifier("faisla-" + (item.shape == "raay" ? "give" : key))
    }

    // Small until touched, then room for a sentence or three.
    private var commentField: some View {
        TextField("A word beside it", text: $comment, axis: .vertical)
            .font(.footnote)
            .foregroundStyle(Theme.ink)
            .lineLimit(commenting || !comment.isEmpty ? 3...6 : 1...1)
            .focused($commenting)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.gilt.opacity(commenting ? 0.7 : 0.3)).frame(height: 0.5)
            }
            .animation(.snappy, value: commenting)
            .accessibilityIdentifier("faisla-comment")
    }

    // The evidence as a strip of small framed pictures; a file the phone
    // cannot draw stands as its caption on a mount. Either opens whole.
    private func strip(_ evidence: [Faisla.Evidence]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(evidence.enumerated()), id: \.offset) { _, e in
                    Button { shown = e } label: { Thumb(evidence: e) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(e.caption ?? "Evidence")
                }
            }
        }
        .scrollClipDisabled()
    }

    private func give(_ decision: String) async {
        guard sending == nil, !decision.isEmpty,
              let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        writing = false
        commenting = false
        withAnimation { refusal = nil }
        sending = decision
        defer { sending = nil }
        do {
            try await HouseClient(baseAddress: address).answer(item.id, decision: decision, comment: comment)
            told += 1
            queue.taken(item.id)
        } catch let refused as FaislaRefusal {
            withAnimation { refusal = refused.text }
        } catch {
            withAnimation { refusal = "The house did not answer; nothing was decided." }
        }
    }
}

private struct Shown: Identifiable {
    let evidence: Faisla.Evidence
    var id: String { evidence.url }
}

private func evidenceURL(_ path: String) -> URL? {
    guard let address = Keychain.loadHouseAddress() else { return nil }
    return HouseClient(baseAddress: address).houseURL(path)
}

private struct Thumb: View {
    let evidence: Faisla.Evidence

    var body: some View {
        Group {
            if evidence.picture, let url = evidenceURL(evidence.url) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Theme.ink.opacity(0.06)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "doc.text").font(.system(size: 15, weight: .light))
                    if let caption = evidence.caption {
                        Text(caption).font(.system(size: 9)).lineLimit(2).multilineTextAlignment(.center)
                    }
                }
                .foregroundStyle(Theme.gilt)
                .padding(4)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Theme.gilt.opacity(0.55), lineWidth: 0.5))
    }
}

// A piece of evidence alone on black, its caption under it; a tap puts it away.
private struct EvidenceFull: View {
    let evidence: Faisla.Evidence
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                if evidence.picture, let url = evidenceURL(evidence.url) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            ProgressView().tint(Theme.bone)
                        }
                    }
                } else if let url = evidenceURL(evidence.url) {
                    Button("Open the file") { openURL(url) }
                        .font(Theme.label())
                        .tracking(1)
                        .foregroundStyle(Theme.giltOnArt)
                }
                if let caption = evidence.caption {
                    Text(caption.plainDashes)
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundStyle(Theme.bone.opacity(0.85))
                        .padding(.horizontal, 24)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
    }
}
