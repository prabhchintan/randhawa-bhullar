import XCTest

// The loop's eyes on the pair. A walk drives the real app by its
// accessibility identifiers and labels, the way a hand would, and at each
// screen takes a picture and, in light and dark, runs Apple's accessibility
// audit. The apps know nothing of it: no launch arguments, no test hooks.
//
// Run by scripts/see.sh, which passes through the test runner WALK_OUT (the
// folder), WALK_LOOK (light, dark or large, the name each picture carries)
// and WALK_AUDIT (1 to audit). The look itself is the simulator's, set by
// the script before each pass.
class Eyes: XCTestCase {
    var app: XCUIApplication!
    private var out: URL!
    private var lookName = "light"
    private var auditing = false

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        out = URL(fileURLWithPath: env["WALK_OUT"] ?? NSTemporaryDirectory() + "see")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        lookName = env["WALK_LOOK"] ?? "light"
        auditing = env["WALK_AUDIT"] == "1"
        app = XCUIApplication()
    }

    /// One screen: its picture, then its audit.
    func see(_ screen: String) {
        pause(1)
        let shot = Self.appName + "-" + screen
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: out.appendingPathComponent("\(shot)-\(lookName).png"))
        guard auditing else { return }
        do {
            try app.performAccessibilityAudit { issue in
                let who = issue.element.map { el -> String in
                    let name = el.label.isEmpty ? el.identifier : el.label
                    let f = el.frame
                    return "\(name.prefix(40)) @\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))"
                } ?? "-"
                let what = issue.compactDescription.replacingOccurrences(of: "\n", with: " ")
                self.write("\(shot)\t\(self.lookName)\t\(Self.kind(issue.auditType))\t\(who)\t\(what)")
                return true
            }
        } catch {
            write("\(shot)\t\(lookName)\taudit\t-\tdid not run: \(error.localizedDescription)")
        }
    }

    /// randhawa or bhullar, from the walk's own name, so the two apps'
    /// pictures never overwrite each other.
    private static var appName: String {
        String(describing: self).replacingOccurrences(of: "Walk", with: "").lowercased()
    }

    /// Any element by its label, whatever kind UIKit made of it.
    func labelled(_ prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// A line for the script to print when the walk could not go somewhere.
    func note(_ line: String) {
        let url = out.appendingPathComponent("notes.txt")
        append("\(type(of: self)) \(lookName): \(line)\n", to: url)
    }

    func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Writes a new memory through the composer, the plus in both apps.
    func remember(_ words: String) -> Bool {
        let plus = app.buttons["remember"]
        guard plus.waitForExistence(timeout: 10) else { note("no plus"); return false }
        plus.tap()
        let field = app.descendants(matching: .any).matching(identifier: "words").firstMatch
        guard field.waitForExistence(timeout: 5) else { note("no composer"); return false }
        see("composer")
        field.typeText(words)
        app.buttons["Save"].tap()
        return true
    }

    /// Closes whatever sheet is up by its Done.
    func done() {
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 3) { done.tap() } else { note("no Done to close with") }
        pause(1)
    }

    private func write(_ line: String) {
        append(line + "\n", to: out.appendingPathComponent("audit.tsv"))
    }

    private func append(_ text: String, to url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(Data(text.utf8))
        try? handle.close()
    }

    private static func kind(_ type: XCUIAccessibilityAuditType) -> String {
        switch type {
        case .contrast: return "contrast"
        case .elementDetection: return "element"
        case .hitRegion: return "hit region"
        case .sufficientElementDescription: return "description"
        case .dynamicType: return "dynamic type"
        case .textClipped: return "clipped"
        case .trait: return "trait"
        default: return "other"
        }
    }
}
