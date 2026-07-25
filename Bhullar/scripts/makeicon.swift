import CoreGraphics
import ImageIO
import Foundation

// Composites the Bhullar brand mark (dark calligraphy, from Bhullar.png at the
// project root) onto an opaque cream ground at 1024x1024; App Store icons
// must be exactly 1024x1024 with no alpha. The pairing is deliberate: Randhawa
// is cream ink on deep green; Bhullar is dark ink on cream paper.
let size = 1024
let srcPath = "/Users/prabrandhawa/Desktop/Randhawa/Bhullar/Bhullar.png"
let outPath = "/Users/prabrandhawa/Desktop/Randhawa/Bhullar/Bhullar/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: srcPath) as CFURL, nil),
      let art = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    fatalError("cannot read \(srcPath)")
}

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("no context") }

// Warm paper cream.
ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0.956, 0.945, 0.915, 1])!)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Fit the art into a centered box with generous margins.
let artW = CGFloat(art.width)
let artH = CGFloat(art.height)
let box = CGFloat(size) * 0.70
let scale = Swift.min(box / artW, box / artH)
let drawW = artW * scale
let drawH = artH * scale
let rect = CGRect(
    x: (CGFloat(size) - drawW) / 2,
    y: (CGFloat(size) - drawH) / 2,
    width: drawW,
    height: drawH
)
// Thicken the calligraphy: stamping the art repeatedly around small circular
// offsets dilates the strokes (union of overlapping ink) without touching the
// letterforms. R is the added half-thickness in icon pixels.
let R: CGFloat = 5.5
ctx.interpolationQuality = .high
for i in 0..<16 {
    let a = CGFloat(i) * 2 * CGFloat.pi / 16
    ctx.draw(art, in: rect.offsetBy(dx: cos(a) * R, dy: sin(a) * R))
}
for i in 0..<8 {
    let a = CGFloat(i) * 2 * CGFloat.pi / 8
    ctx.draw(art, in: rect.offsetBy(dx: cos(a) * R / 2, dy: sin(a) * R / 2))
}
ctx.draw(art, in: rect)

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
