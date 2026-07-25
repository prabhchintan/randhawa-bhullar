import SwiftUI
import WidgetKit
import MapKit
import UIKit

/// A pleasant fake map for the widget gallery: one dense home cluster, a
/// second city, and a few travels. Never shown once real moments exist.
enum DemoMap {
    static let moments: [Moment] = {
        let seeds: [(Double, Double, Int)] = [
            (30.267, -97.743, 9),
            (30.285, -97.736, 3),
            (29.760, -95.369, 4),
            (32.777, -96.797, 2),
            (29.424, -98.493, 1),
            (31.549, -97.146, 1),
        ]
        var moments: [Moment] = []
        var day = 0.0
        for (lat, lon, count) in seeds {
            for i in 0..<count {
                let jitter = Double(i) * 0.0035
                moments.append(Moment(
                    latitude: lat + jitter * 0.6,
                    longitude: lon + jitter,
                    date: Date(timeIntervalSince1970: 1_700_000_000 + day * 86_400)
                ))
                day += 1
            }
        }
        return moments
    }()
}

/// One rendered map per timeline reload: the same snapshot in both
/// appearances, plus the raw data so the view can fall back to the
/// constellation when the tiles couldn't be fetched.
struct MapEntry: TimelineEntry {
    let date: Date
    let moments: [Moment]
    let memories: [Memory]
    let lightMap: UIImage?
    let darkMap: UIImage?
}

/// The map only changes when the app adds a moment or a memory, and the app
/// reloads widget timelines at that point. Rendering needs map tiles from the
/// network, so a failed fetch schedules a retry instead of `.never`.
struct MapProvider: TimelineProvider {
    func placeholder(in context: Context) -> MapEntry {
        MapEntry(date: Date(), moments: DemoMap.moments, memories: [], lightMap: nil, darkMap: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MapEntry) -> Void) {
        let stored = MomentPersistence.load()
        // The widget gallery should show a lived-in map, never an empty one.
        let moments = (context.isPreview && stored.isEmpty) ? DemoMap.moments : stored
        let memories = context.isPreview ? [] : MemoryPersistence.load()
        MapSnapshotRenderer.render(moments: moments, memories: memories, size: context.displaySize) { light, dark in
            completion(MapEntry(date: Date(), moments: moments, memories: memories, lightMap: light, darkMap: dark))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MapEntry>) -> Void) {
        let moments = MomentPersistence.load()
        let memories = MemoryPersistence.load()
        MapSnapshotRenderer.render(moments: moments, memories: memories, size: context.displaySize) { light, dark in
            let entry = MapEntry(date: Date(), moments: moments, memories: memories, lightMap: light, darkMap: dark)
            let policy: TimelineReloadPolicy = (light == nil && dark == nil && !moments.isEmpty)
                ? .after(Date().addingTimeInterval(30 * 60))
                : .never
            completion(Timeline(entries: [entry], policy: policy))
        }
    }
}

/// Renders Apple Maps snapshots with the dots baked in, matching the in-app
/// map: clumped density dots that darken where you return, gold memory dots,
/// and the newest moment ringed in white. Only stored data is read; the
/// widget never samples location.
enum MapSnapshotRenderer {
    static func render(
        moments: [Moment],
        memories: [Memory],
        size: CGSize,
        completion: @escaping (UIImage?, UIImage?) -> Void
    ) {
        guard let region = MomentGeometry.boundingRegion(for: moments),
              size.width > 0, size.height > 0 else {
            completion(nil, nil)
            return
        }
        render(moments: moments, memories: memories, region: region, size: size, style: .light) { light in
            render(moments: moments, memories: memories, region: region, size: size, style: .dark) { dark in
                completion(light, dark)
            }
        }
    }

    private static func render(
        moments: [Moment],
        memories: [Memory],
        region: MomentGeometry.Region,
        size: CGSize,
        style: UIUserInterfaceStyle,
        completion: @escaping (UIImage?) -> Void
    ) {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: region.centerLatitude,
                longitude: region.centerLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: region.latitudeSpan,
                longitudeDelta: region.longitudeSpan
            )
        )
        options.size = size
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false
        options.preferredConfiguration = configuration
        options.traitCollection = UITraitCollection(traitsFrom: [
            options.traitCollection,
            UITraitCollection(displayScale: 3),
            UITraitCollection(userInterfaceStyle: style)
        ])

        MKMapSnapshotter(options: options).start { snapshot, _ in
            guard let snapshot = snapshot else {
                completion(nil)
                return
            }
            completion(draw(moments: moments, memories: memories, on: snapshot, size: size))
        }
    }

    /// Same visual constants as the in-app `MomentMap` annotations.
    private static func draw(
        moments: [Moment],
        memories: [Memory],
        on snapshot: MKMapSnapshotter.Snapshot,
        size: CGSize
    ) -> UIImage {
        let clumps = MomentGeometry.clumps(in: moments, radiusMeters: 35)
        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            snapshot.image.draw(at: .zero)

            for clump in clumps {
                let point = snapshot.point(for: CLLocationCoordinate2D(
                    latitude: clump.latitude,
                    longitude: clump.longitude
                ))
                let diameter = CGFloat(10 + Swift.min(clump.count, 14))
                let opacity = Swift.min(0.25 + 0.1 * Double(clump.count), 0.85)
                UIColor.systemOrange.withAlphaComponent(CGFloat(opacity)).setFill()
                context.cgContext.fillEllipse(in: CGRect(
                    x: point.x - diameter / 2,
                    y: point.y - diameter / 2,
                    width: diameter,
                    height: diameter
                ))
            }

            for memory in memories where memory.hasLocation {
                let point = snapshot.point(for: CLLocationCoordinate2D(
                    latitude: memory.latitude ?? 0,
                    longitude: memory.longitude ?? 0
                ))
                let rect = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
                UIColor.systemYellow.setFill()
                context.cgContext.fillEllipse(in: rect)
                UIColor.white.setStroke()
                context.cgContext.setLineWidth(1.5)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.75, dy: 0.75))
            }

            if let latest = moments.last {
                let point = snapshot.point(for: CLLocationCoordinate2D(
                    latitude: latest.latitude,
                    longitude: latest.longitude
                ))
                let rect = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
                UIColor.systemOrange.setFill()
                context.cgContext.fillEllipse(in: rect)
                UIColor.white.setStroke()
                context.cgContext.setLineWidth(2)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
            }
        }
    }
}

struct RandhawaMapWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: MapEntry

    private var map: UIImage? {
        colorScheme == .dark
            ? (entry.darkMap ?? entry.lightMap)
            : (entry.lightMap ?? entry.darkMap)
    }

    var body: some View {
        Color.clear
            .containerBackground(for: .widget) {
                if let map = map {
                    Image(uiImage: map)
                        .resizable()
                        .scaledToFill()
                } else if entry.moments.isEmpty {
                    ZStack {
                        Color(red: 0.043, green: 0.043, blue: 0.047)
                        Text("Open Randhawa to place your first dot")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(12)
                    }
                } else {
                    // Tiles unavailable (offline, or the gallery's synchronous
                    // placeholder): the constellation still shows the shape.
                    ZStack {
                        Color(red: 0.043, green: 0.043, blue: 0.047)
                        ConstellationView(moments: entry.moments, dotDiameter: 5, inset: 14)
                    }
                }
            }
    }
}

struct RandhawaMapWidget: Widget {
    private let kind = "RandhawaMapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MapProvider()) { entry in
            RandhawaMapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Map")
        .description("Your moments as orange dots on a real map, denser where you return, with your memories in gold.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    RandhawaMapWidget()
} timeline: {
    MapEntry(date: Date(), moments: DemoMap.moments, memories: [], lightMap: nil, darkMap: nil)
}
