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
            date: location.timestamp
        )
        moments.append(moment)
        MomentPersistence.save(moments)
        WidgetCenter.shared.reloadAllTimelines()
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
