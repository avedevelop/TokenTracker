import Foundation
import WidgetKit

final class SharedStore {
    /// Application Support directory used by the main app to persist usage data.
    /// The widget reads this data via the localhost HTTP server (LocalServer).
    static let directory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.tokentracker")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var fileURL: URL {
        directory.appendingPathComponent("usage.json")
    }

    static var accountsFileURL: URL {
        directory.appendingPathComponent("accounts.json")
    }

    static func fileURL(forAccount id: UUID) -> URL {
        directory.appendingPathComponent("usage-\(id.uuidString).json")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Active account snapshot (legacy file, kept for backward compat)

    static func read() -> UsageData {
        guard let data = try? Data(contentsOf: fileURL),
              let usage = try? decoder.decode(UsageData.self, from: data)
        else { return .empty }
        return usage
    }

    static func write(_ usage: UsageData) throws {
        let data = try encoder.encode(usage)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Per-account snapshots (for widget account selection)

    static func readAccount(id: UUID) -> UsageData {
        guard let data = try? Data(contentsOf: fileURL(forAccount: id)),
              let usage = try? decoder.decode(UsageData.self, from: data)
        else { return .empty }
        return usage
    }

    static func writeAccount(_ usage: UsageData, id: UUID) {
        guard let data = try? encoder.encode(usage) else { return }
        try? data.write(to: fileURL(forAccount: id), options: .atomic)
    }

    static func deleteAccount(id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(forAccount: id))
    }

    // MARK: - Accounts manifest (id + display name + active flag)

    struct AccountListEntry: Codable, Hashable {
        let id: UUID
        let name: String
    }

    struct AccountsManifest: Codable {
        var activeId: UUID?
        var accounts: [AccountListEntry]
        /// The account the widget should display. nil = follow active account.
        var widgetAccountId: UUID?
    }

    static func readAccountsManifest() -> AccountsManifest {
        guard let data = try? Data(contentsOf: accountsFileURL),
              let m = try? decoder.decode(AccountsManifest.self, from: data)
        else { return AccountsManifest(activeId: nil, accounts: []) }
        return m
    }

    static func writeAccountsManifest(_ manifest: AccountsManifest) {
        guard let data = try? encoder.encode(manifest) else { return }
        try? data.write(to: accountsFileURL, options: .atomic)
    }

    static func setWidgetAccount(_ id: UUID?) {
        var m = readAccountsManifest()
        m.widgetAccountId = id
        writeAccountsManifest(m)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Bulk updates (writes to legacy file AND per-account file)

    static func updateTokens(from newData: UsageData) throws {
        var stored = read()
        stored.tokensToday = newData.tokensToday
        stored.costToday = newData.costToday
        stored.sessionsToday = newData.sessionsToday
        stored.cacheHitRate = newData.cacheHitRate
        stored.hourlyUsage = newData.hourlyUsage
        stored.topProjects = newData.topProjects
        stored.tokensUpdatedAt = Date()
        try write(stored)
        // Mirror to active account file
        if let id = readAccountsManifest().activeId {
            writeAccount(stored, id: id)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updateLimits(_ limits: UsageData.Limits) throws {
        var stored = read()
        stored.limits = limits
        stored.limitsUpdatedAt = Date()
        try write(stored)
        if let id = readAccountsManifest().activeId {
            writeAccount(stored, id: id)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Writes limits for a specific account (used when polling non-active accounts).
    static func updateLimits(_ limits: UsageData.Limits, forAccount id: UUID) {
        var stored = readAccount(id: id)
        stored.limits = limits
        stored.limitsUpdatedAt = Date()
        writeAccount(stored, id: id)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
