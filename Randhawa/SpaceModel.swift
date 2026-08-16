import Foundation
import CoreLocation
import WidgetKit

/// The app's single source of truth: the moment list, its persistence, and the
/// one-shot location sampling that grows it each time the app opens. The trail
/// (below) grows it between opens. Everything is written only to the on-device
/// store; when the user turns on iCloud sync, CloudSync mirrors that store into
/// their private database.
final class SpaceModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Permission {
        case undetermined  // never asked, so show the intro
        case granted
        case denied
    }

    @Published private(set) var moments: [Moment]
    @Published private(set) var permission: Permission = .undetermined

    /// Ignore re-activations within this window (app-switcher flips, Control
    /// Center peeks) so a burst of opens doesn't fake density.
    private let minimumSampleInterval: TimeInterval = 60

    private let manager = CLLocationManager()
    private var externalChangeObserver: NSObjectProtocol?

    override init() {
        moments = MomentPersistence.load()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        permission = Self.permission(from: manager.authorizationStatus)
        // CloudSync (or the other app) rewrote the moment file; pick it up.
        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: MomentSync.didChangeExternally,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.moments = MomentPersistence.load()
        }
    }

    deinit {
        if let externalChangeObserver {
            NotificationCenter.default.removeObserver(externalChangeObserver)
        }
    }

    var placeCount: Int { MomentGeometry.placeCount(in: moments) }

    var trailCount: Int { moments.lazy.filter { $0.kind == .trail }.count }

    /// When the trail last added a dot, for the one line in settings that shows
    /// it is working. Moments are kept sorted, so the last match is the newest.
    var lastTrailDate: Date? { moments.last { $0.kind == .trail }?.date }

    /// Forgets every dot the trail placed, keeping the ones the user made by
    /// opening the app. The counterpart to switching the trail on: whatever it
    /// gathered can be taken back in one tap, here and in iCloud.
    func eraseTrailDots() {
        let trailIDs = Set(moments.filter { $0.kind == .trail }.map(\.id))
        guard !trailIDs.isEmpty else { return }
        MomentSync.remove(ids: trailIDs)
        moments = MomentPersistence.load()
        Task { @MainActor in
            for id in trailIDs {
                CloudSync.shared?.momentDeleted(id)
            }
        }
    }

    /// The one ask, from Begin. Since 3.2 the map is meant to draw itself, so
    /// this asks for Always straight away rather than While Using first: iOS
    /// shows its ordinary prompt, grants background access provisionally if
    /// the user allows, and comes back on its own later to ask whether that
    /// should stand. Answer While Using only, at either point, and the app
    /// falls back to a dot per open, which is what 3.0 was.
    func requestPermission() {
        manager.requestAlwaysAuthorization()
    }

    /// Whether iOS currently lets the trail run.
    var isAlwaysAuthorized: Bool {
        manager.authorizationStatus == .authorizedAlways
    }

    /// Called on every foreground activation. One fix per open, at most.
    func sampleIfAuthorized() {
        guard permission == .granted else { return }
        if let last = moments.last, Date().timeIntervalSince(last.date) < minimumSampleInterval {
            return
        }
        manager.requestLocation()
    }

    /// Wipes the local store only; the caller decides what happens to iCloud.
    func eraseAll() {
        moments = []
        MomentPersistence.save(moments)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permission = Self.permission(from: manager.authorizationStatus)
        // The first grant arrives through this callback; sample right away so
        // the tap on Begin becomes the user's first dot.
        // (Randhawa, by one old reading: the first into the field.)
        if permission == .granted {
            sampleIfAuthorized()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if let last = moments.last, location.timestamp.timeIntervalSince(last.date) < minimumSampleInterval {
            return
        }
        let moment = Moment(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            date: location.timestamp,
            source: .opened
        )
        // Append through the file rather than over our in-memory copy: the
        // trail may have added dots while this object sat idle in a suspended
        // app, and saving our stale array would erase them.
        MomentSync.append(moment)
        moments = MomentPersistence.load()
        Task { @MainActor in
            CloudSync.shared?.momentAppended(moment.id)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No fix this time; the map simply doesn't gain a dot.
    }

    private static func permission(from status: CLAuthorizationStatus) -> Permission {
        switch status {
        case .notDetermined:
            return .undetermined
        case .authorizedAlways, .authorizedWhenInUse:
            return .granted
        default:
            return .denied
        }
    }
}

/// The trail: dots that arrive without the app being opened, so the map keeps
/// drawing itself while you live.
///
/// Since 3.2 this is the default way the map is made; it still needs the
/// user's yes to iOS's own prompt before it reads anything, and it goes quiet
/// the moment they say so, in the trail screen or in Settings. Three decisions
/// shape everything here.
///
/// **Why iOS wakes us, and why that is not a clock.** The only honest cadence a
/// background app can promise is a ceiling. iOS wakes a sleeping app when the
/// world changes, not when a timer fires, so this listens to the two cheapest
/// signals Apple offers: significant location changes, which arrive after a few
/// hundred metres of movement, and visits, which arrive when you settle
/// somewhere and when you leave. The user's cadence is applied on our side as
/// the smallest gap allowed between two dots. Sitting still all day produces no
/// dots, which is correct: the map is a record of places, and you did not go
/// anywhere.
///
/// **Why no continuous updates.** Continuous background location would need the
/// location background mode, would light the status bar blue, and would cost
/// real battery to tell us something these two signals already tell us well
/// enough. A map drawn at neighbourhood resolution does not need metre
/// resolution. Both APIs used here relaunch a terminated app on their own, so
/// the trail survives a reboot without any of that.
///
/// **Why this is a singleton started at launch.** When iOS relaunches the app
/// for a location event there may be no window and no view, so nothing in the
/// SwiftUI hierarchy can be trusted to exist. Monitoring has to be re-armed from
/// the app's own initialiser, which is what `RandhawaApp` does.
final class LocationTrail: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationTrail()

    /// Mirrors of the two facts the settings screen draws from. Published so
    /// that screen reacts to iOS answering rather than guessing when it will:
    /// the Always prompt is answered outside the app, and the user can revoke
    /// access in Settings while the sheet is open.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var cadence: TrailCadence = .off

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        cadence = TrailSettings.cadence
        // Seed both mirrors before the first delegate callback arrives, so a
        // sheet opened immediately after launch is never briefly wrong.
        authorizationStatus = manager.authorizationStatus
        manager.delegate = self
        // Neighbourhood resolution. The map clusters at 35 and 150 metres, so
        // anything finer than this is battery spent on precision nobody sees.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Deliberately absent: allowsBackgroundLocationUpdates. It belongs to
        // continuous updates and the location background mode, neither of which
        // this app has. Setting it without that mode traps at runtime.
    }

    /// Call once from the app's initialiser, on every launch including the
    /// silent ones iOS makes to deliver a location event.
    func start() {
        apply(TrailSettings.cadence)
    }

    var isAlwaysAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }

    /// Turns the trail on, off, or to a different cadence. Asks for Always the
    /// first time it is needed; iOS shows that prompt once per install, and
    /// after that only Settings can change the answer.
    func setCadence(_ newCadence: TrailCadence) {
        TrailSettings.cadence = newCadence
        cadence = newCadence
        if newCadence.isOn && !isAlwaysAuthorized {
            manager.requestAlwaysAuthorization()
        }
        apply(newCadence)
    }

    /// Starts or stops the monitoring the cadence calls for. Safe to call
    /// repeatedly; Core Location treats a redundant start as a no-op.
    private func apply(_ cadence: TrailCadence) {
        // Without Always the app is never woken, so monitoring would only
        // produce dots while the app is open, which the open itself already
        // does. Stop cleanly instead of pretending.
        guard cadence.isOn, isAlwaysAuthorized else {
            manager.stopMonitoringSignificantLocationChanges()
            manager.stopMonitoringVisits()
            return
        }
        if cadence.watchesMovement {
            manager.startMonitoringSignificantLocationChanges()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
        }
        if cadence.watchesVisits {
            manager.startMonitoringVisits()
        } else {
            manager.stopMonitoringVisits()
        }
    }

    /// Adds a dot, unless it would crowd the one before it. Runs in whatever
    /// sliver of background time iOS granted, so it touches only the file and
    /// gets out.
    private func record(latitude: Double, longitude: Double, date: Date) {
        let cadence = TrailSettings.cadence
        guard cadence.isOn else { return }
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else {
            return
        }
        let moment = Moment(latitude: latitude, longitude: longitude, date: date, source: .trail)
        // One read of the moment file, not two: the spacing check and the
        // append share it. Nothing else happens if the dot was too close to
        // the last one.
        guard MomentSync.appendIfSpaced(moment, minimumSpacing: cadence.minimumSpacing) else { return }
        Task { @MainActor in
            CloudSync.startIfEnabled()
            CloudSync.shared?.momentAppended(moment.id)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        // Covers the grant, and also the revoke: someone who turns Always off
        // in Settings should stop being followed immediately.
        apply(TrailSettings.cadence)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        record(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            date: location.timestamp
        )
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // A visit reports an arrival, a departure, or both. The arrival is the
        // interesting instant; a departure carries a distant-past arrival date,
        // so fall back to the departure to avoid backdating the dot.
        let date: Date
        if visit.arrivalDate != .distantPast {
            date = visit.arrivalDate
        } else if visit.departureDate != .distantFuture {
            date = visit.departureDate
        } else {
            date = Date()
        }
        record(
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude,
            date: date
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No fix this time. The trail simply skips a beat.
    }
}
