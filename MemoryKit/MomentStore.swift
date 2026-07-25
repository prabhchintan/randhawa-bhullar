import Foundation
import CoreGraphics
import WidgetKit

/// One opening of the app: where you were, and when.
struct Moment: Codable, Equatable, Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let date: Date

    init(id: UUID = UUID(), latitude: Double, longitude: Double, date: Date = Date()) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
    }
}

/// On-disk format, versioned so future releases can migrate old maps.
private struct MomentFile: Codable {
    var version: Int
    var moments: [Moment]
}

/// Reads and writes the moment list in the app-group container, so both apps
/// and the widget see the same map. Nothing here touches the network: this
/// file is the device's copy of the map. When iCloud sync is on, CloudSync
/// mirrors it record by record into the user's private database.
enum MomentPersistence {
    /// Must match the App Group enabled on every target of both apps.
    static let appGroupID = "group.Prabhchintan.Randhawa"

    static func load() -> [Moment] {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(MomentFile.self, from: data))?.moments ?? []
    }

    static func save(_ moments: [Moment]) {
        guard let url = fileURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(MomentFile(version: 1, moments: moments)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// The app-group container, or Application Support when the entitlement is
    /// not provisioned yet, so the app still works alone.
    static func containerURL() -> URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return container
        }
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support
    }

    private static func fileURL() -> URL? {
        containerURL()?.appendingPathComponent("moments.json")
    }
}

/// File-level moment operations used by CloudSync when records arrive from
/// iCloud. Kept separate from SpaceModel so both apps can apply fetched
/// moments to the shared file; SpaceModel listens for the notification and
/// reloads its in-memory copy.
enum MomentSync {
    static let didChangeExternally = Notification.Name("MomentSyncDidChangeExternally")

    static func allMoments() -> [Moment] {
        MomentPersistence.load()
    }

    /// Merges fetched moments into the file. Moments never change once made,
    /// so an ID we already have is simply kept.
    static func upsert(_ fetched: [Moment]) {
        var byID = Dictionary(uniqueKeysWithValues: MomentPersistence.load().map { ($0.id, $0) })
        var changed = false
        for moment in fetched where byID[moment.id] == nil {
            byID[moment.id] = moment
            changed = true
        }
        guard changed else { return }
        MomentPersistence.save(byID.values.sorted { $0.date < $1.date })
        didChange()
    }

    static func remove(ids: Set<UUID>) {
        let moments = MomentPersistence.load()
        let kept = moments.filter { !ids.contains($0.id) }
        guard kept.count != moments.count else { return }
        MomentPersistence.save(kept)
        didChange()
    }

    static func eraseAllLocal() {
        MomentPersistence.save([])
        didChange()
    }

    private static func didChange() {
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: didChangeExternally, object: nil)
    }
}

/// Pure geometry over moments: clustering for density and captions, and the
/// abstract projection the constellation draws. No UI and no side effects, so
/// all of it runs and tests off-device.
enum MomentGeometry {
    /// Meters per degree of latitude; a degree of longitude shrinks by
    /// cos(latitude).
    static let metersPerDegree = 111_320.0

    struct Clump: Identifiable, Equatable {
        let id: Int
        var latitude: Double
        var longitude: Double
        var count: Int
    }

    /// Greedy clustering: each moment joins the first clump within
    /// `radiusMeters` (tracked as a running average), or starts a new one.
    /// Order-dependent but stable, cheap, and plenty for rendering density.
    static func clumps(in moments: [Moment], radiusMeters: Double) -> [Clump] {
        var result: [Clump] = []
        for moment in moments {
            var joined = false
            for i in 0..<result.count {
                let clump = result[i]
                if metersBetween(clump.latitude, clump.longitude, moment.latitude, moment.longitude) <= radiusMeters {
                    let n = Double(clump.count)
                    result[i].latitude = (clump.latitude * n + moment.latitude) / (n + 1)
                    result[i].longitude = (clump.longitude * n + moment.longitude) / (n + 1)
                    result[i].count += 1
                    joined = true
                    break
                }
            }
            if !joined {
                result.append(Clump(id: result.count, latitude: moment.latitude, longitude: moment.longitude, count: 1))
            }
        }
        return result
    }

    /// Distinct places for the caption: clumps at neighborhood radius.
    static func placeCount(in moments: [Moment]) -> Int {
        clumps(in: moments, radiusMeters: 150).count
    }

    /// Geographic frame for a map of `moments`: center plus span in degrees.
    /// Kept UIKit/MapKit-free so the math runs and tests off-device.
    struct Region: Equatable {
        var centerLatitude: Double
        var centerLongitude: Double
        var latitudeSpan: Double
        var longitudeSpan: Double
    }

    /// The region a map should show to frame every moment: the bounding box
    /// padded by `paddingFactor`, never tighter than `minSpanMeters` so a
    /// single-neighborhood map doesn't zoom to the user's doorstep, and capped
    /// so the spans stay valid MapKit values.
    static func boundingRegion(
        for moments: [Moment],
        paddingFactor: Double = 1.4,
        minSpanMeters: Double = 900
    ) -> Region? {
        guard !moments.isEmpty else { return nil }
        let lats = moments.map { $0.latitude }
        let lons = moments.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        let centerLatitude = (minLat + maxLat) / 2
        let centerLongitude = (minLon + maxLon) / 2
        let minSpanLat = minSpanMeters / metersPerDegree
        // Longitude degrees shrink by cos(latitude); the floor keeps the
        // division sane at extreme latitudes.
        let cosLat = Swift.max(cos(centerLatitude * Double.pi / 180), 0.01)
        return Region(
            centerLatitude: centerLatitude,
            centerLongitude: centerLongitude,
            latitudeSpan: Swift.min(Swift.max((maxLat - minLat) * paddingFactor, minSpanLat), 170),
            longitudeSpan: Swift.min(Swift.max((maxLon - minLon) * paddingFactor, minSpanLat / cosLat), 350)
        )
    }

    /// Equirectangular distance approximation. Exact enough at clustering
    /// radii, far cheaper than great-circle math.
    static func metersBetween(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let midLat = (lat1 + lat2) / 2 * Double.pi / 180
        let dLat = (lat2 - lat1) * metersPerDegree
        let dLon = (lon2 - lon1) * metersPerDegree * cos(midLat)
        return (dLat * dLat + dLon * dLon).squareRoot()
    }

    /// Projects moments into `size` for the constellation: north up, aspect
    /// preserved, fitted to the bounding box with `padding` on every side.
    /// The ~200 m span floor keeps GPS jitter around a single spot from being
    /// stretched across the whole canvas.
    static func projected(_ moments: [Moment], in size: CGSize, padding: CGFloat) -> [CGPoint] {
        guard !moments.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let lats = moments.map { $0.latitude }
        guard let minLat = lats.min(), let maxLat = lats.max() else { return [] }
        let midLat = (minLat + maxLat) / 2 * Double.pi / 180

        // Planar coordinates: x in "longitude degrees corrected for latitude",
        // y in latitude degrees, so one unit is the same distance either way.
        let xs = moments.map { $0.longitude * cos(midLat) }
        let ys = lats
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return [] }

        let spanFloor = 200.0 / metersPerDegree
        let spanX = Swift.max(maxX - minX, spanFloor)
        let spanY = Swift.max(maxY - minY, spanFloor)
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        let drawWidth = Double(size.width - padding * 2)
        let drawHeight = Double(size.height - padding * 2)
        guard drawWidth > 0, drawHeight > 0 else {
            return moments.map { _ in CGPoint(x: size.width / 2, y: size.height / 2) }
        }

        let scale = Swift.min(drawWidth / spanX, drawHeight / spanY)
        let halfWidth = Double(size.width) / 2
        let halfHeight = Double(size.height) / 2
        var points: [CGPoint] = []
        points.reserveCapacity(xs.count)
        for i in 0..<xs.count {
            let px = halfWidth + (xs[i] - centerX) * scale
            let py = halfHeight - (ys[i] - centerY) * scale
            points.append(CGPoint(x: px, y: py))
        }
        return points
    }
}
