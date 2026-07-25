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

    var body: some View {
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
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Time progress")
        .accessibilityValue(
            "Unit \(position.index) of \(position.total), \(position.percent) percent elapsed"
        )
    }
}

/// Packs `count` equal squares into a rectangle, maximizing cell size. Driving
/// the layout off the available rect means the grid looks deliberate at any
/// widget family or screen size without per-size tuning.
private struct GridLayout {
    let columns: Int
    let cell: CGFloat
    let origin: CGPoint

    init(count: Int, in size: CGSize) {
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
