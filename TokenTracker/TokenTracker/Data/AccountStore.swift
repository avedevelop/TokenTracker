import Foundation
import Security
import Combine

struct AccountProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var orgId: String
    var email: String?
    var fullName: String?
    var tokenValid: Bool = true

    var displayName: String { fullName ?? email ?? name }
    var initials: String {
        let src = fullName ?? email ?? name
        let parts = src.split(separator: " ").map { String($0.prefix(1)).uppercased() }
        if parts.count >= 2 { return parts[0] + parts[1] }
        return String(src.prefix(2)).uppercased()
    }
}

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published private(set) var profiles: [AccountProfile] = []
    @Published private(set) var activeId: UUID?

    private let profilesKey = "com.tokentracker.accounts"
    private let activeKey   = "com.tokentracker.activeAccountId"
    // Single Keychain item stores all tokens as JSON dict — one prompt only
    private let keychainService = "com.tokentracker.session"
    private let keychainAccount = "allTokens"
    private var tokenCache: [UUID: String] = [:]

    private init() { load() }

    var activeProfile: AccountProfile? { profiles.first { $0.id == activeId } }

    func load() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([AccountProfile].self, from: data) {
            profiles = decoded
        }
        if let str = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: str) {
            activeId = id
        }
        // Load all tokens in one Keychain read
        tokenCache = readAllTokensFromKeychain()
        migrateLegacyIfNeeded()
        // If profiles exist in UserDefaults but Keychain has no tokens (e.g. after app
        // reinstall), purge stale profile metadata so login starts from a clean state.
        purgeStaleProfilesIfNeeded()
        repairActiveProfileIfNeeded()
        syncManifestToSharedStore()
    }

    func add(name: String, orgId: String, token: String) throws {
        let profile = AccountProfile(id: UUID(), name: name, orgId: orgId)
        tokenCache[profile.id] = token
        try writeAllTokensToKeychain()
        profiles.append(profile)
        saveProfiles()
        if activeId == nil { setActive(profile.id) }
    }

    func remove(_ profile: AccountProfile) {
        tokenCache.removeValue(forKey: profile.id)
        try? writeAllTokensToKeychain()
        profiles.removeAll { $0.id == profile.id }
        SharedStore.deleteAccount(id: profile.id)
        saveProfiles()
        if activeId == profile.id {
            activeId = profiles.first?.id
            saveActiveId()
        }
    }

    func setActive(_ id: UUID) {
        activeId = id
        saveActiveId()
    }

    func token(for id: UUID) -> String? { tokenCache[id] }

    func activeToken() -> String? {
        guard let id = activeId else { return nil }
        return tokenCache[id]
    }

    /// Creates or updates the active profile with the given token (initial login only).
    func ensureProfile(token: String, orgId: String? = nil) {
        if let id = activeId {
            tokenCache[id] = token
            if let orgId {
                updateOrgId(orgId, for: id)
            }
            try? writeAllTokensToKeychain()
        } else {
            let orgId = orgId ?? UserDefaults.standard.string(forKey: "com.tokentracker.orgId") ?? ""
            try? add(name: "Claude.ai", orgId: orgId, token: token)
        }
    }

    /// Always creates a new profile and switches to it (for adding a second account).
    func addNewProfile(token: String, orgId: String? = nil) {
        let orgId = orgId ?? UserDefaults.standard.string(forKey: "com.tokentracker.orgId") ?? ""
        let profile = AccountProfile(id: UUID(), name: "Claude.ai", orgId: orgId)
        tokenCache[profile.id] = token
        try? writeAllTokensToKeychain()
        profiles.append(profile)
        saveProfiles()
        setActive(profile.id)
        if !orgId.isEmpty {
            UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
        }
    }

    func updateProfileInfo(id: UUID, email: String?, fullName: String?, tokenValid: Bool = true) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].email = email
        profiles[idx].fullName = fullName
        profiles[idx].tokenValid = tokenValid
        if let e = email, profiles[idx].name == "Claude.ai" {
            profiles[idx].name = e
        }
        saveProfiles()
    }

    func updateOrgId(_ orgId: String, for id: UUID) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].orgId = orgId
        // Keep UserDefaults in sync for backward compat with LimitsPoller
        UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
        saveProfiles()
    }

    var activeOrgId: String? {
        guard let orgId = activeProfile?.orgId, !orgId.isEmpty else {
            return UserDefaults.standard.string(forKey: "com.tokentracker.orgId")
        }
        return orgId
    }

    func markTokenStatus(id: UUID, valid: Bool) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].tokenValid = valid
        saveProfiles()
    }

    func updateToken(_ token: String, for id: UUID) throws {
        tokenCache[id] = token
        try writeAllTokensToKeychain()
    }

    // MARK: - Private

    private func readAllTokensFromKeychain() -> [UUID: String] {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: dict.compactMap { k, v in
            UUID(uuidString: k).map { ($0, v) }
        })
    }

    private func writeAllTokensToKeychain() throws {
        let dict = Dictionary(uniqueKeysWithValues: tokenCache.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(dict) else { return }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]
        let attrs: [CFString: Any] = [
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AccountStoreError.saveFailed(addStatus) }
        } else if status != errSecSuccess {
            throw AccountStoreError.saveFailed(status)
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
        syncManifestToSharedStore()
    }

    private func saveActiveId() {
        UserDefaults.standard.set(activeId?.uuidString, forKey: activeKey)
        syncManifestToSharedStore()
    }

    /// Writes the accounts manifest (id + display name + active flag) so the widget
    /// can list accounts via LocalServer and pick which one to display.
    private func syncManifestToSharedStore() {
        let entries = profiles.map { SharedStore.AccountListEntry(id: $0.id, name: $0.displayName) }
        let widgetAccountId = SharedStore.preservedWidgetAccountId(
            SharedStore.readAccountsManifest().widgetAccountId,
            accounts: entries
        )
        SharedStore.writeAccountsManifest(
            SharedStore.AccountsManifest(
                activeId: activeId,
                accounts: entries,
                widgetAccountId: widgetAccountId
            )
        )
    }
    func notifyManifestChanged() { syncManifestToSharedStore() }

    private func migrateLegacyIfNeeded() {
        guard profiles.isEmpty else { return }
        let legacyQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: "sessionKey",
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(legacyQuery as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return }

        let orgId = UserDefaults.standard.string(forKey: "com.tokentracker.orgId") ?? ""
        let profile = AccountProfile(id: UUID(), name: "Claude.ai", orgId: orgId)
        tokenCache[profile.id] = token
        // Only delete legacy item if new write succeeds
        guard (try? writeAllTokensToKeychain()) != nil else {
            tokenCache.removeValue(forKey: profile.id)
            return
        }
        SecItemDelete(legacyQuery as CFDictionary)
        profiles = [profile]
        saveProfiles()
        activeId = profile.id
        saveActiveId()
    }

    /// If UserDefaults has profiles but Keychain has no tokens for any of them,
    /// the app was likely reinstalled. Purge stale metadata so login starts fresh.
    private func purgeStaleProfilesIfNeeded() {
        guard !profiles.isEmpty, tokenCache.isEmpty else { return }
        profiles = []
        activeId = nil
        UserDefaults.standard.removeObject(forKey: profilesKey)
        UserDefaults.standard.removeObject(forKey: activeKey)
        UserDefaults.standard.removeObject(forKey: "com.tokentracker.orgId")
    }

    private func repairActiveProfileIfNeeded() {
        if let activeId,
           profiles.contains(where: { $0.id == activeId }),
           tokenCache[activeId] != nil {
            return
        }

        activeId = profiles.first { tokenCache[$0.id] != nil }?.id
        saveActiveId()
    }

    enum AccountStoreError: Error {
        case saveFailed(OSStatus)
    }
}
