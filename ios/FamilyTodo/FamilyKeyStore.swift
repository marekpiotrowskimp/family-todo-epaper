import Foundation
import Security

/// Klucz rodziny w Keychain (tylko na tym urządzeniu, dostępny po pierwszym odblokowaniu,
/// bez kopii w iCloud). Aplikacja nie zawiera klucza — każda rodzina ma własny.
enum FamilyKeyStore {
    private static var base: [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "pl.piotrowski.familytodo.family-key",
        kSecAttrAccount as String: "family-key",
    ] }

    static func load() -> Data? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    static func save(_ key: Data) -> Bool {
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = key
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(base as CFDictionary)
    }
}
