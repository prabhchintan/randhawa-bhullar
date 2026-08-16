import CoreGraphics
import Foundation
import UIKit

/// The ink: one way of drawing a life onto a map, shared by the app and the
/// widget so the two never disagree about what a place looks like.
///
/// Three marks, all translucent, all darkening where they repeat:
///
/// - **Blots**, where you stayed. Moments clumped at 35 metres, drawn as small
///   soft dots at a constant size. Density comes from stacking, not from
///   growing, so home reads as one dark mass at the scale of a country and as
///   a scatter of dots at the scale of a street, and both are true.
/// - **Threads**, how you moved. Consecutive moments joined by thin lines, one
///   stroke per day. Straight, because straight is what the app knows; a road
///   taken daily darkens like a place visited daily.
/// - **Today**, since midnight, drawn on top in orange: the live stroke over
///   the sediment. The newest dot wears a white ring. Memories sit above
///   everything, in gold.
///
/// Sizes are in screen points and every drawing routine takes a `unit`, the
/// length of one screen point in the drawing's own coordinates. The widget
/// draws in points, so its unit is 1; the map overlay draws in map points and
/// passes 1 / zoomScale.
enum Ink {
    /// Colours resolved for one appearance and one veil setting.
    struct Palette {
        let ink: CGColor
        let today: CGColor
        let memory: CGColor
        let ring: CGColor

        /// Light: a warm near-black on the muted map, sliding to white as the
        /// veil darkens the map underneath. Dark: white throughout, which is
        /// also what the constellation has always been.
        static func resolve(dark: Bool, veil: CGFloat = 0) -> Palette {
            let inkLight: (CGFloat, CGFloat, CGFloat) = (0.13, 0.10, 0.09)
            let white: (CGFloat, CGFloat, CGFloat) = (0.97, 0.97, 0.98)
            let mix: (CGFloat, CGFloat, CGFloat)
            if dark {
                mix = white
            } else {
                let t = Swift.min(Swift.max(veil, 0), 1)
                mix = (inkLight.0 + (white.0 - inkLight.0) * t,
                       inkLight.1 + (white.1 - inkLight.1) * t,
                       inkLight.2 + (white.2 - inkLight.2) * t)
            }
            return Palette(
                ink: CGColor(red: mix.0, green: mix.1, blue: mix.2, alpha: 1),
                today: UIColor.systemOrange.cgColor,
                memory: UIColor.systemYellow.cgColor,
                ring: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            )
        }
    }

    /// Today begins at local midnight: the part of the map that is still
    /// happening is the line you have drawn since you woke up.
    static func todayStart(now: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    /// Everything the draw routine needs, computed once per data change and
    /// never on the draw path. Positions are already projected, so the same
    /// value serves every tile at every zoom.
    struct Prepared {
        struct Blot {
            let point: CGPoint
            let count: Int
        }
        struct Dot {
            let point: CGPoint
            let date: Date
        }

        let blots: [Blot]
        /// One entry per thread: the projected points of its moments in order.
        let threads: [[CGPoint]]
        /// Every moment since local midnight, oldest first.
        let today: [Dot]
        /// Threads restricted to today's moments, for the orange stroke.
        let todayThreads: [[CGPoint]]
        let memories: [CGPoint]
        let newest: CGPoint?
        /// True when a thread stroke or blot could exist at all.
        var isEmpty: Bool { blots.isEmpty && memories.isEmpty }

        static let empty = Prepared(blots: [], threads: [], today: [], todayThreads: [], memories: [], newest: nil)
    }

    /// Projects and groups the data. `project` maps a coordinate to the
    /// drawing's coordinate space.
    static func prepare(
        moments: [Moment],
        memories: [Memory],
        now: Date = Date(),
        project: (_ latitude: Double, _ longitude: Double) -> CGPoint
    ) -> Prepared {
        let sorted = moments.sorted { $0.date < $1.date }
        let points = sorted.map { project($0.latitude, $0.longitude) }
        let clumps = MomentGeometry.clumps(in: sorted, radiusMeters: 35)
        let blots = clumps.map { Prepared.Blot(point: project($0.latitude, $0.longitude), count: $0.count) }
        let ranges = MomentGeometry.threads(in: sorted)
        let threads = ranges.map { Array(points[$0]) }

        let todayStart = todayStart(now: now)
        let firstToday = sorted.firstIndex { $0.date >= todayStart } ?? sorted.count
        let today = (firstToday..<sorted.count).map { Prepared.Dot(point: points[$0], date: sorted[$0].date) }
        // A thread that straddles the day boundary is drawn in ink up to the
        // boundary and in orange from there; the shared point keeps it joined.
        var todayThreads: [[CGPoint]] = []
        for range in ranges where range.upperBound > firstToday {
            let start = Swift.max(range.lowerBound, Swift.max(firstToday - 1, 0))
            if range.upperBound - start > 1 {
                todayThreads.append(Array(points[start..<range.upperBound]))
            }
        }

        let placed = memories.filter(\.hasLocation).map { project($0.latitude ?? 0, $0.longitude ?? 0) }
        return Prepared(
            blots: blots,
            threads: threads,
            today: today,
            todayThreads: todayThreads,
            memories: placed,
            newest: points.last
        )
    }

    /// Draws everything into `context`. `clip` is the region being drawn, in
    /// the same coordinates as the prepared points; marks outside it are
    /// skipped. Pass `nil` to draw all of it.
    static func draw(
        _ prepared: Prepared,
        in context: CGContext,
        palette: Palette,
        unit: CGFloat,
        clip: CGRect? = nil
    ) {
        let reach = 24 * unit
        let visible = clip?.insetBy(dx: -reach, dy: -reach)
        func onScreen(_ point: CGPoint) -> Bool {
            visible?.contains(point) ?? true
        }
        func onScreen(_ points: [CGPoint]) -> Bool {
            guard let visible else { return true }
            var minX = CGFloat.greatestFiniteMagnitude, minY = minX
            var maxX = -CGFloat.greatestFiniteMagnitude, maxY = maxX
            for p in points {
                minX = Swift.min(minX, p.x); maxX = Swift.max(maxX, p.x)
                minY = Swift.min(minY, p.y); maxY = Swift.max(maxY, p.y)
            }
            return visible.intersects(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Threads, past. One stroke per day so repeats stack.
        context.setStrokeColor(palette.ink.copy(alpha: 0.14) ?? palette.ink)
        context.setLineWidth(1.4 * unit)
        for thread in prepared.threads where onScreen(thread) {
            context.addLines(between: thread)
            context.strokePath()
        }

        // Blots. Two concentric fills: the second, wider and fainter, is the
        // bleed into the paper. Alpha grows with repeat visits and stops well
        // short of opaque so neighbours can still add up.
        for blot in prepared.blots where onScreen(blot.point) {
            let alpha = Swift.min(0.10 + 0.045 * CGFloat(blot.count), 0.55)
            let radius = unit * (2.6 + 0.2 * CGFloat(Swift.min(blot.count, 12)))
            context.setFillColor(palette.ink.copy(alpha: alpha * 0.3) ?? palette.ink)
            context.fillEllipse(in: circle(blot.point, radius * 1.7))
            context.setFillColor(palette.ink.copy(alpha: alpha) ?? palette.ink)
            context.fillEllipse(in: circle(blot.point, radius))
        }

        // Today, on top: the orange stroke and its dots. Lighter than the
        // newest ring, so a busy day reads as a line and not a blaze.
        context.setStrokeColor(palette.today.copy(alpha: 0.7) ?? palette.today)
        context.setLineWidth(1.8 * unit)
        for thread in prepared.todayThreads where onScreen(thread) {
            context.addLines(between: thread)
            context.strokePath()
        }
        context.setFillColor(palette.today.copy(alpha: 0.85) ?? palette.today)
        for dot in prepared.today where onScreen(dot.point) {
            context.fillEllipse(in: circle(dot.point, 2.6 * unit))
        }

        // Memories: gold, ringed white, above the ink.
        for point in prepared.memories where onScreen(point) {
            let rect = circle(point, 4.5 * unit)
            context.setFillColor(palette.memory)
            context.fillEllipse(in: rect)
            context.setStrokeColor(palette.ring)
            context.setLineWidth(1.5 * unit)
            context.strokeEllipse(in: rect.insetBy(dx: 0.75 * unit, dy: 0.75 * unit))
        }

        // The newest moment: where you are, or were last.
        if let newest = prepared.newest, onScreen(newest) {
            let rect = circle(newest, 6 * unit)
            context.setFillColor(palette.today)
            context.fillEllipse(in: rect)
            context.setStrokeColor(palette.ring)
            context.setLineWidth(2 * unit)
            context.strokeEllipse(in: rect.insetBy(dx: unit, dy: unit))
        }
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
