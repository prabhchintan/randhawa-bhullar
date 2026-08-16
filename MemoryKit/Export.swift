import Foundation
import SwiftUI
import UIKit

/// Everything the apps hold, written out as one readable file the user can
/// keep, move, or read with any text editor. The other half of the privacy
/// story: data that lives only with you should also leave with you.
///
/// Photos are embedded as base64 JPEG so the export is a single file that
/// needs no unpacking. The shape mirrors the on-disk contract in
/// MemoryKit/README.md and adds nothing the apps do not already store.
enum MapExport {
    struct File: Encodable {
        struct ExportedMemory: Encodable {
            let id: UUID
            let date: Date
            let latitude: Double?
            let longitude: Double?
            let placeName: String?
            let text: String
            let photoJPEGBase64: String?
        }

        let format = "randhawa-export"
        let version = 1
        let exportedAt: Date
        let moments: [Moment]
        let memories: [ExportedMemory]
    }

    /// Writes the export into the temporary directory and returns its URL.
    static func write(now: Date = Date()) throws -> URL {
        let memories = MemoryPersistence.load().map { memory -> File.ExportedMemory in
            var photo: String?
            if let fileName = memory.photoFileName,
               let url = MemoryPersistence.photoURL(fileName: fileName),
               let data = try? Data(contentsOf: url) {
                photo = data.base64EncodedString()
            }
            return File.ExportedMemory(
                id: memory.id,
                date: memory.date,
                latitude: memory.latitude,
                longitude: memory.longitude,
                placeName: memory.placeName,
                text: memory.text,
                photoJPEGBase64: photo
            )
        }
        let file = File(exportedAt: now, moments: MomentPersistence.load(), memories: memories)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        let stamp = now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Randhawa \(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// The system share sheet, for handing the export to AirDrop, Files, or Mail.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Wraps a URL so a sheet can be driven by `.sheet(item:)`.
struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}
