import Foundation
import CoreLocation
import Combine

/// Names for coordinates, resolved once and remembered for the life of the
/// process. Both apps need a place to arrive as a word: Bhullar because it
/// draws no map, Randhawa when a blot is opened or a memory is pinned. This
/// asks Apple's geocoder for that word and asks only once per neighbourhood.
@MainActor
final class PlaceNames: ObservableObject {
    static let shared = PlaceNames()

    @Published private(set) var names: [String: String] = [:]

    private let geocoder = CLGeocoder()
    private var inFlight: [String: [(String?) -> Void]] = [:]
    /// CLGeocoder cancels whatever it is already doing the moment a second
    /// request starts on the same instance, so a screen that fires several
    /// lookups at once (one per row, all on appear) left every row but the
    /// last stuck on its placeholder forever. Queue them one at a time instead.
    private var queue: [(key: String, coordinate: CLLocationCoordinate2D)] = []
    private var geocoding = false

    /// Roughly 100 metres of latitude per key, so two dots in the same block
    /// share one lookup.
    private func key(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
    }

    func name(for coordinate: CLLocationCoordinate2D) -> String? {
        names[key(coordinate)]
    }

    /// Starts a lookup if none is cached or running; `names` publishes the
    /// answer when it arrives.
    func resolve(_ coordinate: CLLocationCoordinate2D) {
        lookup(coordinate) { _ in }
    }

    /// Like `resolve`, and also calls back with the name, or nil if Apple has
    /// no word for the spot. The callback runs on the main actor.
    func lookup(_ coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let cacheKey = key(coordinate)
        if let cached = names[cacheKey] {
            completion(cached)
            return
        }
        if inFlight[cacheKey] != nil {
            inFlight[cacheKey]?.append(completion)
            return
        }
        inFlight[cacheKey] = [completion]
        queue.append((cacheKey, coordinate))
        geocodeNext()
    }

    private func geocodeNext() {
        guard !geocoding, let next = queue.first else { return }
        geocoding = true
        queue.removeFirst()
        let cacheKey = next.key
        let location = CLLocation(latitude: next.coordinate.latitude, longitude: next.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self else { return }
                self.geocoding = false
                let waiting = self.inFlight.removeValue(forKey: cacheKey) ?? []
                var name: String?
                if let placemark = placemarks?.first {
                    let joined = [placemark.locality ?? placemark.name, placemark.administrativeArea]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                    if !joined.isEmpty {
                        name = joined
                        self.names[cacheKey] = joined
                    }
                }
                for callback in waiting {
                    callback(name)
                }
                self.geocodeNext()
            }
        }
    }
}
