import Foundation
import Security

final class KeychainStore {
    static let service = "com.tokentracker.session"
    static let account = "sessionKey"

    static func save(_ value: String) throws {
        // Also persist in UserDefaults as fallback (Keychain can prompt on dev rebuilds)
        UserDefaults.standard.set(value, forKey: "com.tokentracker.sessionKey.backup")

        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        // Fallback: UserDefaults backup (persists across dev rebuilds)
        return UserDefaults.standard.string(forKey: "com.tokentracker.sessionKey.backup")
    }

    static func delete() {
        UserDefaults.standard.removeObject(forKey: "com.tokentracker.sessionKey.backup")
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error {
        case saveFailed(OSStatus)
    }
}
