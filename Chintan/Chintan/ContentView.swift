import SwiftUI

struct ContentView: View {
    @StateObject private var store = ConversationStore()
    @State private var showingSettings = false

    var body: some View {
        TabView {
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

            NavigationStack {
                BoardView()
            }
            .tabItem { Label("The board", systemImage: "checklist") }

            NavigationStack {
                JharokhaView()
            }
            .tabItem { Label("The jharokha", systemImage: "rectangle.split.3x1") }
        }
        .environmentObject(store)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
