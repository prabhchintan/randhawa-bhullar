import SwiftUI

// The house address, typed once and kept in the Keychain, and a health
// check that says plainly whether the house is home.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address: String = Keychain.loadHouseAddress() ?? ""
    @State private var status: String?
    @State private var checking = false

    var body: some View {
        NavigationStack {
            Form {
                Section("House address") {
                    TextField("http://100.x.x.x:port", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Save") {
                        Keychain.saveHouseAddress(address.trimmingCharacters(in: .whitespacesAndNewlines))
                        status = nil
                    }
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Health check") {
                    Button {
                        Task { await checkHealth() }
                    } label: {
                        if checking { ProgressView() } else { Text("Check") }
                    }
                    .disabled(checking || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let status {
                        Text(status)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func checkHealth() async {
        checking = true
        defer { checking = false }
        do {
            let health = try await HouseClient(baseAddress: address).health()
            status = health.ok ? "chintan is home." : "The house answered, but not well."
        } catch {
            status = "The house is not answering. Are you on the tailnet?"
        }
    }
}
