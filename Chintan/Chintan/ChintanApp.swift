import SwiftUI

@main
struct ChintanApp: App {
    init() {
        Theme.apply()
        // Launch arguments, for the house's own eyes: the simulator on yantar
        // launches the app with the house address and the tab to show, then
        // takes a picture of it. A phone never passes these.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--house"), i + 1 < args.count {
            Keychain.override = args[i + 1]
        }
        if args.contains("--hitches") {
            HitchMeter.shared.start()
        }
        // Made at launch, so a wake for a move finds its delegate.
        _ = Whereabouts.shared
        _ = PhoneWord.shared
    }

    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: phase) { _, now in
            if now == .active { Whereabouts.shared.freshen() }
            PhoneWord.shared.scene(now)
        }
    }
}

// The hitch meter, for the walk only (launched with --hitches; a phone never
// is). The simulator has no Instruments hitches, so the app times its own
// frames: a frame that lands more than half a frame late is a hitch, and its
// lateness is written with the wall clock to Caches/hitches.tsv. walk.sh
// sums them over each gesture the walk logs, the hitch time ratio in ms per s.
final class HitchMeter: NSObject {
    static let shared = HitchMeter()
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var file: FileHandle?

    func start() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("hitches.tsv")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        file = try? FileHandle(forWritingTo: url)
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    // The walk with no hand (launched with --hitches --self-walk, by walk.sh
    // through simctl, never a test): the app turns its own pages the way a
    // tap on the bar does and logs each window beside the frames, so the
    // numbers hold the app's own cost alone. A test's hand reads the whole
    // accessibility tree on the main thread at every gesture; a phone's never does.
    @MainActor func walk(turn: @escaping (Tab) -> Void) async {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("self-steps.tsv")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let log = try? FileHandle(forWritingTo: url)
        func window(_ name: String, _ body: () async -> Void) async {
            let start = Date().timeIntervalSince1970
            await body()
            try? await Task.sleep(for: .seconds(0.8))
            let line = String(format: "%.3f\t%.3f\t%@\n", start, Date().timeIntervalSince1970, name)
            log?.write(Data(line.utf8))
        }
        try? await Task.sleep(for: .seconds(6))
        await window("rest, no hand") { try? await Task.sleep(for: .seconds(3)) }
        await window("tabs, no hand") {
            for _ in 0..<3 {
                for t in [Tab.board, .study, .jharokha] {
                    turn(t)
                    try? await Task.sleep(for: .seconds(0.6))
                }
            }
        }
        await window("neighbours, no hand") {
            for _ in 0..<3 {
                for t in [Tab.board, .jharokha] {
                    turn(t)
                    try? await Task.sleep(for: .seconds(0.6))
                }
            }
        }
        try? log?.close()
        FileManager.default.createFile(atPath: caches.appendingPathComponent("self-done").path, contents: nil)
    }

    @objc private func frame(_ link: CADisplayLink) {
        defer { last = link.timestamp }
        guard last > 0, link.duration > 0 else { return }
        let late = (link.timestamp - last) - link.duration
        guard late > link.duration / 2 else { return }
        let line = String(format: "%.3f\t%.1f\n", Date().timeIntervalSince1970, late * 1000)
        file?.write(Data(line.utf8))
    }
}
