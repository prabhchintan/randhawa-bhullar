import SwiftUI

// The house's one-screen view, as plain monospaced text. Refreshed on open
// and by pull.
struct JharokhaView: View {
    @State private var text = ""
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.spacing)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }
        }
        .paperBackground()
        .refreshable { await refresh() }
        .task { await refresh() }
        .navigationTitle("Home")
    }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            return
        }
        do {
            text = try await HouseClient(baseAddress: address).cockpit()
            errorText = nil
        } catch {
            errorText = "The house is not answering. Are you on the tailnet?"
        }
    }
}
