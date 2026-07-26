import CoreGraphics
import CoreText
import ImageIO
import Foundation

// Renders the v3.0 (space app) App Store screenshots at both required sizes:
// iPhone 6.7" (1284x2778) and iPad 13" (2048x2732). All visuals are the app's
// real constellation language drawn deterministically, no fake map tiles.

let space = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
let white = rgb(0.97, 0.97, 0.98)
let orange = rgb(1.0, 0.584, 0.0)
let gold = rgb(1.0, 0.83, 0.25)
let subtle = rgb(0.66, 0.66, 0.70)
let dotWhite = rgb(0.97, 0.97, 0.98, 0.30)

let bold = "HelveticaNeue-Bold"
let medium = "HelveticaNeue-Medium"

func font(_ name: String, _ size: CGFloat) -> CTFont {
    CTFontCreateWithName(name as CFString, size, nil)
}
func line(_ s: String, _ f: CTFont, _ color: CGColor) -> CTLine {
    let attrs: [CFString: Any] = [kCTFontAttributeName: f, kCTForegroundColorAttributeName: color]
    let a = CFAttributedStringCreate(nil, s as CFString, attrs as CFDictionary)!
    return CTLineCreateWithAttributedString(a)
}
func width(_ l: CTLine) -> CGFloat { CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) }

// Hand-placed constellation in unit space (y down): a dense home cluster, a
// second hub, a small third, a strand between, and far travels. Same
// composition family as the in-app demo data and the alternate icon.
let clusterA: [(CGFloat, CGFloat)] = [
    (0.335, 0.415), (0.365, 0.435), (0.350, 0.455), (0.380, 0.410),
    (0.325, 0.440), (0.360, 0.470), (0.390, 0.445), (0.340, 0.395),
    (0.375, 0.480), (0.315, 0.470), (0.355, 0.425), (0.370, 0.450),
]
let clusterB: [(CGFloat, CGFloat)] = [
    (0.645, 0.655), (0.670, 0.675), (0.655, 0.700), (0.680, 0.645), (0.662, 0.663),
]
let clusterC: [(CGFloat, CGFloat)] = [
    (0.755, 0.295), (0.770, 0.315), (0.788, 0.300),
]
let strand: [(CGFloat, CGFloat)] = [
    (0.455, 0.520), (0.535, 0.575), (0.590, 0.620), (0.620, 0.640),
]
let scatter: [(CGFloat, CGFloat)] = [
    (0.215, 0.700), (0.280, 0.215), (0.720, 0.845), (0.165, 0.360),
    (0.825, 0.520), (0.505, 0.185), (0.860, 0.760), (0.130, 0.560),
]
let allDots = clusterA + clusterB + clusterC + strand + scatter
let latestDot: (CGFloat, CGFloat) = (0.410, 0.500)

func render(W: Int, H: Int, outDir: String) {
    let s = CGFloat(W) / 1284.0 // font/size scale relative to the iPhone canvas

    func newContext() -> CGContext {
        CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    }
    func rectFromTop(x: CGFloat, topInset: CGFloat, w: CGFloat, h: CGFloat) -> CGRect {
        CGRect(x: x, y: CGFloat(H) - topInset - h, width: w, height: h)
    }
    func drawCentered(_ ctx: CGContext, _ l: CTLine, centerX: CGFloat, baselineFromTop: CGFloat) {
        ctx.textPosition = CGPoint(x: centerX - width(l) / 2, y: CGFloat(H) - baselineFromTop)
        CTLineDraw(l, ctx)
    }
    func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
    func backgroundGradient(_ ctx: CGContext) {
        let grad = CGGradient(colorsSpace: space,
                              colors: [rgb(0.07, 0.07, 0.08), rgb(0.02, 0.02, 0.03)] as CFArray,
                              locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: 0, y: 0), options: [])
    }
    func save(_ ctx: CGContext, _ name: String) {
        let img = ctx.makeImage()!
        let url = URL(fileURLWithPath: "\(outDir)/\(name)")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        _ = CGImageDestinationFinalize(dest)
        print("wrote \(outDir)/\(name)")
    }
    func caption(_ ctx: CGContext, _ l1: String, _ l2: String?) {
        let f = font(bold, 104 * s)
        let base1 = CGFloat(H) * 0.090
        drawCentered(ctx, line(l1, f, white), centerX: CGFloat(W) / 2, baselineFromTop: base1)
        if let l2 = l2 {
            drawCentered(ctx, line(l2, f, white), centerX: CGFloat(W) / 2, baselineFromTop: base1 + 130 * s)
        }
    }

    /// Draws dots (unit coords, y down) into `rect`. Latest is orange, on top.
    func drawConstellation(_ ctx: CGContext, in rect: CGRect,
                           dots: [(CGFloat, CGFloat)], latest: (CGFloat, CGFloat)?,
                           dotRadius: CGFloat, ringLatest: Bool = false) {
        for (ux, uy) in dots {
            let cx = rect.minX + ux * rect.width
            let cy = rect.maxY - uy * rect.height
            ctx.setFillColor(dotWhite)
            ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: cy - dotRadius,
                                       width: dotRadius * 2, height: dotRadius * 2))
        }
        if let (ux, uy) = latest {
            let cx = rect.minX + ux * rect.width
            let cy = rect.maxY - uy * rect.height
            let r = dotRadius * 1.15
            ctx.setFillColor(orange)
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            if ringLatest {
                ctx.setStrokeColor(white)
                ctx.setLineWidth(4 * s)
                let rr = r * 1.9
                ctx.strokeEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2))
            }
        }
    }

    func pill(_ ctx: CGContext, text: String, centerX: CGFloat, baselineFromTop: CGFloat) {
        let l = line(text, font(medium, 48 * s), subtle)
        let w = width(l) + 84 * s
        let h = 96 * s
        let rect = rectFromTop(x: centerX - w / 2, topInset: baselineFromTop - 66 * s, w: w, h: h)
        ctx.addPath(roundedPath(rect, h / 2))
        ctx.setFillColor(rgb(1, 1, 1, 0.08))
        ctx.fillPath()
        drawCentered(ctx, l, centerX: centerX, baselineFromTop: baselineFromTop)
    }

    // Shot 1: hero, the constellation in a phone-like card.
    func shot1() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "A map only", "you can read")

        let cardTop = CGFloat(H) * 0.187
        let cardBottom = CGFloat(H) * 0.054
        let cardX = CGFloat(W) * 0.10
        let cardW = CGFloat(W) - cardX * 2
        let cardH = CGFloat(H) - cardTop - cardBottom
        let card = rectFromTop(x: cardX, topInset: cardTop, w: cardW, h: cardH)
        ctx.addPath(roundedPath(card, 120 * s)); ctx.setFillColor(rgb(0, 0, 0)); ctx.fillPath()

        let field = card.insetBy(dx: cardW * 0.07, dy: cardH * 0.06)
        let fieldTopPortion = CGRect(x: field.minX, y: field.minY + field.height * 0.14,
                                     width: field.width, height: field.height * 0.86)
        drawConstellation(ctx, in: fieldTopPortion, dots: allDots, latest: latestDot, dotRadius: 20 * s)

        pill(ctx, text: "128 moments · 14 places", centerX: CGFloat(W) / 2,
             baselineFromTop: cardTop + cardH - 110 * s)
        save(ctx, "01-app.png")
    }

    // Renormalizes a dot set (plus the latest dot) to fill unit space with
    // `pad` margins, preserving aspect via uniform scale.
    func normalized(_ dots: [(CGFloat, CGFloat)], latest: (CGFloat, CGFloat),
                    pad: CGFloat) -> ([(CGFloat, CGFloat)], (CGFloat, CGFloat)) {
        let all = dots + [latest]
        var minX = all[0].0, maxX = all[0].0, minY = all[0].1, maxY = all[0].1
        for (x, y) in all {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
        let span = Swift.max(maxX - minX, maxY - minY, 0.0001)
        let scale = (1 - 2 * pad) / span
        let offX = (1 - (maxX - minX) * scale) / 2
        let offY = (1 - (maxY - minY) * scale) / 2
        func map(_ p: (CGFloat, CGFloat)) -> (CGFloat, CGFloat) {
            (offX + (p.0 - minX) * scale, offY + (p.1 - minY) * scale)
        }
        return (dots.map(map), map(latest))
    }

    // Shot 2: the mechanic. Each open drops a dot.
    func shot2() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "Each open marks", "where you are")
        let subBase = CGFloat(H) * 0.090 + 235 * s
        drawCentered(ctx, line("Read only while the app is open,", font(medium, 46 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase)
        drawCentered(ctx, line("never in the background.", font(medium, 46 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase + 72 * s)

        let fieldTop = CGFloat(H) * 0.30
        let field = rectFromTop(x: CGFloat(W) * 0.14, topInset: fieldTop,
                                w: CGFloat(W) * 0.72, h: CGFloat(H) - fieldTop - CGFloat(H) * 0.10)
        let (zoomDots, zoomLatest) = normalized(clusterA + strand, latest: latestDot, pad: 0.08)
        drawConstellation(ctx, in: field, dots: zoomDots, latest: zoomLatest,
                          dotRadius: 34 * s, ringLatest: true)
        save(ctx, "02-open.png")
    }

    /// Gold memory dots with a white ring, drawn over the constellation.
    func drawMemories(_ ctx: CGContext, in rect: CGRect,
                      dots: [(CGFloat, CGFloat)], dotRadius: CGFloat) {
        for (ux, uy) in dots {
            let cx = rect.minX + ux * rect.width
            let cy = rect.maxY - uy * rect.height
            ctx.setFillColor(gold)
            ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: cy - dotRadius,
                                       width: dotRadius * 2, height: dotRadius * 2))
            ctx.setStrokeColor(white)
            ctx.setLineWidth(3.5 * s)
            let rr = dotRadius * 1.45
            ctx.strokeEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2))
        }
    }

    // Shot 3: memories, the 3.0 headline.
    func shot3() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "Pin memories", "to your places")
        let subBase = CGFloat(H) * 0.090 + 235 * s
        drawCentered(ctx, line("A thought, a photo, in gold on your map.", font(medium, 48 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase)
        drawCentered(ctx, line("Made here, they return in Bhullar on their day.", font(medium, 48 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase + 72 * s)

        let fieldTop = CGFloat(H) * 0.285
        let fieldH = CGFloat(H) * 0.44
        let field = rectFromTop(x: CGFloat(W) * 0.12, topInset: fieldTop,
                                w: CGFloat(W) * 0.76, h: fieldH)
        drawConstellation(ctx, in: field, dots: allDots, latest: latestDot, dotRadius: 20 * s)
        let memoryDots: [(CGFloat, CGFloat)] = [(0.350, 0.455), (0.590, 0.620), (0.280, 0.215)]
        drawMemories(ctx, in: field, dots: memoryDots, dotRadius: 22 * s)

        // A note card, the way a saved memory reads.
        let cardW = CGFloat(W) * 0.76
        let cardH = 330 * s
        let cardTop = fieldTop + fieldH + 90 * s
        let card = rectFromTop(x: (CGFloat(W) - cardW) / 2, topInset: cardTop, w: cardW, h: cardH)
        ctx.addPath(roundedPath(card, 56 * s)); ctx.setFillColor(rgb(1, 1, 1, 0.09)); ctx.fillPath()
        let dotR = 16 * s
        let dotCX = card.minX + 76 * s
        let dotCY = card.maxY - 96 * s
        ctx.setFillColor(gold)
        ctx.fillEllipse(in: CGRect(x: dotCX - dotR, y: dotCY - dotR, width: dotR * 2, height: dotR * 2))
        let textX = card.minX + 132 * s
        ctx.textPosition = CGPoint(x: textX, y: CGFloat(H) - (cardTop + 116 * s))
        CTLineDraw(line("First morning in the new place", font(medium, 52 * s), white), ctx)
        ctx.textPosition = CGPoint(x: textX, y: CGFloat(H) - (cardTop + 196 * s))
        CTLineDraw(line("Jul 25 · Austin, TX", font(medium, 44 * s), subtle), ctx)
        ctx.textPosition = CGPoint(x: textX, y: CGFloat(H) - (cardTop + 278 * s))
        CTLineDraw(line("Back on this day, every year", font(medium, 40 * s), rgb(0.5, 0.5, 0.55)), ctx)
        save(ctx, "03-memories.png")
    }

    // Shot 4: privacy, now with the iCloud story told straight.
    func shot4() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "Private by", "architecture")
        let subBase = CGFloat(H) * 0.090 + 235 * s
        drawCentered(ctx, line("No accounts. No tracking. No servers of ours.", font(medium, 50 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase)
        drawCentered(ctx, line("Optional sync to your private iCloud, invisible to us.", font(medium, 46 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase + 78 * s)

        let size = CGFloat(W) * 0.72
        let top = CGFloat(H) * 0.30
        let tileRect = rectFromTop(x: (CGFloat(W) - size) / 2, topInset: top, w: size, h: size)
        ctx.addPath(roundedPath(tileRect, size * 0.16)); ctx.setFillColor(rgb(1, 1, 1, 0.06)); ctx.fillPath()
        drawConstellation(ctx, in: tileRect.insetBy(dx: size * 0.10, dy: size * 0.10),
                          dots: allDots, latest: latestDot, dotRadius: 16 * s)
        drawCentered(ctx, line("Your map, on every phone you will ever own.",
                               font(medium, 48 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: top + size + 150 * s)
        save(ctx, "04-privacy.png")
    }

    shot1(); shot2(); shot3(); shot4()
}

// Run from the repo root: swift scripts/makescreenshots_v2.swift
render(W: 1284, H: 2778, outDir: "AppStore/screenshots")
render(W: 2048, H: 2732, outDir: "AppStore/screenshots/ipad")
print("done")
