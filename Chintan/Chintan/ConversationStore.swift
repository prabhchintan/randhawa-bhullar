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
    }

    func messages(_ voice: Voice) -> [ChintanMessage] { rooms[voice] ?? [] }

    private func fileURL(_ voice: Voice) -> URL {
        dir.appendingPathComponent(voice == .chintan ? "conversation.json" : "conversation-\(voice.rawValue).json")
    }

    private func load(_ voice: Voice) {
        guard let data = try? Data(contentsOf: fileURL(voice)) else { return }
        rooms[voice] = (try? JSONDecoder().decode([ChintanMessage].self, from: data)) ?? []
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
