import Foundation
import Security

// The house address, kept off disk in plain form: the one thing this app
// stores about where it talks to. Not in this repository, never synced.
enum Keychain {
    private static let service = "Prabhchintan.Chintan.house"
    private static let account = "houseAddress"

    static func loadHouseAddress() -> String? {
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
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
