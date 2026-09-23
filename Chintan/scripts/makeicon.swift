import CoreGraphics
import ImageIO
import Foundation

// The house's icon: one jharokha, the arched window the Home tab is named
// for, in warm paper on the deep saffron ground. No letters, no wordplay.
// App Store icons must be exactly 1024x1024 with no alpha channel.
let size = 1024
// Run from the Chintan directory: swift scripts/makeicon.swift [out.png]
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Chintan/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

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

let s = CGFloat(size)
// The saffron and the paper from the asset catalog, light appearance.
let saffron = color(0.722, 0.361, 0.071)
let paper = color(0.969, 0.949, 0.918)

ctx.setFillColor(saffron)
ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

// The room behind the window, a deeper saffron.
let shade = color(0.478, 0.212, 0.031)
let cx = s * 0.5

// A pointed arch: straight jambs, two arcs meeting at the apex, each arc's
// centre on the spring line and pushed across the middle.
// CoreGraphics puts y = 0 at the bottom.
func arch(halfWidth: CGFloat, bottom: CGFloat, springLine: CGFloat, apex: CGFloat) -> CGPath {
    let rise = apex - springLine
    let offset = (rise * rise - halfWidth * halfWidth) / (2 * halfWidth)
    let radius = halfWidth + offset
    let path = CGMutablePath()
    path.move(to: CGPoint(x: cx - halfWidth, y: bottom))
    path.addLine(to: CGPoint(x: cx - halfWidth, y: springLine))
    path.addArc(center: CGPoint(x: cx + offset, y: springLine), radius: radius,
                startAngle: .pi, endAngle: atan2(rise, -offset), clockwise: true)
    path.addArc(center: CGPoint(x: cx - offset, y: springLine), radius: radius,
                startAngle: atan2(rise, offset), endAngle: 0, clockwise: true)
    path.addLine(to: CGPoint(x: cx + halfWidth, y: bottom))
    path.closeSubpath()
    return path
}

let halfWidth = s * 0.2
let bottom = s * 0.27
let springLine = s * 0.54
let apex = s * 0.80
let frame = s * 0.04

// The frame in paper, the opening in shade, one mullion down the middle.
ctx.addPath(arch(halfWidth: halfWidth, bottom: bottom, springLine: springLine, apex: apex))
ctx.setFillColor(paper)
ctx.fillPath()

let opening = arch(halfWidth: halfWidth - frame, bottom: bottom, springLine: springLine,
                   apex: apex - frame * 1.5)
ctx.addPath(opening)
ctx.setFillColor(shade)
ctx.fillPath()

ctx.saveGState()
ctx.addPath(opening)
ctx.clip()
ctx.setFillColor(paper)
ctx.fill(CGRect(x: cx - frame * 0.35, y: bottom, width: frame * 0.7, height: apex - bottom))
ctx.restoreGState()

let sillWidth = halfWidth * 2 + s * 0.09
let sill = CGRect(x: cx - sillWidth / 2, y: bottom - frame, width: sillWidth, height: frame)
ctx.addPath(CGPath(roundedRect: sill, cornerWidth: s * 0.01, cornerHeight: s * 0.01, transform: nil))
ctx.setFillColor(paper)
ctx.fillPath()

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
