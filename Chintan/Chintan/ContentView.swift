import SwiftUI

// The raw values are the names the house's screenshots pass on the command
// line, so they stay as they are even where the tab's own name has moved on.
enum Tab: String {
    case jharokha, board, study

    // The tab named on the command line, for the house's screenshots.
    static var launch: Tab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tab"), i + 1 < args.count, let tab = Tab(rawValue: args[i + 1]) {
            return tab
        }
        return .jharokha
    }
}

struct ContentView: View {
    @StateObject private var store = ConversationStore()
    @State private var showingSettings = false
    @State private var tab: Tab = Tab.launch

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                JharokhaView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(Tab.jharokha)

            NavigationStack {
                BoardView()
            }
            .tabItem { Label("Board", systemImage: "checklist") }
            .tag(Tab.board)

            NavigationStack {
                StudyView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
            }
            .tabItem { Label("Study", systemImage: "bubble.left.and.text.bubble.right") }
            .tag(Tab.study)
        }
        .tint(Theme.saffron)
        .environmentObject(store)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .tint(Theme.saffron)
        }
    }
}
