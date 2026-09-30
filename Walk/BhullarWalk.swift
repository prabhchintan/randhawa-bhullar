import XCTest

// Bhullar's walk: a memory written through the plus and opened, the five
// scales by swiping, today's gold dot opened at the day scale, and the list
// of memories. Bhullar has no menu; its one other control, the envelope,
// leaves for Mail, so the walk does not follow it.
final class BhullarWalk: Eyes {
    func testWalk() throws {
        app.launch()
        let grid = app.descendants(matching: .any).matching(identifier: "grid").firstMatch
        guard grid.waitForExistence(timeout: 10) else {
            see("no-grid")
            note("the grid never came")
            return
        }

        if remember("The walk, looking") {
            pause(1)
            see("memory")
            done()
        }

        // Coarsest first: swipe back to months, then forward through each.
        for _ in 0..<5 where !scale(of: grid).hasPrefix("Month") {
            app.swipeRight()
            pause(0.6)
        }
        for name in ["months", "weeks", "days", "hours", "minutes"] {
            see(name)
            if name == "days" { openToday(grid) }
            app.swipeLeft()
            pause(0.6)
        }

        let memories = app.buttons["memories"]
        if memories.waitForExistence(timeout: 3) {
            memories.tap()
            pause(1)
            see("memories")
            done()
        } else {
            note("no memories button")
        }
    }

    private func scale(of grid: XCUIElement) -> String {
        (grid.value as? String) ?? ""
    }

    /// Taps today's dot, gold since the memory above, where DotGrid draws it:
    /// the same packing, read from the grid's own value ("Day 273 of 365").
    private func openToday(_ grid: XCUIElement) {
        let words = scale(of: grid).split(separator: " ")
        guard words.count >= 4, let index = Int(words[1]),
              let total = Int(words[3].trimmingCharacters(in: .punctuationCharacters)) else {
            note("could not read the grid: \(scale(of: grid))")
            return
        }
        let size = grid.frame.size
        var columns = 1
        var cell: CGFloat = 0
        for candidate in 1...total {
            let rows = Int((Double(total) / Double(candidate)).rounded(.up))
            let fit = min(size.width / CGFloat(candidate), size.height / CGFloat(rows))
            if fit > cell { cell = fit; columns = candidate }
        }
        let rows = Int((Double(total) / Double(columns)).rounded(.up))
        let x = (size.width - cell * CGFloat(columns)) / 2 + (CGFloat((index - 1) % columns) + 0.5) * cell
        let y = (size.height - cell * CGFloat(rows)) / 2 + (CGFloat((index - 1) / columns) + 0.5) * cell
        grid.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
        pause(1)
        see("day")
        done()
    }
}
