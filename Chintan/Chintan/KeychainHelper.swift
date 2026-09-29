import Foundation
import Security

// The house address, kept off disk in plain form: the one thing this app
// stores about where it talks to. Not in this repository, never synced.
enum Keychain {
    private static let service = "Prabhchintan.Chintan.house"
    private static let account = "houseAddress"

    // Set from the command line (--house) for the house's own screenshots in
    // the simulator; wins over the Keychain and never persists.
    static var override: String?

    // On the Mac an ad hoc build has no data protection keychain (no team, no
    // entitlement), so the address lives in the app's defaults there; the
    // house writes it once (`defaults write Prabhchintan.Chintan houseAddress`)
    // and a --house launch remembers it (Prab, 2026-09-27 13:37: "it says no
    // house address add in settings but i don't see a settings things").
    private static let defaultsKey = "houseAddress"

    static func loadHouseAddress() -> String? {
        if let override, !override.isEmpty {
            #if targetEnvironment(macCatalyst)
            UserDefaults.standard.set(override, forKey: defaultsKey)
            #endif
            return override
        }
        #if targetEnvironment(macCatalyst)
        if let kept = UserDefaults.standard.string(forKey: defaultsKey), !kept.isEmpty { return kept }
        #endif
        return typed() ?? House.address
    }

    // The address typed in settings, which wins over the build's own.
    private static func typed() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let address = String(data: data, encoding: .utf8),
              !address.isEmpty else { return nil }
        return address
    }

    static func saveHouseAddress(_ address: String) {
        #if targetEnvironment(macCatalyst)
        UserDefaults.standard.set(address, forKey: defaultsKey)
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(address.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    // A wake for a move comes with the phone locked more often than not, so
    // the address is readable after the first unlock, as the house's fixes
    // need; an address kept before this is moved over once, while unlocked.
    static func keepAfterFirstUnlock() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let change: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemUpdate(query as CFDictionary, change as CFDictionary)
    }
}
