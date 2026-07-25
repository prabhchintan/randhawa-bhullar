import CoreGraphics
import ImageIO
import Foundation

// Renders a 1024x1024, opaque (no alpha) app icon directly into a CGContext,
// App Store icons must be exactly 1024x1024 with no alpha channel.
//
// v2.0 icon: a constellation of moments. Translucent white dots stack into a
// glow where places repeat (the home cluster); the single orange dot is the
// newest moment. Same near-black ground as the v1 icon, so the family reads.
let size = 1024
let outPath = "/Users/prabrandhawa/Desktop/Randhawa/Randhawa/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("no context") }

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

// Background: near-black, matching the v1 icon and the in-app constellation.
ctx.setFillColor(color(0.043, 0.043, 0.047))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Hand-placed moments in unit space: a dense home cluster lower-left of
// center, a second small hub upper-right, a loose strand between them, and a
// few far travels. Deliberate composition, not random: the icon is a glyph.
let cluster: [(CGFloat, CGFloat)] = [
    (0.355, 0.415), (0.385, 0.435), (0.370, 0.455), (0.400, 0.410),
    (0.345, 0.440), (0.380, 0.470), (0.410, 0.445), (0.360, 0.395),
    (0.395, 0.480), (0.335, 0.470),
]
let hub: [(CGFloat, CGFloat)] = [
    (0.665, 0.655), (0.690, 0.675), (0.675, 0.700), (0.700, 0.645),
]
let strand: [(CGFloat, CGFloat)] = [
    (0.475, 0.520), (0.555, 0.575), (0.610, 0.620),
]
let travels: [(CGFloat, CGFloat)] = [
    (0.230, 0.700), (0.775, 0.310), (0.300, 0.215),
    (0.740, 0.845), (0.180, 0.360), (0.845, 0.520),
]
// The newest moment: at the edge of the home cluster, in orange.
let latest: (CGFloat, CGFloat) = (0.430, 0.500)

let white = color(0.97, 0.97, 0.98, 0.30) // stacks into a glow where dots overlap
let orange = color(1.0, 0.584, 0.0)

func drawDot(_ point: (CGFloat, CGFloat), radius: CGFloat, fill: CGColor) {
    let cx = point.0 * CGFloat(size)
    let cy = (1 - point.1) * CGFloat(size) // y-down design coords in a y-up context
    ctx.setFillColor(fill)
    ctx.fillEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
}

for point in cluster { drawDot(point, radius: 34, fill: white) }
for point in hub { drawDot(point, radius: 32, fill: white) }
for point in strand { drawDot(point, radius: 28, fill: white) }
for point in travels { drawDot(point, radius: 26, fill: white) }
drawDot(latest, radius: 30, fill: orange)

guard let cgImage = ctx.makeImage() else { fatalError("no image") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("no destination")
}
CGImageDestinationAddImage(dest, cgImage, nil)
if CGImageDestinationFinalize(dest) {
    print("wrote \(outPath)")
} else {
    fatalError("write failed")
}
