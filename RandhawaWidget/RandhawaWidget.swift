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

/// Renders Apple Maps snapshots with the ink baked in, matching the in-app
/// map: blots that darken where you return, threads where you moved, today in
/// orange, memories in gold. Only stored data is read; the widget never
/// samples location.
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
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
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
            completion(draw(moments: moments, memories: memories, on: snapshot, size: size, style: style))
        }
    }

    /// The same ink the app draws, on the snapshot: blots, threads, today in
    /// orange, memories in gold. Points here are screen points, so the unit is 1.
    private static func draw(
        moments: [Moment],
        memories: [Memory],
        on snapshot: MKMapSnapshotter.Snapshot,
        size: CGSize,
        style: UIUserInterfaceStyle
    ) -> UIImage {
        let prepared = Ink.prepare(moments: moments, memories: memories) { latitude, longitude in
            snapshot.point(for: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        let palette = Ink.Palette.resolve(dark: style == .dark)
        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            snapshot.image.draw(at: .zero)
            Ink.draw(prepared, in: context.cgContext, palette: palette, unit: 1)
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
        .description("Your places in ink on a real map, darker where you return, with today in orange and your memories in gold.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    RandhawaMapWidget()
} timeline: {
    MapEntry(date: Date(), moments: DemoMap.moments, memories: [], lightMap: nil, darkMap: nil)
}
