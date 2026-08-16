import SwiftUI
import MapKit
import UIKit

/// The real map with the ink on it: an MKMapView, a muted basemap, and two
/// overlays drawn by hand. The wash sits between the tiles and the ink and
/// takes the veil as its alpha; slide it to one and the map is gone, leaving
/// the constellation, on a projection you can still zoom. The ink overlay
/// draws every blot and thread per tile from data prepared once, so a year of
/// trail dots costs the same as a week of app opens.
///
/// SwiftUI's Map was the previous host. It puts one view per annotation on
/// screen, which is fine for hundreds of dots and not for tens of thousands,
/// and it offers no way to draw under the labels or between the tiles.
struct InkMapView: UIViewRepresentable {
    let moments: [Moment]
    let memories: [Memory]
    let veil: Double
    let dark: Bool
    /// Bumped by the parent to ask for the map to frame every moment again.
    var fitRequest: Int = 0
    var onTapMemory: (Memory) -> Void = { _ in }
    var onTapPlace: (MomentGeometry.Clump) -> Void = { _ in }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false
        mapView.preferredConfiguration = configuration
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.delegate = context.coordinator
        mapView.addOverlay(context.coordinator.wash, level: .aboveLabels)
        mapView.addOverlay(context.coordinator.ink, level: .aboveLabels)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        // Let the map's own double tap zoom win; ours only fires on a clean single tap.
        for recognizer in mapView.subviews.flatMap({ $0.gestureRecognizers ?? [] }) {
            if let doubleTap = recognizer as? UITapGestureRecognizer, doubleTap.numberOfTapsRequired == 2 {
                tap.require(toFail: doubleTap)
            }
        }
        mapView.addGestureRecognizer(tap)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTapMemory = onTapMemory
        coordinator.onTapPlace = onTapPlace
        coordinator.update(moments: moments, memories: memories, veil: veil, dark: dark, fitRequest: fitRequest)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        weak var mapView: MKMapView?
        let wash = WashOverlay()
        let ink = InkOverlay()
        var onTapMemory: (Memory) -> Void = { _ in }
        var onTapPlace: (MomentGeometry.Clump) -> Void = { _ in }

        private var washRenderer: MKOverlayRenderer?
        private var inkRenderer: InkRenderer?
        private var moments: [Moment] = []
        private var memories: [Memory] = []
        private var clumps: [MomentGeometry.Clump] = []
        private var veil: Double = -1
        private var dark: Bool?
        private var lastFitRequest = 0
        private var lastNewestID: UUID?
        private var hasFitted = false

        func update(moments: [Moment], memories: [Memory], veil: Double, dark: Bool, fitRequest: Int) {
            let dataChanged = moments != self.moments || memories != self.memories
            if dataChanged {
                self.moments = moments
                self.memories = memories
                clumps = MomentGeometry.clumps(in: moments, radiusMeters: 35)
                ink.prepared = Ink.prepare(moments: moments, memories: memories) { latitude, longitude in
                    let point = MKMapPoint(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    return CGPoint(x: point.x, y: point.y)
                }
                inkRenderer?.setNeedsDisplay()
            }
            let appearanceChanged = dark != self.dark || (veil != self.veil && !dark)
            self.dark = dark
            if veil != self.veil {
                self.veil = veil
                washRenderer?.alpha = CGFloat(veil)
            }
            if appearanceChanged {
                inkRenderer?.palette = Ink.Palette.resolve(dark: dark, veil: CGFloat(veil))
                inkRenderer?.setNeedsDisplay()
            }
            fitIfNeeded(fitRequest: fitRequest, dataChanged: dataChanged)
        }

        /// Frames every moment on first appearance, on request, and when a
        /// new moment lands somewhere the map is not looking. Otherwise the
        /// camera belongs to the user.
        private func fitIfNeeded(fitRequest: Int, dataChanged: Bool) {
            guard let mapView, !moments.isEmpty else { return }
            let newestID = moments.last?.id
            var shouldFit = false
            var animated = true
            if !hasFitted {
                shouldFit = true
                animated = false
            } else if fitRequest != lastFitRequest {
                shouldFit = true
            } else if dataChanged, newestID != lastNewestID, let newest = moments.last {
                let point = MKMapPoint(CLLocationCoordinate2D(latitude: newest.latitude, longitude: newest.longitude))
                shouldFit = !mapView.visibleMapRect.contains(point)
            }
            lastFitRequest = fitRequest
            lastNewestID = newestID
            guard shouldFit, let region = MomentGeometry.boundingRegion(for: moments) else { return }
            hasFitted = true
            let coordinateRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: region.centerLatitude, longitude: region.centerLongitude),
                span: MKCoordinateSpan(latitudeDelta: region.latitudeSpan, longitudeDelta: region.longitudeSpan)
            )
            mapView.setRegion(mapView.regionThatFits(coordinateRegion), animated: animated)
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay === wash {
                let renderer = WashRenderer(overlay: overlay)
                renderer.alpha = CGFloat(Swift.max(veil, 0))
                washRenderer = renderer
                return renderer
            }
            let renderer = InkRenderer(overlay: ink)
            renderer.palette = Ink.Palette.resolve(dark: dark ?? false, veil: CGFloat(Swift.max(veil, 0)))
            inkRenderer = renderer
            return renderer
        }

        // MARK: - Taps

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView, recognizer.state == .ended else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            // Metres per screen point at this latitude and zoom, so the hit
            // radius is a thumb's width on screen whatever the scale.
            let mapPointsPerPoint = mapView.visibleMapRect.size.width / Double(mapView.bounds.width)
            let metersPerPoint = mapPointsPerPoint * MKMetersPerMapPointAtLatitude(coordinate.latitude)
            let reach = 22 * metersPerPoint

            var bestMemory: (Memory, Double)?
            for memory in memories where memory.hasLocation {
                let distance = MomentGeometry.metersBetween(
                    coordinate.latitude, coordinate.longitude, memory.latitude ?? 0, memory.longitude ?? 0)
                if distance <= reach, distance < (bestMemory?.1 ?? .infinity) {
                    bestMemory = (memory, distance)
                }
            }
            if let (memory, _) = bestMemory {
                onTapMemory(memory)
                return
            }
            var bestClump: (MomentGeometry.Clump, Double)?
            for clump in clumps {
                let distance = MomentGeometry.metersBetween(
                    coordinate.latitude, coordinate.longitude, clump.latitude, clump.longitude)
                if distance <= reach, distance < (bestClump?.1 ?? .infinity) {
                    bestClump = (clump, distance)
                }
            }
            if let (clump, _) = bestClump {
                onTapPlace(clump)
            }
        }
    }
}

/// A world-sized overlay whose renderer paints black; its alpha is the veil.
final class WashOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 0, longitude: 0) }
    var boundingMapRect: MKMapRect { .world }
}

final class WashRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        context.setFillColor(CGColor(gray: 0.02, alpha: 1))
        context.fill(rect(for: mapRect))
    }
}

/// Holds the prepared ink for the renderer. Renderers draw on background
/// threads, so the value is swapped under a lock and read once per tile.
final class InkOverlay: NSObject, MKOverlay {
    private let lock = NSLock()
    private var storage: Ink.Prepared = .empty

    var prepared: Ink.Prepared {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); storage = newValue; lock.unlock() }
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 0, longitude: 0) }
    var boundingMapRect: MKMapRect { .world }
}

final class InkRenderer: MKOverlayRenderer {
    private let lock = NSLock()
    private var storedPalette = Ink.Palette.resolve(dark: false)

    var palette: Ink.Palette {
        get { lock.lock(); defer { lock.unlock() }; return storedPalette }
        set { lock.lock(); storedPalette = newValue; lock.unlock() }
    }

    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        true
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? InkOverlay else { return }
        let prepared = overlay.prepared
        guard !prepared.isEmpty || prepared.newest != nil else { return }
        let clip = CGRect(x: mapRect.origin.x, y: mapRect.origin.y, width: mapRect.size.width, height: mapRect.size.height)
        Ink.draw(prepared, in: context, palette: palette, unit: 1 / zoomScale, clip: clip)
    }
}
