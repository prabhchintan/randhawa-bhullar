import Foundation

struct ChintanMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let fromHouse: Bool
    let date: Date
}

// The three voices of the house, each a room in the study.
enum Voice: String, CaseIterable, Identifiable {
    case chintan, darban, yaar
    var id: String { rawValue }
}

// The conversations, kept on the device alone: one JSON file per voice in
// Application Support, newest last, each trimmed to the last 500 turns.
// chintan's stays in the file it always had. Never synced.
@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var rooms: [Voice: [ChintanMessage]] = [:]
    private let dir: URL
    private let limit = 500

    init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for voice in Voice.allCases { load(voice) }
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
            if let v = Voice(rawValue: name), w.since.timeIntervalSinceNow > -86_400 { waiting[v] = w }
        }
    }

    func wait(_ w: Waiting?, in voice: Voice) {
        waiting[voice] = w
        let kept = Dictionary(uniqueKeysWithValues: waiting.map { ($0.key.rawValue, $0.value) })
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
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: fileURL(voice), options: .atomic)
    }
}
