import SwiftUI

/// The colors used to paint the dot grid. Bundling them in a value type lets
/// each context (the app, a Home Screen widget, a Lock Screen accessory)
/// supply its own palette while sharing one renderer.
struct DotPalette {
    var elapsed: Color
    var today: Color
    var remaining: Color
    var memory: Color

    /// Full-color palette for the app and Home Screen widgets.
    static let standard = DotPalette(
        elapsed: .primary,
        today: .orange,
        remaining: .primary.opacity(0.15),
        memory: .orange.opacity(0.45)
    )

    /// Monochrome palette for Lock Screen accessories, which the system
    /// renders with vibrancy. Here opacity, not hue, conveys progress.
    static let accessory = DotPalette(
        elapsed: .primary,
        today: .primary,
        remaining: .primary.opacity(0.25),
        memory: .primary.opacity(0.6)
    )
}

/// Draws one dot per unit of the current scale, sizing them to fill the
/// available space. Units listed in `highlighted` (the ones holding a
/// memory) render in the palette's memory color, so annotated time glows
/// softly inside the elapsed field.
///
/// A single `Canvas` does all the drawing rather than hundreds of `View`s, so it
/// renders cheaply and stays well inside the widget memory budget at every size.
struct DotGrid: View {
    let position: ScalePosition
    var palette: DotPalette = .standard
    var highlighted: Set<Int> = []

    /// Diameter of each dot as a fraction of its grid cell. Below `1` it leaves
    /// gutters between dots.
    var dotScale: CGFloat = 0.7

    /// The unit the user has opened, drawn with a ring so the grid says which
    /// dot the sheet is talking about.
    var selected: Int?

    /// Set by the app to make dots openable. Left nil by the widgets, which
    /// have no sheets to open and ignore gestures anyway.
    var onSelectUnit: ((Int) -> Void)?

    /// Names the unit for VoiceOver ("Day 219 of 365"). The grid is a single
    /// accessibility element, so without this the whole feature would be
    /// unreachable: there is no per-dot element to focus, and hit testing a
    /// dot a few points wide is not something anyone should have to do.
    var unitName: String = "Unit"

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let layout = GridLayout(count: position.total, in: size)
                let radius = layout.cell * dotScale / 2
                guard radius > 0 else { return }
                let current = position.index

                for index in 0..<position.total {
                    let unit = index + 1
                    let center = layout.center(of: index)
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    let color: Color
                    if unit == current {
                        color = palette.today
                    } else if highlighted.contains(unit) {
                        color = palette.memory
                    } else if unit < current {
                        color = palette.elapsed
                    } else {
                        color = palette.remaining
                    }
                    context.fill(Path(ellipseIn: rect), with: .color(color))

                    // The ring sits outside the dot, so selecting one never
                    // changes how much of the field is filled in.
                    if unit == selected {
                        let ring = rect.insetBy(dx: -radius * 0.9, dy: -radius * 0.9)
                        context.stroke(
                            Path(ellipseIn: ring),
                            with: .color(palette.today),
                            lineWidth: Swift.max(radius * 0.35, 1)
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { point in
                guard let onSelectUnit else { return }
                let layout = GridLayout(count: position.total, in: proxy.size)
                guard let unit = layout.unit(at: point) else { return }
                onSelectUnit(unit)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Time progress")
        .accessibilityValue(
            "\(unitName) \(position.index) of \(position.total), \(position.percent) percent elapsed"
        )
        .accessibilityAddTraits(onSelectUnit == nil ? [] : .isButton)
        .accessibilityHint(onSelectUnit == nil ? "" : "Opens the current \(unitName.lowercased())")
        // Activating the element opens the unit in progress. Sighted users get
        // any dot by tapping it; this at least makes the sheet reachable, and
        // "now" is the one dot that needs no aiming to mean something.
        .accessibilityAction {
            onSelectUnit?(position.index)
        }
    }
}

/// Packs `count` equal squares into a rectangle, maximizing cell size. Driving
/// the layout off the available rect means the grid looks deliberate at any
/// widget family or screen size without per-size tuning.
private struct GridLayout {
    let count: Int
    let columns: Int
    let cell: CGFloat
    let origin: CGPoint

    init(count: Int, in size: CGSize) {
        self.count = count
        guard count > 0, size.width > 0, size.height > 0 else {
            columns = 1
            cell = 0
            origin = .zero
            return
        }

        // Try every column count and keep the one that yields the largest cell.
        // `count` is at most 1440, so this loop is cheap and runs once per draw.
        var bestColumns = 1
        var bestCell: CGFloat = 0
        for candidate in 1...count {
            let candidateRows = Int((Double(count) / Double(candidate)).rounded(.up))
            let candidateCell = min(
                size.width / CGFloat(candidate),
                size.height / CGFloat(candidateRows)
            )
            if candidateCell > bestCell {
                bestCell = candidateCell
                bestColumns = candidate
            }
        }

        let rows = Int((Double(count) / Double(bestColumns)).rounded(.up))
        columns = bestColumns
        cell = bestCell

        // Center the whole block within the available size.
        let gridWidth = bestCell * CGFloat(bestColumns)
        let gridHeight = bestCell * CGFloat(rows)
        origin = CGPoint(
            x: (size.width - gridWidth) / 2,
            y: (size.height - gridHeight) / 2
        )
    }

    /// The 1-based unit under `point`, or nil outside the grid.
    ///
    /// Hit-testing the cell rather than the drawn circle is deliberate: at the
    /// minute scale a dot is a few points across, and asking someone to hit
    /// that would make the whole feature feel broken. Every point inside the
    /// block belongs to exactly one dot, so there are no dead gutters.
    func unit(at point: CGPoint) -> Int? {
        guard cell > 0 else { return nil }
        let column = Int(floor((point.x - origin.x) / cell))
        let row = Int(floor((point.y - origin.y) / cell))
        guard column >= 0, column < columns, row >= 0 else { return nil }
        let index = row * columns + column
        guard index >= 0, index < count else { return nil }
        return index + 1
    }

    func center(of index: Int) -> CGPoint {
        let column = index % columns
        let row = index / columns
        return CGPoint(
            x: origin.x + (CGFloat(column) + 0.5) * cell,
            y: origin.y + (CGFloat(row) + 0.5) * cell
        )
    }
}

#Preview {
    DotGrid(position: TimeScale.days.position())
        .padding()
}
