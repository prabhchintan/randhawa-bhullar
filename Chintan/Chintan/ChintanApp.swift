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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
