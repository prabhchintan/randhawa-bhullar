import Foundation
import CoreLocation
import WidgetKit

/// The app's single source of truth: the moment list, its persistence, and the
/// one-shot location sampling that grows it. Location is read only while the
/// app is open and written only to the on-device store; when the user turns on
/// iCloud sync, CloudSync mirrors that store into their private database.
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

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
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

/// The trail: dots that arrive without the app being opened, for people who
/// want the map to keep drawing itself while they live.
///
/// Off until the user turns it on, and off again the moment they say so. Three
/// decisions shape everything here.
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
final class LocationTrail: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrail()

    private let manager = CLLocationManager()

    /// Set while a request is in flight so the authorization callback knows the
    /// user is mid-decision and can finish turning the trail on for them.
    private var awaitingAlwaysDecision = false

    private override init() {
        super.init()
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
        manager.authorizationStatus == .authorizedAlways
    }

    /// Whether the user has been asked for Always and said no. The settings
    /// screen uses this to stop offering a prompt that iOS will not show again.
    var needsSettingsForAlways: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .denied, .restricted: return true
        default: return false
        }
    }

    /// Turns the trail on, off, or to a different cadence. Asks for Always the
    /// first time it is needed; iOS shows that prompt once per install, and
    /// after that only Settings can change the answer.
    func setCadence(_ cadence: TrailCadence) {
        TrailSettings.cadence = cadence
        if cadence.isOn && !isAlwaysAuthorized {
            awaitingAlwaysDecision = true
            manager.requestAlwaysAuthorization()
        }
        apply(cadence)
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
        // Throttle against the newest dot from any source, so a trail wake
        // seconds after the user opened the app does not double-mark the spot.
        if let newest = MomentSync.newestDate(), date.timeIntervalSince(newest) < cadence.minimumSpacing {
            return
        }
        let moment = Moment(latitude: latitude, longitude: longitude, date: date, source: .trail)
        MomentSync.append(moment)
        Task { @MainActor in
            CloudSync.startIfEnabled()
            CloudSync.shared?.momentAppended(moment.id)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if awaitingAlwaysDecision, manager.authorizationStatus != .notDetermined {
            awaitingAlwaysDecision = false
        }
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
