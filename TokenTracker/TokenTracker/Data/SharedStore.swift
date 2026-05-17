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

    static func updateTokens(from newData: UsageData) throws {
        var stored = read()
        stored.tokensToday = newData.tokensToday
        stored.costToday = newData.costToday
        stored.sessionsToday = newData.sessionsToday
        stored.cacheHitRate = newData.cacheHitRate
        stored.hourlyUsage = newData.hourlyUsage
        stored.tokensUpdatedAt = Date()
        try write(stored)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updateLimits(_ limits: UsageData.Limits) throws {
        var stored = read()
        stored.limits = limits
        stored.limitsUpdatedAt = Date()
        try write(stored)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
