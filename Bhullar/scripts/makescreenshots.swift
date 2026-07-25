import CoreGraphics
import CoreText
import ImageIO
import Foundation

// Renders Bhullar's App Store screenshots at both required sizes: iPhone 6.7"
// (1284x2778) and iPad 13" (2048x2732). Grids use today's real values, drawn
// with the same packing algorithm as the app.

let space = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
let white = rgb(0.97, 0.97, 0.98)
let orange = rgb(1.0, 0.584, 0.0)
let gold = rgb(1.0, 0.83, 0.25)
let dim = rgb(0.97, 0.97, 0.98, 0.16)
let subtle = rgb(0.66, 0.66, 0.70)

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

// Today's real values, same math as the app.
let now = Date()
let cal = Calendar.current
func position(_ unit: Calendar.Component, in span: Calendar.Component, fallback: Int) -> (Int, Int) {
    let ordinal = cal.ordinality(of: unit, in: span, for: now) ?? 1
    let total = cal.range(of: unit, in: span, for: now)?.count ?? fallback
    return (min(max(ordinal, 1), max(total, 1)), max(total, 1))
}
let (monthIdx, monthTotal) = position(.month, in: .year, fallback: 12)
let (weekIdx, weekTotal) = position(.weekOfYear, in: .year, fallback: 52)
let (dayIdx, dayTotal) = position(.day, in: .year, fallback: 365)
let (hourIdx, hourTotal) = position(.hour, in: .day, fallback: 24)
let dayPercent = Int(Double(dayIdx) / Double(dayTotal) * 100)

func render(W: Int, H: Int, outDir: String) {
    let s = CGFloat(W) / 1284.0

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

    /// Draws `total` dots (current one orange, elapsed filled, units in
    /// `highlighted` gold, the way memory days render) packed into rect.
    func drawDots(_ ctx: CGContext, in rect: CGRect, current: Int, total: Int,
                  dotScale: CGFloat, elapsedColor: CGColor, remainingColor: CGColor,
                  highlighted: Set<Int> = []) {
        guard total > 0, rect.width > 0, rect.height > 0 else { return }
        var bestCols = 1
        var bestCell: CGFloat = 0
        for c in 1...total {
            let rows = Int((Double(total) / Double(c)).rounded(.up))
            let cell = min(rect.width / CGFloat(c), rect.height / CGFloat(rows))
            if cell > bestCell { bestCell = cell; bestCols = c }
        }
        let cell = bestCell
        let rows = Int((Double(total) / Double(bestCols)).rounded(.up))
        let gridW = cell * CGFloat(bestCols)
        let gridH = cell * CGFloat(rows)
        let originX = rect.minX + (rect.width - gridW) / 2
        let originTop = (rect.height - gridH) / 2
        let radius = cell * dotScale / 2
        for i in 0..<total {
            let unit = i + 1
            let col = i % bestCols
            let row = i / bestCols
            let cx = originX + (CGFloat(col) + 0.5) * cell
            let cy = rect.maxY - (originTop + (CGFloat(row) + 0.5) * cell)
            let dot = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
            if unit == current { ctx.setFillColor(orange) }
            else if highlighted.contains(unit) { ctx.setFillColor(gold) }
            else if unit < current { ctx.setFillColor(elapsedColor) }
            else { ctx.setFillColor(remainingColor) }
            ctx.fillEllipse(in: dot)
        }
    }

    // Shot 1: hero, the day-of-year grid, the app's classic face.
    func shot1() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "A telescope", "for time")

        let cardTop = CGFloat(H) * 0.187
        let cardBottom = CGFloat(H) * 0.054
        let cardX = CGFloat(W) * 0.10
        let cardW = CGFloat(W) - cardX * 2
        let cardH = CGFloat(H) - cardTop - cardBottom
        let card = rectFromTop(x: cardX, topInset: cardTop, w: cardW, h: cardH)
        ctx.addPath(roundedPath(card, 120 * s)); ctx.setFillColor(rgb(0, 0, 0)); ctx.fillPath()

        let pad = cardW * 0.08
        let gridH = cardH * 0.58
        let gridRect = CGRect(x: card.minX + pad, y: card.maxY - cardH * 0.06 - gridH,
                              width: cardW - pad * 2, height: gridH)
        drawDots(ctx, in: gridRect, current: dayIdx, total: dayTotal,
                 dotScale: 0.72, elapsedColor: white, remainingColor: dim)

        let pctBaseline = cardTop + cardH * 0.06 + gridH + 200 * s
        drawCentered(ctx, line("\(dayPercent)%", font(bold, 200 * s), white),
                     centerX: CGFloat(W) / 2, baselineFromTop: pctBaseline)
        drawCentered(ctx, line("Day \(dayIdx) of \(dayTotal) · \(dayTotal - dayIdx) left", font(medium, 54 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: pctBaseline + 90 * s)
        drawCentered(ctx, line("tap the dots to zoom", font(medium, 44 * s), rgb(0.45, 0.45, 0.5)),
                     centerX: CGFloat(W) / 2, baselineFromTop: pctBaseline + 160 * s)
        save(ctx, "01-app.png")
    }

    // Shot 2: the four scales, 2x2.
    func shot2() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "Months, weeks,", "days, hours")

        let tileSize = CGFloat(W) * 0.38
        let gap = CGFloat(W) * 0.06
        let leftX = (CGFloat(W) - tileSize * 2 - gap) / 2
        let topRow = CGFloat(H) * 0.24
        let rowGap = tileSize + 170 * s

        func tile(_ x: CGFloat, _ top: CGFloat, current: Int, total: Int, label: String) {
            let r = rectFromTop(x: x, topInset: top, w: tileSize, h: tileSize)
            ctx.addPath(roundedPath(r, tileSize * 0.16))
            ctx.setFillColor(rgb(1, 1, 1, 0.08)); ctx.fillPath()
            drawDots(ctx, in: r.insetBy(dx: tileSize * 0.11, dy: tileSize * 0.11),
                     current: current, total: total, dotScale: 0.7,
                     elapsedColor: white, remainingColor: rgb(1, 1, 1, 0.22))
            drawCentered(ctx, line(label, font(medium, 46 * s), subtle),
                         centerX: x + tileSize / 2, baselineFromTop: top + tileSize + 72 * s)
        }

        tile(leftX, topRow, current: monthIdx, total: monthTotal, label: "\(monthTotal) months")
        tile(leftX + tileSize + gap, topRow, current: weekIdx, total: weekTotal, label: "\(weekTotal) weeks")
        tile(leftX, topRow + rowGap, current: dayIdx, total: dayTotal, label: "\(dayTotal) days")
        tile(leftX + tileSize + gap, topRow + rowGap, current: hourIdx, total: hourTotal, label: "\(hourTotal) hours")

        drawCentered(ctx, line("One grid. Tap to zoom.", font(medium, 50 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: topRow + rowGap + tileSize + 170 * s)
        save(ctx, "02-scales.png")
    }

    // Shot 3: the widgets.
    func shot3() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "Widgets at", "every scale")

        let tileSize = CGFloat(W) * 0.38
        let gap = CGFloat(W) * 0.06
        let leftX = (CGFloat(W) - tileSize * 2 - gap) / 2
        let topRow = CGFloat(H) * 0.25

        func widgetTile(_ x: CGFloat, _ top: CGFloat, current: Int, total: Int, label: String) {
            let r = rectFromTop(x: x, topInset: top, w: tileSize, h: tileSize)
            ctx.addPath(roundedPath(r, tileSize * 0.18))
            ctx.setFillColor(rgb(1, 1, 1, 0.10)); ctx.fillPath()
            drawDots(ctx, in: r.insetBy(dx: tileSize * 0.10, dy: tileSize * 0.10),
                     current: current, total: total, dotScale: 0.72,
                     elapsedColor: white, remainingColor: rgb(1, 1, 1, 0.22))
            drawCentered(ctx, line(label, font(medium, 46 * s), subtle),
                         centerX: x + tileSize / 2, baselineFromTop: top + tileSize + 72 * s)
        }

        widgetTile(leftX, topRow, current: dayIdx, total: dayTotal, label: "Year in Dots")
        widgetTile(leftX + tileSize + gap, topRow, current: hourIdx, total: hourTotal, label: "Day in Dots")

        // The configurable widget below, with the year grid.
        let medW = CGFloat(W) * 0.80
        let medH = medW / 2.13
        let medTop = topRow + tileSize + 190 * s
        let med = rectFromTop(x: CGFloat(W) * 0.10, topInset: medTop, w: medW, h: medH)
        ctx.addPath(roundedPath(med, medH * 0.20))
        ctx.setFillColor(rgb(1, 1, 1, 0.10)); ctx.fillPath()
        drawDots(ctx, in: med.insetBy(dx: medW * 0.06, dy: medH * 0.10),
                 current: dayIdx, total: dayTotal, dotScale: 0.72,
                 elapsedColor: white, remainingColor: rgb(1, 1, 1, 0.22))
        drawCentered(ctx, line("Dots at Any Scale", font(medium, 46 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: medTop + medH + 72 * s)

        drawCentered(ctx, line("Lock Screen sizes included.", font(medium, 50 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: medTop + medH + 190 * s)
        save(ctx, "03-widgets.png")
    }

    // Shot 4: memories, the 2.0 headline.
    func shot4() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "Memories return", "on their day")
        let subBase = CGFloat(H) * 0.090 + 235 * s
        drawCentered(ctx, line("Write it down today; its day glows gold.", font(medium, 48 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase)
        drawCentered(ctx, line("Made in Randhawa, they show up here too.", font(medium, 48 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase + 72 * s)

        let size = CGFloat(W) * 0.76
        let top = CGFloat(H) * 0.295
        let tileRect = rectFromTop(x: (CGFloat(W) - size) / 2, topInset: top, w: size, h: size)
        ctx.addPath(roundedPath(tileRect, size * 0.14)); ctx.setFillColor(rgb(1, 1, 1, 0.07)); ctx.fillPath()
        let memoryDays = Set([dayIdx - 12, dayIdx - 47, dayIdx - 101, dayIdx - 163].filter { $0 >= 1 })
        drawDots(ctx, in: tileRect.insetBy(dx: size * 0.09, dy: size * 0.09),
                 current: dayIdx, total: dayTotal, dotScale: 0.74,
                 elapsedColor: white, remainingColor: dim, highlighted: memoryDays)

        // The on-this-day line, the way the app shows it under the caption.
        let pillText = "2 memories on this day"
        let pl = line(pillText, font(medium, 48 * s), gold)
        let pw = width(pl) + 96 * s
        let ph = 104 * s
        let pillTop = top + size + 110 * s
        let pillRect = rectFromTop(x: (CGFloat(W) - pw) / 2, topInset: pillTop, w: pw, h: ph)
        ctx.addPath(roundedPath(pillRect, ph / 2))
        ctx.setFillColor(rgb(1, 1, 1, 0.08)); ctx.fillPath()
        drawCentered(ctx, line(pillText, font(medium, 48 * s), gold),
                     centerX: CGFloat(W) / 2, baselineFromTop: pillTop + ph * 0.66)
        save(ctx, "04-memories.png")
    }

    // Shot 5: the honesty/privacy card.
    func shot5() {
        let ctx = newContext()
        backgroundGradient(ctx)
        caption(ctx, "No accounts.", "No sign-up.")
        let subBase = CGFloat(H) * 0.090 + 235 * s
        drawCentered(ctx, line("The grid is computed from today's date.", font(medium, 50 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase)
        drawCentered(ctx, line("Memories sync only to your own private iCloud, if you choose.", font(medium, 42 * s), rgb(0.5, 0.5, 0.55)),
                     centerX: CGFloat(W) / 2, baselineFromTop: subBase + 78 * s)

        let size = CGFloat(W) * 0.72
        let top = CGFloat(H) * 0.30
        let tileRect = rectFromTop(x: (CGFloat(W) - size) / 2, topInset: top, w: size, h: size)
        ctx.addPath(roundedPath(tileRect, size * 0.16)); ctx.setFillColor(rgb(1, 1, 1, 0.06)); ctx.fillPath()
        drawDots(ctx, in: tileRect.insetBy(dx: size * 0.10, dy: size * 0.10),
                 current: dayIdx, total: dayTotal, dotScale: 0.74,
                 elapsedColor: white, remainingColor: dim)
        drawCentered(ctx, line("\(dayPercent)% of \(cal.component(.year, from: now)) complete", font(medium, 50 * s), subtle),
                     centerX: CGFloat(W) / 2, baselineFromTop: top + size + 150 * s)
        save(ctx, "05-privacy.png")
    }

    shot1(); shot2(); shot3(); shot4(); shot5()
}

render(W: 1284, H: 2778, outDir: "/Users/prabrandhawa/Desktop/Randhawa/Bhullar/AppStore/screenshots")
render(W: 2048, H: 2732, outDir: "/Users/prabrandhawa/Desktop/Randhawa/Bhullar/AppStore/screenshots/ipad")
print("done")
