import CoreGraphics
import CoreText
import ImageIO
import Foundation

// Renders App Store screenshots at 2048x2732 (12.9"/13" iPad portrait), which
// App Store Connect accepts for the 13-inch iPad slot. Same renderer as the
// iPhone set, re-tuned for the wider iPad canvas.

let W = 2048, H = 2732
let outDir = "/Users/prabrandhawa/Desktop/Randhawa/AppStore/screenshots/ipad"

let now = Date()
let cal = Calendar.current
let day = cal.ordinality(of: .day, in: .year, for: now) ?? 1
let total = cal.range(of: .day, in: .year, for: now)?.count ?? 365
let percent = Int(Double(day) / Double(total) * 100)
let remaining = total - day
let dateFmt = DateFormatter()
dateFmt.dateFormat = "EEEE, MMMM d"
let dateString = dateFmt.string(from: now)

let space = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
let white = rgb(0.97, 0.97, 0.98)
let orange = rgb(1.0, 0.584, 0.0)
let dim = rgb(0.97, 0.97, 0.98, 0.16)
let subtle = rgb(0.66, 0.66, 0.70)

func font(_ name: String, _ size: CGFloat) -> CTFont { CTFontCreateWithName(name as CFString, size, nil) }
let bold = "HelveticaNeue-Bold"
let medium = "HelveticaNeue-Medium"
let thin = "HelveticaNeue-Thin"

func line(_ s: String, _ f: CTFont, _ color: CGColor) -> CTLine {
    let attrs: [CFString: Any] = [kCTFontAttributeName: f, kCTForegroundColorAttributeName: color]
    let a = CFAttributedStringCreate(nil, s as CFString, attrs as CFDictionary)!
    return CTLineCreateWithAttributedString(a)
}
func width(_ l: CTLine) -> CGFloat { CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) }
func drawCentered(_ ctx: CGContext, _ l: CTLine, centerX: CGFloat, baselineFromTop: CGFloat) {
    ctx.textPosition = CGPoint(x: centerX - width(l) / 2, y: CGFloat(H) - baselineFromTop)
    CTLineDraw(l, ctx)
}
func drawLeft(_ ctx: CGContext, _ l: CTLine, x: CGFloat, baselineFromTop: CGFloat) {
    ctx.textPosition = CGPoint(x: x, y: CGFloat(H) - baselineFromTop)
    CTLineDraw(l, ctx)
}
func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}
func rectFromTop(x: CGFloat, topInset: CGFloat, w: CGFloat, h: CGFloat) -> CGRect {
    CGRect(x: x, y: CGFloat(H) - topInset - h, width: w, height: h)
}
func drawDots(_ ctx: CGContext, in rect: CGRect, dotScale: CGFloat,
              elapsed: CGColor, today todayColor: CGColor, remainingColor: CGColor) {
    guard total > 0, rect.width > 0, rect.height > 0 else { return }
    var bestCols = 1
    var bestCell: CGFloat = 0
    for c in 1...total {
        let rows = Int((Double(total) / Double(c)).rounded(.up))
        let cell = min(rect.width / CGFloat(c), rect.height / CGFloat(rows))
        if cell > bestCell { bestCell = cell; bestCols = c }
    }
    let rows = Int((Double(total) / Double(bestCols)).rounded(.up))
    let cell = bestCell
    let gridW = cell * CGFloat(bestCols)
    let gridH = cell * CGFloat(rows)
    let originX = rect.minX + (rect.width - gridW) / 2
    let originTop = (rect.height - gridH) / 2
    let radius = cell * dotScale / 2
    for i in 0..<total {
        let dayNum = i + 1
        let col = i % bestCols
        let row = i / bestCols
        let cx = originX + (CGFloat(col) + 0.5) * cell
        let cy = rect.maxY - (originTop + (CGFloat(row) + 0.5) * cell)
        let dot = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
        if dayNum == day { ctx.setFillColor(todayColor) }
        else if dayNum < day { ctx.setFillColor(elapsed) }
        else { ctx.setFillColor(remainingColor) }
        ctx.fillEllipse(in: dot)
    }
}
func newContext() -> CGContext {
    CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}
func backgroundGradient(_ ctx: CGContext) {
    let grad = CGGradient(colorsSpace: space,
                          colors: [rgb(0.07, 0.07, 0.08), rgb(0.02, 0.02, 0.03)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
}
func save(_ ctx: CGContext, _ name: String) {
    let img = ctx.makeImage()!
    let url = URL(fileURLWithPath: "\(outDir)/\(name)")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    _ = CGImageDestinationFinalize(dest)
    print("wrote \(name)")
}
func caption(_ ctx: CGContext, _ l1: String, _ l2: String?) {
    let f = font(bold, 150)
    drawCentered(ctx, line(l1, f, white), centerX: CGFloat(W) / 2, baselineFromTop: 400)
    if let l2 = l2 {
        drawCentered(ctx, line(l2, f, white), centerX: CGFloat(W) / 2, baselineFromTop: 580)
    }
}

// MARK: - 1: app hero
func screenshot1() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "One dot for every", "day of the year")

    let cardTop: CGFloat = 780, cardBottom: CGFloat = 230
    let cardH = CGFloat(H) - cardTop - cardBottom
    let cardX: CGFloat = 360, cardW = CGFloat(W) - cardX * 2
    let card = rectFromTop(x: cardX, topInset: cardTop, w: cardW, h: cardH)
    ctx.addPath(roundedPath(card, 150)); ctx.setFillColor(rgb(0, 0, 0)); ctx.fillPath()

    let pad: CGFloat = 110
    let inner = card.insetBy(dx: pad, dy: pad)
    let gridH = inner.height * 0.60
    let gridRect = CGRect(x: inner.minX, y: inner.maxY - gridH, width: inner.width, height: gridH)
    drawDots(ctx, in: gridRect, dotScale: 0.72, elapsed: white, today: orange, remainingColor: dim)

    let pctBaseline = cardTop + pad + gridH + 250
    drawCentered(ctx, line("\(percent)%", font(bold, 230), white), centerX: CGFloat(W) / 2, baselineFromTop: pctBaseline)
    let sub = "Day \(day) of \(total) · \(remaining) left"
    drawCentered(ctx, line(sub, font(medium, 64), subtle), centerX: CGFloat(W) / 2, baselineFromTop: pctBaseline + 110)
    save(ctx, "01-app.png")
}

// MARK: - 2: Home Screen widgets (small + medium + large, centered)
func screenshot2() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "Lives on your", "Home Screen")

    let tileRemaining = rgb(1, 1, 1, 0.22)
    func widgetTile(_ rect: CGRect) {
        ctx.addPath(roundedPath(rect, rect.width * 0.16))
        ctx.setFillColor(rgb(1, 1, 1, 0.10)); ctx.fillPath()
        let inset = rect.insetBy(dx: rect.width * 0.09, dy: rect.width * 0.09)
        drawDots(ctx, in: inset, dotScale: 0.72, elapsed: white, today: orange, remainingColor: tileRemaining)
    }
    // iPad's canvas is shorter than the phone's, so show two substantial tiles
    // (a medium 2:1 and a large square) rather than three cramped ones.
    let medW = CGFloat(W) - 720
    let medH = medW / 2.13
    let medTop: CGFloat = 820
    widgetTile(rectFromTop(x: 360, topInset: medTop, w: medW, h: medH))
    let largeSide: CGFloat = 900
    let largeTop = medTop + medH + 150
    widgetTile(rectFromTop(x: (CGFloat(W) - largeSide) / 2, topInset: largeTop, w: largeSide, h: largeSide))
    save(ctx, "02-home.png")
}

// MARK: - 3: Lock Screen
func screenshot3() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "And your", "Lock Screen")

    let cardTop: CGFloat = 800, cardBottom: CGFloat = 230
    let cardH = CGFloat(H) - cardTop - cardBottom
    let card = rectFromTop(x: 360, topInset: cardTop, w: CGFloat(W) - 720, h: cardH)
    let grad = CGGradient(colorsSpace: space, colors: [rgb(0.10, 0.11, 0.14), rgb(0.04, 0.04, 0.06)] as CFArray, locations: [0, 1])!
    ctx.saveGState(); ctx.addPath(roundedPath(card, 150)); ctx.clip()
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: card.maxY), end: CGPoint(x: 0, y: card.minY), options: [])
    ctx.restoreGState()

    let cx = CGFloat(W) / 2
    drawCentered(ctx, line(dateString, font(medium, 60), subtle), centerX: cx, baselineFromTop: cardTop + 200)
    drawCentered(ctx, line("9:41", font(thin, 360), white), centerX: cx, baselineFromTop: cardTop + 540)

    let rowTop = cardTop + 740
    let circD: CGFloat = 320
    let circ = rectFromTop(x: card.minX + 150, topInset: rowTop, w: circD, h: circD)
    ctx.addPath(CGPath(ellipseIn: circ, transform: nil)); ctx.setFillColor(rgb(1, 1, 1, 0.12)); ctx.fillPath()
    drawDots(ctx, in: circ.insetBy(dx: 40, dy: 40), dotScale: 0.62, elapsed: white, today: white, remainingColor: rgb(1, 1, 1, 0.28))

    let rectW = card.maxX - (circ.maxX + 90) - 150
    let rect = rectFromTop(x: circ.maxX + 90, topInset: rowTop + 15, w: rectW, h: circD - 30)
    let gridSquare = CGRect(x: rect.minX, y: rect.minY, width: rect.height, height: rect.height)
    drawDots(ctx, in: gridSquare, dotScale: 0.7, elapsed: white, today: white, remainingColor: rgb(1, 1, 1, 0.28))
    let textX = gridSquare.maxX + 50
    drawLeft(ctx, line("\(percent)%", font(bold, 110), white), x: textX, baselineFromTop: rowTop + 140)
    drawLeft(ctx, line("\(remaining) days left", font(medium, 56), subtle), x: textX, baselineFromTop: rowTop + 225)
    save(ctx, "03-lock.png")
}

// MARK: - 4: minimal / privacy
func screenshot4() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "Quietly minimal.", nil)
    drawCentered(ctx, line("No accounts. No tracking. No noise.", font(medium, 70), subtle),
                 centerX: CGFloat(W) / 2, baselineFromTop: 740)

    let size = CGFloat(W) - 760
    let top: CGFloat = 980
    let tile = rectFromTop(x: 380, topInset: top, w: size, h: size)
    ctx.addPath(roundedPath(tile, size * 0.14)); ctx.setFillColor(rgb(1, 1, 1, 0.06)); ctx.fillPath()
    drawDots(ctx, in: tile.insetBy(dx: size * 0.10, dy: size * 0.10), dotScale: 0.74, elapsed: white, today: orange, remainingColor: dim)

    drawCentered(ctx, line("\(percent)% of \(cal.component(.year, from: now)) complete", font(medium, 64), subtle),
                 centerX: CGFloat(W) / 2, baselineFromTop: top + size + 230)
    save(ctx, "04-privacy.png")
}

screenshot1()
screenshot2()
screenshot3()
screenshot4()
print("done iPad: \(percent)%, day \(day)/\(total)")
