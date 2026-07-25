import Foundation

/// Something worth keeping: a thought, and optionally a photo, pinned to a
/// moment in time and (when it was made somewhere) a place. Randhawa shows
/// memories where they happened; Bhullar shows them when they happened.
struct Memory: Codable, Equatable, Identifiable {
    let id: UUID
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var text: String
    var photoFileName: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        text: String,
        photoFileName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.text = text
        self.photoFileName = photoFileName
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }
}

extension Array where Element == Memory {
    /// The "on this day" set: memories made on this calendar date, not
    /// counting today's own. Both apps use this to resurface the past at the
    /// moment it becomes an anniversary.
    func onThisDayIDs(now: Date = Date(), calendar: Calendar = .current) -> Set<UUID> {
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        var ids: Set<UUID> = []
        for memory in self {
            guard !calendar.isDate(memory.date, inSameDayAs: now),
                  calendar.component(.month, from: memory.date) == month,
                  calendar.component(.day, from: memory.date) == day else { continue }
            ids.insert(memory.id)
        }
        return ids
    }
}

/// On-disk format, versioned like the moment file.
private struct MemoryArchive: Codable {
    var version: Int
    var memories: [Memory]
}

/// Reads and writes the memory list and its photos in the app-group container,
/// so both apps and the Randhawa widget see the same memories. Photos live as
/// plain JPEG files next to the JSON, named by memory ID.
enum MemoryPersistence {
    /// Newest first, which is the order every list shows.
    static func load() -> [Memory] {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let memories = (try? decoder.decode(MemoryArchive.self, from: data))?.memories ?? []
        return memories.sorted { $0.date > $1.date }
    }

    static func save(_ memories: [Memory]) {
        guard let url = fileURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(MemoryArchive(version: 1, memories: memories)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func photosDirectory() -> URL? {
        guard let base = MomentPersistence.containerURL() else { return nil }
        let directory = base.appendingPathComponent("MemoryPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func photoURL(fileName: String) -> URL? {
        photosDirectory()?.appendingPathComponent(fileName)
    }

    private static func fileURL() -> URL? {
        MomentPersistence.containerURL()?.appendingPathComponent("memories.json")
    }
}
