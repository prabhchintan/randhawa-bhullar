import Foundation

struct ChintanMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let fromHouse: Bool
    let date: Date
}

// The four voices of the house, each a room in the study.
enum Voice: String, CaseIterable, Identifiable {
    case chintan, darban, yaar, hawa
    var id: String { rawValue }

    // hawa, the air, is never written down: its room lives in memory alone.
    var kept: Bool { self != .hawa }
}

// The conversations, kept on the device alone: one JSON file per voice in
// Application Support, newest last, each trimmed to the last 500 turns.
// chintan's stays in the file it always had. Never synced. hawa's has no
// file and no line in waiting.json; forget(_:) empties it.
@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var rooms: [Voice: [ChintanMessage]] = [:]
    private let dir: URL
    private let limit = 500

    init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for voice in Voice.allCases where voice.kept { load(voice) }
        loadWaiting()
    }

    func messages(_ voice: Voice) -> [ChintanMessage] { rooms[voice] ?? [] }

    private func fileURL(_ voice: Voice) -> URL {
        dir.appendingPathComponent(voice == .chintan ? "conversation.json" : "conversation-\(voice.rawValue).json")
    }

    private func load(_ voice: Voice) {
        guard let data = try? Data(contentsOf: fileURL(voice)) else { return }
        rooms[voice] = (try? JSONDecoder().decode([ChintanMessage].self, from: data)) ?? []
    }

    // A word the house has not yet answered, one per room at most: the id to
    // ask after, and the word it answers. Kept in its own file so a reply the
    // house finished while the app was closed still finds its room. A day
    // on, it is let go and the word reads as unanswered.
    struct Waiting: Codable {
        var id: String
        let word: UUID
        let since: Date
    }

    @Published private(set) var waiting: [Voice: Waiting] = [:]
    private var waitingURL: URL { dir.appendingPathComponent("waiting.json") }

    private func loadWaiting() {
        guard let data = try? Data(contentsOf: waitingURL),
              let kept = try? JSONDecoder().decode([String: Waiting].self, from: data) else { return }
        for (name, w) in kept {
            if let v = Voice(rawValue: name), v.kept, w.since.timeIntervalSinceNow > -86_400 { waiting[v] = w }
        }
    }

    func wait(_ w: Waiting?, in voice: Voice) {
        waiting[voice] = w
        guard voice.kept else { return }
        let kept = Dictionary(uniqueKeysWithValues: waiting.filter { $0.key.kept }.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(kept) else { return }
        try? data.write(to: waitingURL, options: .atomic)
    }

    func append(_ message: ChintanMessage, to voice: Voice) {
        var messages = rooms[voice] ?? []
        messages.append(message)
        if messages.count > limit {
            messages.removeFirst(messages.count - limit)
        }
        rooms[voice] = messages
        guard voice.kept, let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: fileURL(voice), options: .atomic)
    }

    // A room that keeps nothing, emptied: its words and its wait let go.
    func forget(_ voice: Voice) {
        guard !voice.kept else { return }
        rooms[voice] = nil
        waiting[voice] = nil
    }
}
