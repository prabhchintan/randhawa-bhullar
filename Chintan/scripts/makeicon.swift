import CoreGraphics
import ImageIO
import Foundation

// A quiet icon for a private app: one warm dot, off-center, on near-black
// ground. No mark, no wordplay, nothing to notice twice. App Store icons
// must be exactly 1024x1024 with no alpha channel.
let size = 1024
// Run from the Chintan directory: swift scripts/makeicon.swift
let outPath = "Chintan/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

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

ctx.setFillColor(color(0.043, 0.043, 0.047))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let dot = color(0.204, 0.408, 0.541)
let cx = CGFloat(size) * 0.5
let cy = CGFloat(size) * 0.5
let radius = CGFloat(size) * 0.12
ctx.setFillColor(dot)
ctx.fillEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))

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
