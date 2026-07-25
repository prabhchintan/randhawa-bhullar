import SwiftUI

/// Draws moments as an abstract constellation: no basemap, no labels, just
/// the shape of where you've been. Translucent dots stack, so places you
/// return to glow brighter; the newest moment is the single orange dot.
struct ConstellationView: View {
    let moments: [Moment]
    var dotDiameter: CGFloat = 6
    var inset: CGFloat = 24
    var highlightLatest = true

    var body: some View {
        Canvas { context, size in
            let points = MomentGeometry.projected(moments, in: size, padding: inset)
            guard !points.isEmpty else { return }
            let radius = dotDiameter / 2
            let lastIndex = points.count - 1

            for (index, point) in points.enumerated() {
                let rect = CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: dotDiameter,
                    height: dotDiameter
                )
                let color: Color
                if highlightLatest && index == lastIndex {
                    color = .orange
                } else {
                    color = .white.opacity(0.3)
                }
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Constellation of moments")
        .accessibilityValue(
            "\(moments.count) moments across \(MomentGeometry.placeCount(in: moments)) places"
        )
    }
}
