import XCTest

// Randhawa's walk: the intro on a fresh install, the map, the menu, the
// trail screen, and a memory written through the plus and opened.
final class RandhawaWalk: Eyes {
    func testWalk() throws {
        app.launch()

        // A fresh install opens on the intro, and Begin hands over to iOS's
        // own question, answered While Using.
        let begin = app.buttons["Begin"]
        if begin.waitForExistence(timeout: 5) {
            see("intro")
            begin.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allow = springboard.buttons["Allow While Using App"]
            if allow.waitForExistence(timeout: 10) {
                allow.tap()
            } else {
                note("iOS did not ask about location")
            }
        }

        let menu = app.buttons["menu"]
        guard menu.waitForExistence(timeout: 15) else {
            see("no-map")
            note("the map never came")
            return
        }
        pause(4) // the first dot, and the basemap under it
        see("map")

        // The menu does not always open to a plain synthesized tap over the
        // map; a tap at its centre, then a press, are the fallbacks.
        let trail = labelled("Trail:")
        menu.tap()
        if !trail.waitForExistence(timeout: 3) {
            menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        if !trail.waitForExistence(timeout: 3) { menu.press(forDuration: 0.8) }
        see("menu")
        if trail.waitForExistence(timeout: 3) {
            trail.tap()
            pause(1)
            see("trail")
            done()
        } else {
            note("no trail item in the menu")
            app.swipeDown()
        }

        if remember("The walk, looking") {
            pause(1)
            see("memory")
            done()
        }
    }
}
