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
        // Made at launch, so a wake for a move or for Health finds its delegate.
        // The phone's senses are the phone's: the Mac is a wall and tells the
        // house nothing of where, how or what.
        #if !targetEnvironment(macCatalyst)
        _ = Whereabouts.shared
        _ = PhoneWord.shared
        _ = Health.shared
        _ = Motion.shared
        _ = Metrics.shared
        Wakes.register()
        Wakes.ask()
        #endif
    }

    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: phase) { _, now in
            #if targetEnvironment(macCatalyst)
            if now == .active { Wall.fill() }
            #else
            if now == .active {
                Whereabouts.shared.freshen()
                Health.shared.freshen()
                Motion.shared.freshen()
                Metrics.shared.freshen()
            }
            PhoneWord.shared.scene(now)
            if now == .background { Wakes.ask() }
            #endif
        }
        #if targetEnvironment(macCatalyst)
        .commands { WallMenu() }
        #endif
    }
}

#if targetEnvironment(macCatalyst)
// The wall's one setting, in the menu bar that comes down over the full
// screen: how often it turns to the next painting.
struct WallMenu: Commands {
    @AppStorage(WallPace.key) private var minutes = WallPace.standard

    var body: some Commands {
        CommandMenu("Wall") {
            Picker("Turn Every", selection: $minutes) {
                ForEach(WallPace.choices, id: \.self) { m in
                    Text(m == 60 ? "1 Hour" : "\(m) Minutes").tag(m)
                }
            }
        }
    }
}
#endif

#if targetEnvironment(macCatalyst)
// The Mac is a wall: no title, no toolbar, and the window full screen on
// launch, so the menu bar and the Dock step away and the painting is the room.
// Catalyst has no word for full screen of its own; AppKit's window is asked
// by name, once.
@MainActor
enum Wall {
    private static var filled = false

    static func fill() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.titlebar?.titleVisibility = .hidden
            scene.titlebar?.toolbar = nil
        }
        guard !filled, !ProcessInfo.processInfo.arguments.contains("--windowed") else { return }
        filled = true
        // The window is made a beat after the scene says it is active.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let app = (NSClassFromString("NSApplication") as? NSObject.Type)?.value(forKey: "sharedApplication") as? NSObject,
                  let windows = app.value(forKey: "windows") as? [NSObject] else { return }
            for window in windows where (window.value(forKey: "canBecomeMainWindow") as? Bool) == true {
                let mask = (window.value(forKey: "styleMask") as? UInt) ?? 0
                if mask & (1 << 14) == 0 { window.perform(NSSelectorFromString("toggleFullScreen:"), with: nil) }
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--say-window") { say() }
    }

    // For the house's eyes (`--say-window`, wall.sh only): twice a second the
    // wall writes Caches/wall-state, "full" when its window is full screen,
    // in front and on the space in view, "window" when it is up but not that.
    // The runner cannot read the window server's list, so the wall says it.
    private static func say() {
        let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wall-state")
        Task { @MainActor in
            while true {
                var state = "window"
                if let app = (NSClassFromString("NSApplication") as? NSObject.Type)?.value(forKey: "sharedApplication") as? NSObject,
                   (app.value(forKey: "isActive") as? Bool) == true,
                   let windows = app.value(forKey: "windows") as? [NSObject] {
                    let full = windows.contains { w in
                        ((w.value(forKey: "styleMask") as? UInt) ?? 0) & (1 << 14) != 0
                            && (w.value(forKey: "isOnActiveSpace") as? Bool) == true
                            && (w.value(forKey: "isVisible") as? Bool) == true
                    }
                    if full { state = "full" }
                }
                try? Data(state.utf8).write(to: file, options: .atomic)
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
    }
}
#endif

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
