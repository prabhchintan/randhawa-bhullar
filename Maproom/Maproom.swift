// Maproom: the map, made at home.
//
// Reads the maintainer's Moments and Memories from his private CloudKit
// database using this Mac's own iCloud session, the one long-lived
// credential Apple allows for a private database, and writes them as JSON
// where scripts/mymap.py expects them. No tokens, nothing to renew.
// Location data stays in ~/Library/Application Support/randhawa-loop/map/,
// never in a repository. scripts/maproom.sh is the launchd wrapper that
// runs this, summarizes, and pushes the summary to the private repo.

import CloudKit
import Foundation

struct MaproomError: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

@main
struct Maproom {
    static let containerID = "iCloud.Prabhchintan.Randhawa"
    static let zoneID = CKRecordZone.ID(zoneName: "SpaceTime", ownerName: CKCurrentUserDefaultName)

    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("maproom failed: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run() async throws {
        let out = CommandLine.arguments.count > 1
            ? URL(fileURLWithPath: CommandLine.arguments[1])
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("randhawa-loop/map")
        let container = CKContainer(identifier: containerID)
        let status = try await container.accountStatus()
        guard status == .available else {
            throw MaproomError("iCloud account not available on this Mac (status \(status.rawValue)); sign in through System Settings")
        }
        let db = container.privateCloudDatabase
        let moments = try await records(in: db, type: "Moment").map(moment).sorted { str($0["date"]) < str($1["date"]) }
        let memories = try await records(in: db, type: "Memory").map(memory).sorted { str($0["date"]) < str($1["date"]) }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try write(["pulledAt": now(), "moments": moments], to: out.appendingPathComponent("moments.json"))
        try write(["pulledAt": now(), "memories": memories], to: out.appendingPathComponent("memories.json"))
        print("\(moments.count) moments, \(memories.count) memories")
    }

    static func records(in db: CKDatabase, type: String) async throws -> [CKRecord] {
        var found: [CKRecord] = []
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var (results, cursor) = try await db.records(matching: query, inZoneWith: zoneID, desiredKeys: nil, resultsLimit: 200)
        while true {
            found += try results.map { try $0.1.get() }
            guard let next = cursor else { return found }
            (results, cursor) = try await db.records(continuingMatchFrom: next, desiredKeys: nil, resultsLimit: 200)
        }
    }

    // The JSON shapes scripts/mymap.py has read since 2026-08-16; every key
    // is always present, null when empty, dates in the .000Z style.
    static func moment(_ record: CKRecord) -> [String: Any] {
        [
            "id": trim(record.recordID.recordName, prefix: "moment-"),
            "latitude": record["latitude"] as? Double as Any,
            "longitude": record["longitude"] as? Double as Any,
            "date": (record["date"] as? Date).map(stamp) as Any,
        ]
    }

    static func memory(_ record: CKRecord) -> [String: Any] {
        [
            "id": trim(record.recordID.recordName, prefix: "memory-"),
            "date": (record["date"] as? Date).map(stamp) as Any,
            "latitude": record["latitude"] as? Double as Any,
            "longitude": record["longitude"] as? Double as Any,
            "placeName": record["placeName"] as? String as Any,
            "text": (record["text"] as? String) ?? "",
            "hasPhoto": record["photo"] != nil,
        ]
    }

    static func trim(_ name: String, prefix: String) -> String {
        name.hasPrefix(prefix) ? String(name.dropFirst(prefix.count)) : name
    }

    static func str(_ value: Any?) -> String { value as? String ?? "" }

    static func stamp(_ date: Date) -> String {
        let form = ISO8601DateFormatter()
        form.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return form.string(from: date)
    }

    static func now() -> String { stamp(Date()) }

    static func write(_ object: [String: Any], to url: URL) throws {
        let cleaned = object.mapValues { value -> Any in
            if let list = value as? [[String: Any]] {
                return list.map { $0.mapValues { $0 as? NSObject ?? NSNull() } }
            }
            return value
        }
        let data = try JSONSerialization.data(withJSONObject: cleaned, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }
}
