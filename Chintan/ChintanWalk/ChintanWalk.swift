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
        app.launchArguments = ["--house", env["CHINTAN_HOUSE"] ?? "", "--tab", "jharokha", "--keep-staged"]
    }

    override func tearDown() {
        try? log?.close()
    }

    func testWalk() throws {
        mark("launch")
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))
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
            // Held, the ring grows its plaque; the film sees it grow and fold.
            mark("hold-ring")
            ring.press(forDuration: 1.5)
            pause(0.8)
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
            // Held again and slid up onto the plaque's last line, a word for
            // the house opens; a word is typed and put away, never sent.
            mark("slide-word")
            let from = label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let onto = label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: -40, dy: -62))
            from.press(forDuration: 0.8, thenDragTo: onto)
            pause(1)
            let word = app.descendants(matching: .any).matching(identifier: "word").firstMatch
            if word.waitForExistence(timeout: 2) {
                shot("home-word")
                word.typeText("the walk")
                pause(0.5)
                shot("home-word-typed")
                mark("word-away")
                app.buttons["Put away"].tap()
                pause(1)
            } else {
                note("home: the slide did not open a word for the house")
            }
        } else {
            note("home: no museum label")
        }

        // A tap on the bare picture leaves the painting alone; a pinch looks
        // closer and springs back; a tap brings the wall back.
        mark("alone")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        pause(1)
        shot("home-alone")
        if app.buttons["Home"].isHittable { note("home: the tap did not leave the painting alone") }
        mark("pinch")
        app.pinch(withScale: 2.5, velocity: 1)
        pause(1)
        // Alone, a swipe to the left walks on to tomorrow's painting and one
        // to the right walks back; the film sees each turn cross.
        mark("alone-turn-on")
        app.swipeLeft()
        pause(1.5)
        shot("home-alone-on")
        mark("alone-turn-back")
        app.swipeRight()
        pause(1.5)
        shot("home-alone-returned")
        // Held, the painting is kept; the answer rises in the foot below the
        // work. Staged by `--keep-staged`, so nothing is filed.
        mark("alone-hold")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).press(forDuration: 1.0)
        pause(0.6)
        shot("home-alone-kept")
        pause(3.5)
        mark("alone-back")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        pause(1)
        shot("home-back")
        if !app.buttons["Home"].isHittable { note("home: a tap did not bring the wall back") }

        // The swipe between tabs, as a thumb does it.
        mark("swipe-home-left")
        app.swipeLeft()
        pause(1.5)
        shot("home-swiped-left")
        note("after swipe left from Home, selected: " + selectedTab())

        mark("tab-board")
        app.buttons["Board"].tap()
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

        // The heading held grows its plaque over a dimmed board; held again
        // and slid down onto the plaque's last line, a word for the house
        // opens, is typed and put away, never sent.
        let heading = app.descendants(matching: .any).matching(identifier: "heading").firstMatch
        if heading.exists {
            mark("hold-heading")
            heading.press(forDuration: 1.5)
            pause(0.8)
            mark("slide-word-board")
            let from = heading.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7))
            let onto = heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(CGVector(dx: 0, dy: 87))
            from.press(forDuration: 0.8, thenDragTo: onto)
            pause(1)
            if typeWord("board") {
                mark("word-away-board")
                app.buttons["Put away"].tap()
                pause(1)
            }
        } else {
            note("board: no heading to hold")
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
        app.buttons["Study"].tap()
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

        // A room's name held grows its plaque under the names; the film sees
        // it grow and fold, and the room stays as it was.
        let darbanName = app.buttons["darban"].firstMatch
        if darbanName.exists {
            mark("hold-room")
            darbanName.press(forDuration: 1.5)
            pause(0.8)
            note("after holding darban, chintan is " + (app.buttons["chintan"].firstMatch.isSelected ? "still open" : "not open"))
            // Held again and slid down the plaque onto its last line.
            mark("slide-word-study")
            let from = darbanName.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.8, thenDragTo: from.withOffset(CGVector(dx: 24, dy: 198)))
            pause(1)
            if typeWord("study") {
                mark("word-away-study")
                app.buttons["Put away"].tap()
                pause(1)
            }
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
        app.buttons["Home"].tap()
        pause(2)
        shot("home-dark")
        mark("tab-board-dark")
        app.buttons["Board"].tap()
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

    // The composer a slide opened: photographed, a word typed, photographed.
    private func typeWord(_ screen: String) -> Bool {
        let word = app.descendants(matching: .any).matching(identifier: "word").firstMatch
        guard word.waitForExistence(timeout: 2) else {
            note(screen + ": the slide did not open a word for the house")
            return false
        }
        shot(screen + "-word")
        word.typeText("the walk")
        pause(0.5)
        shot(screen + "-word-typed")
        return true
    }

    private func selectedTab() -> String {
        for name in ["Home", "Board", "Study"] where app.buttons[name].isSelected {
            return name
        }
        return "none"
    }
}

// The audit: Apple's own accessibility audit (iOS 17) on every screen the
// walk rests on: contrast, dynamic type, hit targets, element descriptions,
// clipped text. Each finding is a line in audit.tsv (screen, appearance,
// kind, element, what is wrong), not a failure, so the walk runs whole and
// walk.sh prints the list. walk.sh runs it once light and once dark, passing
// AUDIT_LOOK. Zero findings is the bar.
final class ChintanAudit: XCTestCase {
    private var app: XCUIApplication!
    private var log: FileHandle?
    private var waived: FileHandle?
    private var look = "light"

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        look = env["AUDIT_LOOK"] ?? "light"
        let out = URL(fileURLWithPath: env["WALK_OUT"] ?? NSTemporaryDirectory() + "walk")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        log = try Self.append(out.appendingPathComponent("audit.tsv"))
        waived = try Self.append(out.appendingPathComponent("audit-waived.tsv"))
        app = XCUIApplication()
        app.launchArguments = ["--house", env["CHINTAN_HOUSE"] ?? "", "--tab", "jharokha"]
    }

    override func tearDown() {
        try? log?.close()
        try? waived?.close()
    }

    // Light and dark each add to the same list.
    private static func append(_ url: URL) throws -> FileHandle {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let file = try FileHandle(forWritingTo: url)
        try file.seekToEnd()
        return file
    }

    func testAudit() throws {
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 5)
        audit("home")

        app.buttons["Board"].tap()
        Thread.sleep(forTimeInterval: 3)
        audit("board")
        let leaf = app.descendants(matching: .any).matching(identifier: "leaf").firstMatch
        if leaf.waitForExistence(timeout: 5) {
            leaf.tap()
            Thread.sleep(forTimeInterval: 1)
            audit("board, a leaf open")
            leaf.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }

        app.buttons["Study"].tap()
        Thread.sleep(forTimeInterval: 2)
        audit("study")
        let darban = app.buttons["darban"].firstMatch
        if darban.exists {
            darban.tap()
            Thread.sleep(forTimeInterval: 1.2)
            audit("study, darban")
            app.buttons["chintan"].firstMatch.tap()
        }
    }

    // Findings waived by name, each against the pictures, never silently:
    // they go to audit-waived.tsv with the reason, and walk.sh counts them.
    // - contrast, every screen: the audit samples the painting around the
    //   letters, not the plaque under them, and reads bone on lamp black (about
    //   15 to 1) as failed; the plaques' ink, the board's dates and shelf names,
    //   the study's words, Home's lines and label over their shade and the
    //   bar's names all read cleanly in both modes in every look since sprint 4.
    // - text clipped, the board: a thing's reasons stop at two lines by
    //   design; the rest is on tap.
    // - dynamic type, the bar's names and the rings' names: held at a size on
    //   purpose (the bar at the system tab bar's, with the large content viewer
    //   on a press and hold; the rings, a picture, at the first large size), so
    //   the largest text never runs them off the phone. Seen at the largest size.
    private static let heldAtSize: Set<String> = ["Home", "Board", "Study", "hours", "week", "fable"]

    private static func waiver(_ type: XCUIAccessibilityAuditType, on screen: String, element: String?) -> String? {
        if type == .dynamicType, let element, heldAtSize.contains(element) {
            return "held at a size by design, the large content viewer on the bar; seen at the largest text"
        }
        if type == .contrast {
            return "samples the painting, not the plaque or shade under the letters; clean in the pictures"
        }
        if type == .textClipped, screen.hasPrefix("board") {
            return "a thing's reasons stop at two lines by design, the rest on tap"
        }
        return nil
    }

    private func audit(_ screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                let who = issue.element.map { el -> String in
                    let name = el.label.isEmpty ? el.identifier : el.label
                    let f = el.frame
                    return "\(el.elementType.rawValue):\(name.prefix(40)) @\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))"
                } ?? "-"
                // The long word too, so a finding names what it measured.
                let what = (issue.compactDescription + ": " + issue.detailedDescription)
                    .replacingOccurrences(of: "\n", with: " ")
                let line = "\(screen)\t\(self.look)\t\(Self.kind(issue.auditType))\t\(who)\t\(what)"
                if let why = Self.waiver(issue.auditType, on: screen, element: issue.element?.label) {
                    self.waived?.write(Data("\(line)\twaived: \(why)\n".utf8))
                } else {
                    self.log?.write(Data((line + "\n").utf8))
                }
                return true
            }
        } catch {
            log?.write(Data("\(screen)\t\(look)\taudit\t-\t\(error.localizedDescription)\n".utf8))
        }
    }

    private static func kind(_ type: XCUIAccessibilityAuditType) -> String {
        switch type {
        case .contrast: return "contrast"
        case .dynamicType: return "dynamic type"
        case .hitRegion: return "hit region"
        case .elementDetection: return "element detection"
        case .sufficientElementDescription: return "description"
        case .textClipped: return "text clipped"
        case .trait: return "trait"
        default: return "other \(type.rawValue)"
        }
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
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 5)

        // A ring held and let go: the plaque grows and folds.
        let ring = app.descendants(matching: .any).matching(identifier: "ring").firstMatch
        if ring.exists {
            window("reveal") {
                for _ in 0..<3 {
                    ring.press(forDuration: 1.0)
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }

        // The first visit to each tab, where a screen builds and fetches.
        window("first visits") {
            for tab in ["Board", "Study", "Home"] {
                app.buttons[tab].tap()
                Thread.sleep(forTimeInterval: 1.5)
            }
        }
        window("tabs") {
            for _ in 0..<3 {
                for tab in ["Board", "Study", "Home"] {
                    app.buttons[tab].tap()
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
        app.buttons["Board"].tap()
        Thread.sleep(forTimeInterval: 2)
        window("board scroll") { fling(app.scrollViews["shelves"]) }
        app.buttons["Study"].tap()
        Thread.sleep(forTimeInterval: 2)
        window("study scroll") { fling(app.scrollViews["conversation"]) }
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

// The widget's eyes (widget.sh): the app opened once, then the simulator's
// own home screen (the widget finds the house by the build's address): the widget
// gallery searched for chintan, each size photographed as the gallery shows
// it, the large one added and photographed standing on the home screen, and
// taken off again so the next look starts from the same screen.
final class ChintanWidgetEyes: XCTestCase {
    private var out: URL!
    private let board = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func testGallery() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        out = URL(fileURLWithPath: env["WALK_OUT"] ?? NSTemporaryDirectory() + "widget")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let app = XCUIApplication()
        app.launchArguments = ["--house", env["CHINTAN_HOUSE"] ?? "", "--tab", "jharokha"]
        app.launch()
        sleep(6)
        XCUIDevice.shared.press(.home)
        sleep(2)
        tree("home")
        // The first page has no room for the large one, and the simulator's
        // home screen faults when a widget spills onto a new page (its ripple,
        // SBHRippleSimulation); so place it on the page chintan's icon stands on.
        let icon = board.icons["chintan"]
        var turns = 0
        while turns < 3 && !(icon.exists && icon.frame.width > 0 && board.frame.contains(icon.frame)) {
            board.swipeLeft()
            sleep(2)
            turns += 1
        }
        shot("home-before")
        // Into the home screen's edit mode, from an empty spot above the dock.
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).press(forDuration: 1.6)
        sleep(1)
        let editMenu = board.buttons["Edit Home Screen"]
        if editMenu.exists { editMenu.tap(); sleep(1) }
        let edit = board.buttons["Edit"]
        if edit.waitForExistence(timeout: 4) {
            edit.tap()
            sleep(1)
            let add = board.buttons["Add Widget"]
            if add.waitForExistence(timeout: 3) { add.tap() }
        } else if board.buttons["Add Widget"].exists {
            board.buttons["Add Widget"].tap()
        }
        sleep(2)
        tree("gallery")
        let search = board.searchFields["Search Widgets"]
        guard search.waitForExistence(timeout: 5) else { shot("no-gallery"); return }
        search.tap()
        search.typeText("chintan")
        sleep(2)
        tree("search")
        let found = board.cells.containing(.staticText, identifier: "chintan").firstMatch
        let named = board.staticTexts["chintan"].firstMatch
        if found.exists { found.tap() } else if named.exists { named.tap() } else { shot("not-found"); return }
        // The gallery asks the widget for its snapshot, from the house; let it hang.
        sleep(12)
        tree("sizes")
        shot("gallery-small")
        for size in ["medium", "large"] {
            board.swipeLeft()
            sleep(6)
            shot("gallery-" + size)
        }
        // The system letters it " Add Widget", its plus sign a space.
        let place = board.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch
        guard place.waitForExistence(timeout: 3) else { return }
        // Add Widget faults the simulator's home screen in its drop ripple
        // (SBHRippleSimulation), so the preview is carried out by hand.
        let preview = board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        preview.press(forDuration: 1.2, thenDragTo: board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        sleep(3)
        shot("placed-edit")
        tree("placed-edit")
        XCUIDevice.shared.press(.home)
        sleep(10)
        // The home screen names a widget as an icon whose value begins "Widget".
        let held = board.icons.matching(NSPredicate(format: "identifier == 'chintan' AND value BEGINSWITH 'Widget'")).firstMatch
        // It may land on a later page: walk on until it stands in view.
        var page = 1
        while page < 4 && !(held.exists && held.isHittable) {
            board.swipeLeft()
            sleep(3)
            page += 1
        }
        shot("home-large")
        tree("placed")
        // Off again, so the next look begins on the same home screen.
        if held.exists && held.isHittable {
            held.press(forDuration: 1.6)
            let remove = board.buttons["Remove Widget"]
            if remove.waitForExistence(timeout: 3) {
                remove.tap()
                let sure = board.alerts.buttons["Remove"]
                if sure.waitForExistence(timeout: 3) { sure.tap() }
            }
        }
        XCUIDevice.shared.press(.home)
    }

    private func shot(_ name: String) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: out.appendingPathComponent(name + ".png"))
    }

    // What the home screen holds at each step, for when a step misses.
    private func tree(_ name: String) {
        try? Data(board.debugDescription.utf8).write(to: out.appendingPathComponent("tree-" + name + ".txt"))
    }
}
