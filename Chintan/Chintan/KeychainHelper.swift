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

    static func loadHouseAddress() -> String? {
        if let override, !override.isEmpty { return override }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveHouseAddress(_ address: String) {
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
