import XCTest

// The walk: the house's eyes for motion. One scripted pass through the app
// the way a hand would take it: swipe between tabs, scroll each shelf, open
// a leaf, press and hold, type a word in a room, turn the phone dark. Every
// state it passes through is photographed, and every gesture is written to
// a log with the wall clock, so walk.sh can cut the film around each one.
// Nothing is ever sent to the house: the word typed is taken back.
//
// Run by scripts/walk.sh, which passes WALK_OUT (where the pictures and the
// log go) and CHINTAN_HOUSE (the house address) through the test runner.
final class ChintanWalk: XCTestCase {
    private var app: XCUIApplication!
    private var out: URL!
    private var log: FileHandle?
    private var shots = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        out = URL(fileURLWithPath: env["WALK_OUT"] ?? NSTemporaryDirectory() + "walk")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let logURL = out.appendingPathComponent("steps.tsv")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        log = try FileHandle(forWritingTo: logURL)
        app = XCUIApplication()
        app.launchArguments = ["--house", env["CHINTAN_HOUSE"] ?? "", "--tab", "jharokha"]
    }

    override func tearDown() {
        try? log?.close()
    }

    func testWalk() throws {
        mark("launch")
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
        pause(5) // the painting and the day come from the house
        shot("home")

        // Home: a ring told in words, the label's credit, a press and hold.
        let ring = app.descendants(matching: .any).matching(identifier: "ring").firstMatch
        if ring.exists {
            mark("ring")
            ring.tap()
            pause(1)
            shot("home-ring")
            ring.tap()
            pause(0.6)
        } else {
            note("home: no ring to tap")
        }
        let label = app.descendants(matching: .any).matching(identifier: "label").firstMatch
        if label.exists {
            mark("label")
            label.tap()
            pause(1)
            shot("home-credit")
            label.tap()
            pause(0.6)
            mark("hold-label")
            label.press(forDuration: 1.5)
            pause(0.8)
            shot("home-held")
        } else {
            note("home: no museum label")
        }

        // The swipe between tabs, as a thumb does it.
        mark("swipe-home-left")
        app.swipeLeft()
        pause(1.5)
        shot("home-swiped-left")
        note("after swipe left from Home, selected: " + selectedTab())

        mark("tab-board")
        app.tabBars.buttons["Board"].tap()
        pause(3)
        shot("board")

        // Down the shelves and back.
        mark("scroll-board")
        app.swipeUp()
        pause(1.5)
        shot("board-scrolled")
        mark("scroll-board-back")
        app.swipeDown()
        pause(1.5)

        let leaf = app.descendants(matching: .any).matching(identifier: "leaf").firstMatch
        if leaf.waitForExistence(timeout: 5) {
            mark("open-leaf")
            leaf.tap()
            pause(1)
            shot("board-leaf-open")
            leaf.tap()
            pause(0.8)
            mark("hold-leaf")
            leaf.press(forDuration: 1.5)
            pause(0.8)
            shot("board-leaf-held")
            // A hold that ends as a tap would leave the leaf open; close it.
            if app.buttons["Done"].exists { leaf.tap(); pause(0.6) }
        } else {
            note("board: no leaf to open")
        }

        mark("swipe-board-left")
        app.swipeLeft()
        pause(1.5)
        shot("board-swiped-left")
        note("after swipe left from Board, selected: " + selectedTab())
        mark("swipe-board-right")
        app.swipeRight()
        pause(1.5)
        note("after swipe right from Board, selected: " + selectedTab())

        mark("tab-study")
        app.tabBars.buttons["Study"].tap()
        pause(2)
        shot("study")

        mark("scroll-study")
        app.swipeDown()
        pause(1.5)
        shot("study-scrolled")

        for room in ["darban", "yaar", "chintan"] {
            let door = app.buttons[room].firstMatch
            guard door.exists else { note("study: no room " + room); continue }
            mark("room-" + room)
            door.tap()
            pause(1.2)
            shot("study-" + room)
        }

        // A word typed in a room, the keyboard up, and taken back unsent.
        let composer = app.textViews["composer"].exists ? app.textViews["composer"] : app.textFields["composer"]
        if composer.waitForExistence(timeout: 3) {
            mark("composer")
            composer.tap()
            pause(1.2)
            shot("study-keyboard")
            let word = "the walk says hello"
            mark("type")
            composer.typeText(word)
            pause(0.8)
            shot("study-typed")
            composer.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: word.count))
            pause(0.5)
            // The keyboard covers the tabs; a drag down the conversation
            // is how a thumb puts it away.
            mark("keyboard-away")
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            let into = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
            from.press(forDuration: 0.05, thenDragTo: into, withVelocity: .default, thenHoldForDuration: 0.1)
            pause(1.2)
            shot("study-keyboard-away")
            if app.keyboards.count > 0 { note("study: the keyboard stays up after a drag down") }
        } else {
            note("study: no composer")
        }

        // The phone turns dark under the hand; walk.sh flips it on this mark.
        mark("dark")
        pause(3)
        shot("study-dark")
        mark("tab-home-dark")
        app.tabBars.buttons["Home"].tap()
        pause(2)
        shot("home-dark")
        mark("tab-board-dark")
        app.tabBars.buttons["Board"].tap()
        pause(2)
        shot("board-dark")
        mark("light")
        pause(2)
        mark("end")
    }

    // MARK: the log and the pictures

    private func write(_ kind: String, _ text: String) {
        let t = String(format: "%.3f", Date().timeIntervalSince1970)
        log?.write(Data("\(t)\t\(kind)\t\(text)\n".utf8))
    }

    private func mark(_ name: String) { write("mark", name) }
    private func note(_ text: String) { write("note", text) }

    private func shot(_ name: String) {
        shots += 1
        let file = String(format: "%02d-%@.png", shots, name)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: out.appendingPathComponent(file))
        write("shot", file)
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func selectedTab() -> String {
        for name in ["Home", "Board", "Study"] where app.tabBars.buttons[name].isSelected {
            return name
        }
        return "none"
    }
}

// The hitches: the number Apple uses for jank, the hitch time ratio in ms
// per s (under 5 is good, over 10 is a visible jank). The simulator has no
// Instruments hitches, so the app times its own frames (--hitches) and this
// walk gives each gesture a window in hitches-steps.tsv; walk.sh sums the
// late frames in each window. Run apart from the walk, off the film.
final class ChintanHitches: XCTestCase {
    private var app: XCUIApplication!
    private var log: FileHandle?

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        let out = URL(fileURLWithPath: env["WALK_OUT"] ?? NSTemporaryDirectory() + "walk")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let url = out.appendingPathComponent("hitches-steps.tsv")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        log = try FileHandle(forWritingTo: url)
        app = XCUIApplication()
        app.launchArguments = ["--house", env["CHINTAN_HOUSE"] ?? "", "--tab", "jharokha", "--hitches"]
    }

    override func tearDown() {
        try? log?.close()
    }

    func testHitches() throws {
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 5)

        // The first visit to each tab, where a screen builds and fetches.
        window("first visits") {
            for tab in ["Board", "Study", "Home"] {
                app.tabBars.buttons[tab].tap()
                Thread.sleep(forTimeInterval: 1.5)
            }
        }
        window("tabs") {
            for _ in 0..<3 {
                for tab in ["Board", "Study", "Home"] {
                    app.tabBars.buttons[tab].tap()
                    Thread.sleep(forTimeInterval: 0.6)
                }
            }
        }
        window("swipe") {
            for _ in 0..<3 {
                app.swipeLeft(velocity: .fast)
                app.swipeRight(velocity: .fast)
            }
        }
        app.tabBars.buttons["Board"].tap()
        Thread.sleep(forTimeInterval: 2)
        window("board scroll") { fling(app.scrollViews.firstMatch) }
        app.tabBars.buttons["Study"].tap()
        Thread.sleep(forTimeInterval: 2)
        window("study scroll") { fling(app.scrollViews.firstMatch) }
    }

    private func fling(_ shelf: XCUIElement) {
        guard shelf.exists else { return }
        for _ in 0..<5 {
            shelf.swipeUp(velocity: .fast)
            shelf.swipeDown(velocity: .fast)
        }
    }

    // A gesture's window: its name, when it began and when the screen had
    // settled after it, on the wall clock the app's meter also writes.
    private func window(_ name: String, _ body: () -> Void) {
        let start = Date().timeIntervalSince1970
        body()
        Thread.sleep(forTimeInterval: 0.8)
        let end = Date().timeIntervalSince1970
        log?.write(Data(String(format: "%.3f\t%.3f\t%@\n", start, end, name).utf8))
    }
}
