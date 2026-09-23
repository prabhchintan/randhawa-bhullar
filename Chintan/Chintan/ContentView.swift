import SwiftUI

enum Tab: String {
    case study, board, jharokha

    // The tab named on the command line, for the house's screenshots.
    static var launch: Tab {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tab"), i + 1 < args.count, let tab = Tab(rawValue: args[i + 1]) {
            return tab
        }
        return .study
    }
}

struct ContentView: View {
    @StateObject private var store = ConversationStore()
    @State private var showingSettings = false
    @State private var tab: Tab = Tab.launch

    var body: some View {
        TabView(selection: $tab) {
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
            .tabItem { Label("The study", systemImage: "text.bubble") }
            .tag(Tab.study)

            NavigationStack {
                BoardView()
            }
            .tabItem { Label("The board", systemImage: "checklist") }
            .tag(Tab.board)

            NavigationStack {
                JharokhaView()
            }
            .tabItem { Label("The jharokha", systemImage: "rectangle.split.3x1") }
            .tag(Tab.jharokha)
        }
        .environmentObject(store)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
