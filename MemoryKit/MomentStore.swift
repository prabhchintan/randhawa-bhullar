import Foundation
import CoreGraphics
import WidgetKit

/// How a moment came to exist. A dot you placed by opening the app is a
/// different kind of thing from one the phone placed while your pocket was
/// closed, and the apps say so rather than blurring them together.
///
/// Optional on `Moment` on purpose: moments written by Randhawa 3.0 carry no
/// source, and moments arriving from iCloud carry none either, since the field
/// is deliberately not part of the CloudKit schema. Both read back as
/// `.opened`, which is what they were.
enum MomentSource: String, Codable {
    case opened
    case trail
}

/// One dot on the map: where you were, and when.
struct Moment: Codable, Equatable, Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let date: Date

    /// Absent in files written before 3.1. Read `kind` instead of this.
    let source: MomentSource?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        date: Date = Date(),
        source: MomentSource? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
        self.source = source
    }

    /// The source, with the pre-3.1 absence resolved.
    var kind: MomentSource { source ?? .opened }
}

extension Array where Element == Moment {
    /// Every moment inside a span of time, oldest first. The span is
    /// half-open, so adjacent units never claim the same moment.
    func within(_ interval: DateInterval) -> [Moment] {
        filter { $0.date >= interval.start && $0.date < interval.end }
            .sorted { $0.date < $1.date }
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

    /// Appends one moment by re-reading the file first, so a trail sample
    /// taken while the app was asleep cannot clobber whatever CloudKit or the
    /// other app wrote in the meantime. Kept sorted, because callers that ask
    /// for the newest moment expect the last one to be it.
    static func append(_ moment: Moment) {
        var moments = MomentPersistence.load()
        guard !moments.contains(where: { $0.id == moment.id }) else { return }
        moments.append(moment)
        moments.sort { $0.date < $1.date }
        MomentPersistence.save(moments)
        didChange()
    }

    /// Appends only if the newest moment on file is at least `minimumSpacing`
    /// older, and reports whether it did.
    ///
    /// The spacing check reads the same file the append writes, so it happens
    /// here rather than in the caller: a trail wake gets a few seconds of
    /// background time, and loading the whole moment list twice to answer one
    /// question is the kind of waste that grows with the file. Throttling
    /// against the newest moment from any source is deliberate, so opening the
    /// app and the trail waking cannot place two dots a second apart.
    @discardableResult
    static func appendIfSpaced(_ moment: Moment, minimumSpacing: TimeInterval) -> Bool {
        var moments = MomentPersistence.load()
        if let newest = moments.lazy.map(\.date).max(),
           moment.date.timeIntervalSince(newest) < minimumSpacing {
            return false
        }
        guard !moments.contains(where: { $0.id == moment.id }) else { return false }
        moments.append(moment)
        moments.sort { $0.date < $1.date }
        MomentPersistence.save(moments)
        didChange()
        return true
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

/// How often Randhawa may add a dot on its own.
///
/// The honest framing, which the settings screen repeats: iOS decides when to
/// wake a sleeping app, and it does that when you move, not on a clock. So a
/// cadence here is a ceiling, not a promise. It says how close together two
/// dots are allowed to be, and the phone supplies the movement.
///
/// Since 3.2 the trail is how the map is meant to be made, so `moves` is the
/// default and the menu offers three choices instead of six. The middle
/// cadences still parse, because a 3.1 user may have picked one, but nothing
/// offers them any more.
enum TrailCadence: String, Codable, CaseIterable, Identifiable {
    /// The 3.0 behaviour: dots come only from opening the app.
    case off
    case moves
    case quarterHour
    case hour
    case quarterDay
    case arrivals

    /// What a fresh install, or a setting that was never touched, means.
    static let standard: TrailCadence = .moves

    /// The choices the settings screen shows, in order. A legacy cadence that
    /// is currently selected is shown too, so the screen never lies about
    /// what is on.
    static func offered(including current: TrailCadence) -> [TrailCadence] {
        var list: [TrailCadence] = [.moves, .arrivals, .off]
        if !list.contains(current) {
            list.insert(current, at: 1)
        }
        return list
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .moves: return "Whenever you move"
        case .quarterHour: return "At most every 15 minutes"
        case .hour: return "At most once an hour"
        case .quarterDay: return "At most every 4 hours"
        case .arrivals: return "Only when you arrive somewhere"
        }
    }

    var detail: String {
        switch self {
        case .off:
            return "A dot only when you open the app. Nothing is read while it is closed."
        case .moves:
            return "The map as it is meant to be made: a dot each time your phone notices you have gone somewhere, and lines between them."
        case .quarterHour:
            return "A close trail that still skips the small shuffles around one room."
        case .hour:
            return "Enough to draw a day's shape without filling the map."
        case .quarterDay:
            return "Morning, afternoon, evening. The lightest way to keep a trail."
        case .arrivals:
            return "No lines between places. A dot when you settle somewhere and stay a while."
        }
    }

    /// The smallest gap allowed between two dots.
    var minimumSpacing: TimeInterval {
        switch self {
        case .off: return .infinity
        case .moves: return 300
        case .quarterHour: return 900
        case .hour: return 3_600
        case .quarterDay: return 14_400
        // Visits are already rare. The floor only guards against a visit
        // landing on top of a dot the user just placed by opening the app.
        case .arrivals: return 300
        }
    }

    /// Significant-change monitoring is the movement source. Arrivals mode
    /// deliberately does without it, which is what makes it the quiet one.
    var watchesMovement: Bool {
        switch self {
        case .off, .arrivals: return false
        default: return true
        }
    }

    /// Visit monitoring costs almost nothing and always says something worth
    /// keeping, so every mode except off uses it.
    var watchesVisits: Bool { self != .off }

    var isOn: Bool { self != .off }
}

/// Where the trail setting lives: the App Group defaults, next to the sync
/// switch, so Bhullar can tell the user where its dots are coming from without
/// Randhawa having to be open.
///
/// An absent value means the standard cadence (3.1 read absence as off; 3.2
/// reads it as `moves`, because the trail is now how the map is made). An
/// unrecognised value still means off, so a reader that does not know a future
/// cadence fails closed. Note that the setting alone starts nothing: the trail
/// also needs Always location, which only the user can grant.
enum TrailSettings {
    private static let cadenceKey = "trailCadence"
    private static let offerAnsweredKey = "trailOfferAnswered"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: MomentPersistence.appGroupID) ?? .standard
    }

    static var cadence: TrailCadence {
        get {
            guard let raw = sharedDefaults.string(forKey: cadenceKey) else { return .standard }
            return TrailCadence(rawValue: raw) ?? .off
        }
        set {
            sharedDefaults.set(newValue.rawValue, forKey: cadenceKey)
        }
    }

    /// Whether the one-time "your map can draw itself now" card, shown to
    /// people who granted While Using before 3.2, has been answered.
    static var offerAnswered: Bool {
        get { sharedDefaults.bool(forKey: offerAnsweredKey) }
        set { sharedDefaults.set(newValue, forKey: offerAnsweredKey) }
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

    /// A square of the lookup grid, one clustering radius tall.
    private struct Cell: Hashable {
        let lat: Int
        let lon: Int
    }

    /// Greedy clustering: each moment joins the first clump within
    /// `radiusMeters` (tracked as a running average), or starts a new one.
    /// Order-dependent but stable, cheap, and plenty for rendering density.
    ///
    /// The obvious way to write this compares every moment against every clump,
    /// which is fine while moments only arrive when someone opens the app. The
    /// trail breaks that assumption, so clumps are indexed into a grid and each
    /// moment only looks at the cells its radius can actually reach. Output is
    /// identical to the all-pairs version, including clump order and the rule
    /// that the earliest eligible clump wins.
    static func clumps(in moments: [Moment], radiusMeters: Double) -> [Clump] {
        guard !moments.isEmpty, radiusMeters > 0 else { return [] }
        var result: [Clump] = []
        var buckets: [Cell: [Int]] = [:]

        // Cells are one radius of latitude on a side. Latitude degrees are a
        // fixed distance, so cell height is constant; longitude degrees shrink
        // toward the poles, which makes cells narrower than a radius up there,
        // so the horizontal search widens to compensate.
        let cellDegrees = radiusMeters / metersPerDegree
        func cell(_ latitude: Double, _ longitude: Double) -> Cell {
            Cell(
                lat: Int((latitude / cellDegrees).rounded(.down)),
                lon: Int((longitude / cellDegrees).rounded(.down))
            )
        }

        for moment in moments {
            let home = cell(moment.latitude, moment.longitude)
            let cosLat = Swift.max(cos(moment.latitude * Double.pi / 180), 0.01)
            let lonReach = Int((1 / cosLat).rounded(.up))

            var winner: Int?
            for dLat in -1...1 {
                for dLon in -lonReach...lonReach {
                    guard let candidates = buckets[Cell(lat: home.lat + dLat, lon: home.lon + dLon)] else { continue }
                    for index in candidates {
                        // Skip anything that cannot beat the clump already found;
                        // "first one wins" is what makes this stable.
                        if let winner, index >= winner { continue }
                        let clump = result[index]
                        if metersBetween(clump.latitude, clump.longitude, moment.latitude, moment.longitude) <= radiusMeters {
                            winner = index
                        }
                    }
                }
            }

            guard let index = winner else {
                result.append(Clump(id: result.count, latitude: moment.latitude, longitude: moment.longitude, count: 1))
                buckets[home, default: []].append(result.count - 1)
                continue
            }

            let before = cell(result[index].latitude, result[index].longitude)
            let n = Double(result[index].count)
            result[index].latitude = (result[index].latitude * n + moment.latitude) / (n + 1)
            result[index].longitude = (result[index].longitude * n + moment.longitude) / (n + 1)
            result[index].count += 1
            // The running average moves the clump, occasionally across a cell
            // boundary. Reindex when it does, or later moments will not find it.
            let after = cell(result[index].latitude, result[index].longitude)
            if after != before {
                buckets[before]?.removeAll { $0 == index }
                buckets[after, default: []].append(index)
            }
        }
        return result
    }

    /// Distinct places for the caption: clumps at neighborhood radius.
    static func placeCount(in moments: [Moment]) -> Int {
        clumps(in: moments, radiusMeters: 150).count
    }

    /// Two dots are joined by a line when they are this close in time. Half a
    /// day: a night at home joins yesterday's last dot to this morning's first
    /// with a line of no length, and a flight longer than this leaves a gap
    /// rather than a straight stroke across an ocean nobody crossed on foot.
    static let threadGap: TimeInterval = 12 * 3600

    /// Runs of consecutive moments joined by lines, as index ranges into
    /// `moments`, which must be sorted by date. Each range is one thread; a
    /// moment with no neighbour within `maxGap` on either side is in none.
    ///
    /// A thread also ends at midnight. Each day is drawn as one stroke, and
    /// strokes are translucent, so a road taken every morning darkens the way
    /// a place visited every morning does. One unbroken stroke across weeks
    /// would never stack on itself, and the commute would stay faint forever.
    static func threads(
        in moments: [Moment],
        maxGap: TimeInterval = threadGap,
        calendar: Calendar = .current
    ) -> [Range<Int>] {
        guard moments.count > 1 else { return [] }
        var result: [Range<Int>] = []
        var start = 0
        for index in 1..<moments.count {
            let previous = moments[index - 1].date
            let current = moments[index].date
            if current.timeIntervalSince(previous) > maxGap || !calendar.isDate(current, inSameDayAs: previous) {
                if index - start > 1 {
                    result.append(start..<index)
                }
                start = index
            }
        }
        if moments.count - start > 1 {
            result.append(start..<moments.count)
        }
        return result
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
