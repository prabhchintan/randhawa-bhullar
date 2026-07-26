import CoreGraphics
import CoreText
import ImageIO
import Foundation

// Renders App Store screenshots at 1320x2868 (6.9" iPhone, the size App Store
// Connect requires). The app UI is deterministic CoreGraphics, so these are
// faithful to what the app actually draws, using today's real year values.

let W = 1284, H = 2778
let outDir = "/Users/prabrandhawa/Desktop/Randhawa/AppStore/screenshots"

// MARK: - Today's values (same math as the app)
let now = Date()
let cal = Calendar.current
let day = cal.ordinality(of: .day, in: .year, for: now) ?? 1
let total = cal.range(of: .day, in: .year, for: now)?.count ?? 365
let percent = Int(Double(day) / Double(total) * 100)
let remaining = total - day
let dateFmt = DateFormatter()
dateFmt.dateFormat = "EEEE, MMMM d"
let dateString = dateFmt.string(from: now)

// MARK: - Color helpers
let space = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
let white = rgb(0.97, 0.97, 0.98)
let orange = rgb(1.0, 0.584, 0.0)
let dim = rgb(0.97, 0.97, 0.98, 0.16)
let subtle = rgb(0.66, 0.66, 0.70)

// MARK: - Font + text helpers
func font(_ name: String, _ size: CGFloat) -> CTFont {
    CTFontCreateWithName(name as CFString, size, nil)
}
let bold = "HelveticaNeue-Bold"
let medium = "HelveticaNeue-Medium"
let thin = "HelveticaNeue-Thin"

func line(_ s: String, _ f: CTFont, _ color: CGColor, tracking: CGFloat = 0) -> CTLine {
    var attrs: [CFString: Any] = [kCTFontAttributeName: f, kCTForegroundColorAttributeName: color]
    if tracking != 0 { attrs[kCTKernAttributeName] = tracking as CFNumber }
    let a = CFAttributedStringCreate(nil, s as CFString, attrs as CFDictionary)!
    return CTLineCreateWithAttributedString(a)
}
func width(_ l: CTLine) -> CGFloat { CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil)) }

/// Draws a line whose baseline sits `baselineFromTop` pixels below the top edge,
/// centered on `centerX` (context is bottom-up, so we convert).
func drawCentered(_ ctx: CGContext, _ l: CTLine, centerX: CGFloat, baselineFromTop: CGFloat) {
    ctx.textPosition = CGPoint(x: centerX - width(l) / 2, y: CGFloat(H) - baselineFromTop)
    CTLineDraw(l, ctx)
}
func drawLeft(_ ctx: CGContext, _ l: CTLine, x: CGFloat, baselineFromTop: CGFloat) {
    ctx.textPosition = CGPoint(x: x, y: CGFloat(H) - baselineFromTop)
    CTLineDraw(l, ctx)
}

// MARK: - Shapes
func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// rect in context (bottom-up) coords. `topInset` = distance of rect's top edge
/// from the canvas top.
func rectFromTop(x: CGFloat, topInset: CGFloat, w: CGFloat, h: CGFloat) -> CGRect {
    CGRect(x: x, y: CGFloat(H) - topInset - h, width: w, height: h)
}

/// Draws the year's dots inside `rect`, fitting them like the app does.
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
    let originTop = (rect.height - gridH) / 2 // from rect's top edge
    let radius = cell * dotScale / 2
    for i in 0..<total {
        let dayNum = i + 1
        let col = i % bestCols
        let row = i / bestCols
        let cx = originX + (CGFloat(col) + 0.5) * cell
        let cyFromRectTop = originTop + (CGFloat(row) + 0.5) * cell
        let cy = rect.maxY - cyFromRectTop
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
    let f = font(bold, 104)
    drawCentered(ctx, line(l1, f, white), centerX: CGFloat(W) / 2, baselineFromTop: 250)
    if let l2 = l2 {
        drawCentered(ctx, line(l2, f, white), centerX: CGFloat(W) / 2, baselineFromTop: 380)
    }
}

// MARK: - Screenshot 1: app hero
func screenshot1() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "One dot for every", "day of the year")

    // Phone-like card with the actual app layout.
    let cardTop: CGFloat = 520, cardBottom: CGFloat = 150
    let cardH = CGFloat(H) - cardTop - cardBottom
    let cardX: CGFloat = 130, cardW = CGFloat(W) - cardX * 2
    let card = rectFromTop(x: cardX, topInset: cardTop, w: cardW, h: cardH)
    ctx.addPath(roundedPath(card, 120)); ctx.setFillColor(rgb(0, 0, 0)); ctx.fillPath()

    let pad: CGFloat = 90
    let inner = card.insetBy(dx: pad, dy: pad)
    // Grid in the upper ~62%.
    let gridH = inner.height * 0.60
    let gridRect = CGRect(x: inner.minX, y: inner.maxY - gridH, width: inner.width, height: gridH)
    drawDots(ctx, in: gridRect, dotScale: 0.72, elapsed: white, today: orange, remainingColor: dim)

    // "48%" + caption below the grid.
    let pctBaseline = cardTop + pad + gridH + 200
    drawCentered(ctx, line("\(percent)%", font(bold, 200), white), centerX: CGFloat(W) / 2, baselineFromTop: pctBaseline)
    let sub = "Day \(day) of \(total) · \(remaining) left"
    drawCentered(ctx, line(sub, font(medium, 54), subtle), centerX: CGFloat(W) / 2, baselineFromTop: pctBaseline + 90)

    save(ctx, "01-app.png")
}

// MARK: - Screenshot 2: Home Screen widgets
func screenshot2() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "Lives on your", "Home Screen")

    let tileRemaining = rgb(1, 1, 1, 0.22)
    func widgetTile(_ rect: CGRect) {
        ctx.addPath(roundedPath(rect, rect.width * 0.18))
        ctx.setFillColor(rgb(1, 1, 1, 0.10)); ctx.fillPath()
        let inset = rect.insetBy(dx: rect.width * 0.10, dy: rect.width * 0.10)
        drawDots(ctx, in: inset, dotScale: 0.72, elapsed: white, today: orange, remainingColor: tileRemaining)
    }

    // Small (centered), then medium and large stacked below.
    let smallSize: CGFloat = 460
    let smallTop: CGFloat = 640
    widgetTile(rectFromTop(x: (CGFloat(W) - smallSize) / 2, topInset: smallTop, w: smallSize, h: smallSize))
    // Medium (2:1) to the right won't fit beside; stack: medium below small.
    let medTop = smallTop + smallSize + 90
    let medW = CGFloat(W) - 260
    widgetTile(rectFromTop(x: 130, topInset: medTop, w: medW, h: (medW - 40) / 2.13))
    // Large below.
    let largeTop = medTop + (medW - 40) / 2.13 + 90
    let largeSize = CGFloat(W) - 260
    widgetTile(rectFromTop(x: 130, topInset: largeTop, w: largeSize, h: min(largeSize, CGFloat(H) - largeTop - 150)))

    save(ctx, "02-home.png")
}

// MARK: - Screenshot 3: Lock Screen widgets
func screenshot3() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "And your", "Lock Screen")

    // Faux lock screen: clock + date, then accessory widgets beneath.
    let cardTop: CGFloat = 560, cardBottom: CGFloat = 150
    let cardH = CGFloat(H) - cardTop - cardBottom
    let card = rectFromTop(x: 130, topInset: cardTop, w: CGFloat(W) - 260, h: cardH)
    ctx.addPath(roundedPath(card, 120))
    let grad = CGGradient(colorsSpace: space, colors: [rgb(0.10, 0.11, 0.14), rgb(0.04, 0.04, 0.06)] as CFArray, locations: [0, 1])!
    ctx.saveGState(); ctx.addPath(roundedPath(card, 120)); ctx.clip()
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: card.maxY), end: CGPoint(x: 0, y: card.minY), options: [])
    ctx.restoreGState()

    let cx = CGFloat(W) / 2
    drawCentered(ctx, line(dateString, font(medium, 46), subtle), centerX: cx, baselineFromTop: cardTop + 150)
    drawCentered(ctx, line("9:41", font(thin, 300), white), centerX: cx, baselineFromTop: cardTop + 420)

    // Accessory row: circular + rectangular (monochrome).
    let rowTop = cardTop + 560
    let circD: CGFloat = 280
    let circ = rectFromTop(x: card.minX + 90, topInset: rowTop, w: circD, h: circD)
    ctx.addPath(CGPath(ellipseIn: circ, transform: nil)); ctx.setFillColor(rgb(1, 1, 1, 0.12)); ctx.fillPath()
    drawDots(ctx, in: circ.insetBy(dx: 34, dy: 34), dotScale: 0.62, elapsed: white, today: white, remainingColor: rgb(1, 1, 1, 0.28))

    // Rectangular accessory: small grid + text.
    let rectW = card.maxX - (circ.maxX + 70) - 90
    let rect = rectFromTop(x: circ.maxX + 70, topInset: rowTop + 10, w: rectW, h: circD - 20)
    let gridSquare = CGRect(x: rect.minX, y: rect.minY, width: rect.height, height: rect.height)
    drawDots(ctx, in: gridSquare, dotScale: 0.7, elapsed: white, today: white, remainingColor: rgb(1, 1, 1, 0.28))
    let textX = gridSquare.maxX + 36
    drawLeft(ctx, line("\(percent)%", font(bold, 88), white), x: textX, baselineFromTop: rowTop + 110)
    drawLeft(ctx, line("\(remaining) days left", font(medium, 44), subtle), x: textX, baselineFromTop: rowTop + 175)

    save(ctx, "03-lock.png")
}

// MARK: - Screenshot 4: privacy / minimal
func screenshot4() {
    let ctx = newContext()
    backgroundGradient(ctx)
    caption(ctx, "Quietly minimal.", nil)
    drawCentered(ctx, line("No accounts. No tracking. No noise.", font(medium, 52), subtle),
                 centerX: CGFloat(W) / 2, baselineFromTop: 470)

    // One large tile, centered.
    let size = CGFloat(W) - 360
    let top: CGFloat = 720
    let tile = rectFromTop(x: 180, topInset: top, w: size, h: size)
    ctx.addPath(roundedPath(tile, size * 0.16)); ctx.setFillColor(rgb(1, 1, 1, 0.06)); ctx.fillPath()
    drawDots(ctx, in: tile.insetBy(dx: size * 0.10, dy: size * 0.10), dotScale: 0.74, elapsed: white, today: orange, remainingColor: dim)

    drawCentered(ctx, line("\(percent)% of \(cal.component(.year, from: now)) complete", font(medium, 50), subtle),
                 centerX: CGFloat(W) / 2, baselineFromTop: top + size + 180)

    save(ctx, "04-privacy.png")
}

screenshot1()
screenshot2()
screenshot3()
screenshot4()
print("done: \(percent)%, day \(day)/\(total), \(remaining) left")
