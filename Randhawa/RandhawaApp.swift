import SwiftUI

@main
struct RandhawaApp: App {
    init() {
        // Re-arm the trail before anything else. iOS relaunches this app in the
        // background to deliver location events, and in those launches no view
        // is ever built, so this initialiser is the only place guaranteed to
        // run. A no-op when the trail is off, which is the default.
        LocationTrail.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
