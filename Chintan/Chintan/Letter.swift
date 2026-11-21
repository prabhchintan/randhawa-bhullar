import SwiftUI

// The morning letter, hung in the app (Prab, 2026-11-21, the study: "we could
// either devise a way for me to read them in the app, or I could respond to
// the emails ... I would prefer them to be in app but not fully sure if my
// behavior will translate. We could run both"). The same issue the mail
// carries, as the house's own pieces: the opening, the painting, the teacher,
// the lesson, the long things, the voices on X, the wide net, the house. The
// tap ledger notes how long each piece stood on the screen and which link he
// opened, so the house learns what landed by watching and never asks.
struct LetterIssue: Codable, Equatable {
    struct Piece: Codable, Equatable, Identifiable {
        struct Link: Codable, Equatable {
            let label: String
            let url: String
        }
        let id: String
        let kind: String
        var kicker: String?
        var title: String?
        var meta: String?
        var image: String?
        var body: [String]?
        var points: [String]?
        var quotes: [String]?
        var why: String?
        var links: [Link]?
    }

    let issue: Int
    var date: String?
    var dateWords: String?
    var subject: String?
    let pieces: [Piece]

    enum CodingKeys: String, CodingKey {
        case issue, date, subject, pieces
        case dateWords = "date_words"
    }
}

// The issue as last read: from the house when it is in reach, else by the
// feed's own road (the worker keeps the newest issue), else the copy the
// phone kept. The newest number he has opened is kept, so Home can mark an
// issue he has not yet read.
@MainActor final class LetterStore: ObservableObject {
    static let shared = LetterStore()

    @Published private(set) var issue: LetterIssue?
    @Published private(set) var loaded = false
    @Published private(set) var opened = UserDefaults.standard.integer(forKey: LetterStore.openedKey)

    private static let openedKey = "letter.opened"
    private static let file: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("letter.json")

    private init() {
        if let data = try? Data(contentsOf: Self.file) { issue = try? JSONDecoder().decode(LetterIssue.self, from: data) }
    }

    // An issue come since he last opened the letter.
    var unread: Bool { (issue?.issue ?? 0) > opened && opened > 0 }

    func markOpened() {
        guard let no = issue?.issue else { return }
        // The first look only sets the mark, the way the guest book does.
        if no != opened {
            opened = no
            UserDefaults.standard.set(no, forKey: Self.openedKey)
        }
    }

    func read() async {
        defer { loaded = true }
        var data: Data?
        if let address = Keychain.loadHouseAddress(), !address.isEmpty {
            data = try? await HouseClient(baseAddress: address).letter()
        }
        if data == nil, let road = Keychain.loadRoad(),
           let url = URL(string: road.url.replacingOccurrences(of: "/chintan/timeline", with: "/chintan/letter")),
           url.scheme == "https" {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.setValue("Bearer " + road.token, forHTTPHeaderField: "Authorization")
            if let (body, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                data = body
            }
        }
        guard let data, let fresh = try? JSONDecoder().decode(LetterIssue.self, from: data), !fresh.pieces.isEmpty else { return }
        // Never an older issue over a newer one the phone already holds.
        if let held = issue, held.issue > fresh.issue { return }
        if fresh != issue {
            issue = fresh
            try? data.write(to: Self.file, options: .atomic)
        }
        if opened == 0 { markOpened() }
    }
}

struct LetterView: View {
    @ObservedObject private var store = LetterStore.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    // The pieces on the screen now and since when, for the tap ledger.
    @State private var onScreen: [String: Date] = [:]

    // The letter is one sheet, the way the mail is: the mail's own face (Iowan
    // Old Style), a masthead, the pieces one under another with a gilt
    // ornament between, nothing boxed (his word, 2026-11-21 12:55: the font
    // size and the presentation "more classy").
    private enum Face {
        static func roman(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font { .custom("IowanOldStyle-Roman", size: size, relativeTo: style) }
        static func italic(_ size: CGFloat, _ style: Font.TextStyle = .body) -> Font { .custom("IowanOldStyle-Italic", size: size, relativeTo: style) }
        static func bold(_ size: CGFloat, _ style: Font.TextStyle = .title3) -> Font { .custom("IowanOldStyle-Bold", size: size, relativeTo: style) }
    }

    // For the house's eyes: `--open letter-N` opens on the Nth piece.
    var eyes: String?

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                heading
                    .padding(.top, 14)
                if let issue = store.issue {
                    ForEach(issue.pieces) { piece in
                        VStack(alignment: .leading, spacing: 0) {
                            if piece.kind != "opening" { ornament }
                            leaf(piece, in: issue)
                        }
                        .id(piece.id)
                        .onAppear { onScreen[piece.id] = .now }
                        .onDisappear { settle(piece.id, in: issue) }
                    }
                    colophon
                } else if store.loaded {
                    Text("The letter comes in the morning, when the house is in reach.")
                        .font(Face.italic(17))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 30)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        // The sheet's own handle keeps a clear band; no line runs under it.
        .padding(.top, 26)
        .task(id: store.issue?.issue) {
            guard let word = eyes, word.hasPrefix("letter-"), let n = Int(word.dropFirst(7)),
                  let pieces = store.issue?.pieces, pieces.indices.contains(n) else { return }
            try? await Task.sleep(for: .seconds(1.5))
            proxy.scrollTo(pieces[n].id, anchor: .top)
        }
        }
        .task { await store.read() }
        // The letter while it is open, by its number; each piece by its seconds.
        .task(id: store.issue?.issue) {
            guard let no = store.issue?.issue else { return }
            Taps.shared.begin("letter", id: String(no))
            store.markOpened()
        }
        .onChange(of: phase) { _, now in
            if now != .active { settleAll() }
        }
        .onDisappear {
            settleAll()
            Taps.shared.end("letter")
        }
    }

    private func settle(_ id: String, in issue: LetterIssue) {
        guard let since = onScreen.removeValue(forKey: id) else { return }
        let secs = Date.now.timeIntervalSince(since)
        // A piece only passed on the way down is not a reading.
        if secs >= 1 { Taps.shared.note("letter.piece", id: "\(issue.issue)|\(id)", secs: secs) }
    }

    private func settleAll() {
        guard let issue = store.issue else { return }
        for id in Array(onScreen.keys) { settle(id, in: issue) }
    }

    // The masthead, as the mail letters it.
    private var heading: some View {
        VStack(spacing: 0) {
            Text("NICHOR")
                .font(Face.roman(28, .title))
                .tracking(10)
                .padding(.leading, 10)
                .foregroundStyle(Theme.ink)
            Text("THE LONG THINGS AND THE WIDE NET, FOR PRAB")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(Theme.gilt)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            Rectangle()
                .fill(Theme.gilt)
                .frame(width: 72, height: 1)
                .padding(.top, 20)
                .padding(.bottom, 14)
            Text(headLine.plainDashes)
                .font(Face.italic(15, .footnote))
                .foregroundStyle(Theme.ink.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
        .accessibilityElement(children: .combine)
    }

    private var headLine: String {
        guard let issue = store.issue else { return store.loaded ? "No letter yet" : "Reading the letter" }
        return [issue.dateWords, "No. \(issue.issue)"].compactMap { $0 }.joined(separator: " \u{00B7} ")
    }

    private var ornament: some View {
        Text("\u{00B7}   \u{00B7}   \u{00B7}")
            .font(Face.roman(20))
            .foregroundStyle(Theme.gilt)
            .frame(maxWidth: .infinity)
            .padding(.top, 34)
            .padding(.bottom, 30)
            .accessibilityHidden(true)
    }

    private var colophon: some View {
        VStack(spacing: 16) {
            Rectangle().fill(Theme.gilt).frame(width: 72, height: 1)
            Text("a letter from chintan")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Theme.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    private func kicker(_ text: String) -> some View {
        Text(text.plainDashes.uppercased())
            .font(.system(size: 11, weight: .medium))
            .tracking(1.6)
            .foregroundStyle(Theme.gilt)
    }

    private func open(_ link: LetterIssue.Piece.Link, of piece: LetterIssue.Piece, in issue: LetterIssue) {
        guard let url = URL(string: link.url) else { return }
        Taps.shared.note("letter.link", id: "\(issue.issue)|\(piece.id)")
        openURL(url)
    }

    @ViewBuilder
    private func leaf(_ piece: LetterIssue.Piece, in issue: LetterIssue) -> some View {
        let centred = piece.kind == "painting"
        VStack(alignment: centred ? .center : .leading, spacing: 0) {
            if let image = piece.image, let url = URL(string: image) {
                AsyncImage(url: url) { phase in
                    if let picture = phase.image {
                        picture.resizable().scaledToFit()
                    } else {
                        Rectangle().fill(Theme.ink.opacity(0.06)).frame(height: 220)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(.bottom, 14)
                .onTapGesture { if let first = piece.links?.first { open(first, of: piece, in: issue) } }
                .accessibilityHidden(true)
            }
            if let word = piece.kicker, !word.isEmpty {
                kicker(word)
                    .padding(.bottom, 10)
            }
            if let title = piece.title, !title.isEmpty {
                Group {
                    if centred {
                        Text(title.plainDashes).font(Face.italic(16, .callout)).foregroundStyle(Theme.ink.opacity(0.7))
                    } else {
                        Text(title.plainDashes).font(Face.bold(piece.kind == "talk" ? 27 : 22)).foregroundStyle(Theme.ink)
                    }
                }
                .lineSpacing(2)
                .multilineTextAlignment(centred ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture { if let first = piece.links?.first { open(first, of: piece, in: issue) } }
            }
            if let meta = piece.meta, !meta.isEmpty {
                Text(meta.plainDashes)
                    .font(centred ? .system(size: 11) : Face.italic(15, .footnote))
                    .tracking(centred ? 0.6 : 0)
                    .foregroundStyle(Theme.ink.opacity(0.58))
                    .multilineTextAlignment(centred ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            ForEach(Array((piece.body ?? []).enumerated()), id: \.offset) { _, text in
                Text(text.plainDashes)
                    .font(Face.roman(piece.kind == "opening" ? 21 : 19))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(piece.kind == "opening" ? 6 : 5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, piece.kind == "opening" ? 0 : 14)
            }
            if let points = piece.points, !points.isEmpty {
                kicker("Worth knowing")
                    .padding(.top, 24)
                ForEach(Array(points.enumerated()), id: \.offset) { n, text in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(n + 1)")
                            .font(Face.roman(16, .callout))
                            .foregroundStyle(Theme.gilt)
                            .frame(width: 18, alignment: .leading)
                        Text(text.plainDashes)
                            .font(Face.roman(18))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
                }
            }
            ForEach(Array((piece.quotes ?? []).enumerated()), id: \.offset) { _, text in
                Text("\u{201C}" + text.plainDashes + "\u{201D}")
                    .font(Face.italic(18))
                    .foregroundStyle(Theme.ink.opacity(0.82))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 16)
                    .padding(.vertical, 2)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.gilt).frame(width: 2) }
                    .padding(.top, 18)
            }
            if let why = piece.why, !why.isEmpty {
                kicker("For you")
                    .padding(.top, 26)
                Text(why.plainDashes)
                    .font(Face.roman(18))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            if let links = piece.links, !links.isEmpty, !centred {
                HStack(spacing: 22) {
                    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                        Button {
                            open(link, of: piece, in: issue)
                        } label: {
                            HStack(spacing: 5) {
                                Text(link.label.uppercased())
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(1.6)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .foregroundStyle(Theme.gilt)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
    }
}
