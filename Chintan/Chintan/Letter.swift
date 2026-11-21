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

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                heading
                    .padding(.horizontal, 6)
                    .padding(.top, 18)
                    .padding(.bottom, 6)
                if let issue = store.issue {
                    ForEach(issue.pieces) { piece in
                        leaf(piece, in: issue)
                            .onAppear { onScreen[piece.id] = .now }
                            .onDisappear { settle(piece.id, in: issue) }
                    }
                } else if store.loaded {
                    Text("The letter comes in the morning, when the house is in reach.")
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .plaque()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
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

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headLine)
                .font(Theme.label())
                .tracking(0.8)
                .foregroundStyle(Theme.ink.opacity(0.7))
            Text((store.issue?.subject ?? (store.loaded ? "No letter yet." : "Reading the letter.")).plainDashes)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var headLine: String {
        guard let issue = store.issue else { return "The letter" }
        return [issue.dateWords, "No. \(issue.issue)"].compactMap { $0 }.joined(separator: " \u{00B7} ")
    }

    @ViewBuilder
    private func leaf(_ piece: LetterIssue.Piece, in issue: LetterIssue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let kicker = piece.kicker, !kicker.isEmpty {
                Text(kicker.plainDashes.uppercased())
                    .font(Theme.label(.caption))
                    .tracking(1)
                    .foregroundStyle(Theme.gilt)
            }
            if let image = piece.image, let url = URL(string: image) {
                AsyncImage(url: url) { phase in
                    if let picture = phase.image {
                        picture.resizable().scaledToFit()
                    } else {
                        Rectangle().fill(Theme.ink.opacity(0.06)).frame(height: 180)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .accessibilityHidden(true)
            }
            if let title = piece.title, !title.isEmpty {
                Text(title.plainDashes)
                    .font(.system(piece.kind == "talk" ? .title3 : .headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let meta = piece.meta, !meta.isEmpty {
                Text(meta.plainDashes)
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array((piece.body ?? []).enumerated()), id: \.offset) { _, text in
                Text(text.plainDashes)
                    .font(.system(piece.kind == "opening" ? .title3 : .body, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array((piece.points ?? []).enumerated()), id: \.offset) { n, text in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(n + 1)")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(Theme.gilt)
                    Text(text.plainDashes)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(Array((piece.quotes ?? []).enumerated()), id: \.offset) { _, text in
                Text("\u{201C}" + text.plainDashes + "\u{201D}")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.gilt).frame(width: 1.5) }
            }
            if let why = piece.why, !why.isEmpty {
                Text("FOR YOU")
                    .font(Theme.label(.caption))
                    .tracking(1)
                    .foregroundStyle(Theme.gilt)
                    .padding(.top, 4)
                Text(why.plainDashes)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let links = piece.links, !links.isEmpty {
                HStack(spacing: 18) {
                    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                        Button {
                            guard let url = URL(string: link.url) else { return }
                            Taps.shared.note("letter.link", id: "\(issue.issue)|\(piece.id)")
                            openURL(url)
                        } label: {
                            Text(link.label.uppercased())
                                .font(Theme.label(.caption))
                                .tracking(1)
                                .foregroundStyle(Theme.gilt)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
    }
}
