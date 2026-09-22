import Foundation

struct ChintanMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let fromHouse: Bool
    let date: Date
}

// The conversation, kept on the device alone: a JSON file in Application
// Support, newest last, trimmed to the last 500 turns. Never synced.
@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var messages: [ChintanMessage] = []
    private let fileURL: URL
    private let limit = 500

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("conversation.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        messages = (try? JSONDecoder().decode([ChintanMessage].self, from: data)) ?? []
    }

    func append(_ message: ChintanMessage) {
        messages.append(message)
        if messages.count > limit {
            messages.removeFirst(messages.count - limit)
        }
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
