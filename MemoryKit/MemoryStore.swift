import Foundation
import Combine
import WidgetKit

/// The in-memory source of truth for memories inside each app. It owns the
/// shared file and photo folder, tells CloudSync about local edits, and
/// applies fetched records without echoing them back to iCloud.
@MainActor
final class MemoryStore: ObservableObject {
    static let shared = MemoryStore()

    @Published private(set) var memories: [Memory]

    private init() {
        memories = MemoryPersistence.load()
    }

    /// The other app may have written the file while this one was suspended.
    func reloadFromDisk() {
        let fresh = MemoryPersistence.load()
        if fresh != memories {
            memories = fresh
        }
    }

    func memory(withID id: UUID) -> Memory? {
        memories.first { $0.id == id }
    }

    func photoURL(for memory: Memory) -> URL? {
        memory.photoFileName.flatMap { MemoryPersistence.photoURL(fileName: $0) }
    }

    // MARK: - Local edits (synced up when iCloud sync is on)

    @discardableResult
    func add(
        text: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        photoData: Data? = nil
    ) -> Memory {
        var memory = Memory(
            latitude: latitude,
            longitude: longitude,
            placeName: placeName,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if let photoData {
            let fileName = memory.id.uuidString + ".jpg"
            if let url = MemoryPersistence.photoURL(fileName: fileName),
               (try? photoData.write(to: url, options: .atomic)) != nil {
                memory.photoFileName = fileName
            }
        }
        memories.insert(memory, at: 0)
        persist()
        CloudSync.shared?.memoryChanged(memory.id)
        return memory
    }

    /// Reverse geocoding finishes after the save; fill the name in when it does.
    func setPlaceName(_ placeName: String, for id: UUID) {
        guard let index = memories.firstIndex(where: { $0.id == id }),
              memories[index].placeName != placeName else { return }
        memories[index].placeName = placeName
        persist()
        CloudSync.shared?.memoryChanged(id)
    }

    func delete(_ memory: Memory) {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        deletePhoto(of: memories[index])
        memories.remove(at: index)
        persist()
        CloudSync.shared?.memoryDeleted(memory.id)
    }

    /// Wipes the local store only; the caller decides what happens to iCloud.
    func eraseAll() {
        for memory in memories {
            deletePhoto(of: memory)
        }
        memories = []
        persist()
    }

    // MARK: - Applying fetched iCloud changes (never echoed back)

    func applyFetched(_ incoming: Memory, photoSourceURL: URL?) {
        if let photoSourceURL, let fileName = incoming.photoFileName,
           let destination = MemoryPersistence.photoURL(fileName: fileName) {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: photoSourceURL, to: destination)
        }
        if let index = memories.firstIndex(where: { $0.id == incoming.id }) {
            memories[index] = incoming
        } else {
            let insertAt = memories.firstIndex { $0.date < incoming.date } ?? memories.count
            memories.insert(incoming, at: insertAt)
        }
        persist()
    }

    func removeFetched(ids: Set<UUID>) {
        let removed = memories.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        for memory in removed {
            deletePhoto(of: memory)
        }
        memories.removeAll { ids.contains($0.id) }
        persist()
    }

    // MARK: -

    private func deletePhoto(of memory: Memory) {
        guard let url = photoURL(for: memory) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func persist() {
        MemoryPersistence.save(memories)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
