import Foundation

// MARK: - Provider

enum AIProvider: String, Codable, CaseIterable {
    case claudeCode = "Claude Code"
    case claudeAPI = "Claude API"
    case openAI    = "OpenAI"
    case gemini    = "Gemini"

    var icon: String {
        switch self {
        case .claudeCode, .claudeAPI: return "claude"
        case .openAI:  return "openai"
        case .gemini:  return "gemini"
        }
    }

    var shortName: String { rawValue }
}

// MARK: - UsageData

struct UsageData: Codable, Equatable {
    var provider: AIProvider = .claudeCode
    var tokensToday: Int
    var costToday: Double
    var sessionsToday: Int
    var cacheHitRate: Double
    var limits: Limits?
    var hourlyUsage: [Int]
    var limitsUpdatedAt: Date?
    var tokensUpdatedAt: Date?

    struct Limits: Codable, Equatable {
        // Five-hour message limit
        var fiveHourUtilization: Double       // 0-100
        var fiveHourResetsAt: Date?

        // Seven-day message limit
        var weeklyUtilization: Double         // 0-100
        var weeklyResetsAt: Date?

        // Max subscription per-model limits (nil if not Max)
        var sonnetUtilization: Double?
        var opusUtilization: Double?

        // Extra usage credits
        var extraUsageUsed: Double?           // USD spent
        var extraUsageLimit: Double?          // USD limit
        var extraUsageEnabled: Bool

        var fiveHourPercent: Double { fiveHourUtilization / 100.0 }
        var weeklyPercent: Double { weeklyUtilization / 100.0 }
    }

    static let empty = UsageData(
        tokensToday: 0,
        costToday: 0,
        sessionsToday: 0,
        cacheHitRate: 0,
        limits: nil,
        hourlyUsage: Array(repeating: 0, count: 24),
        limitsUpdatedAt: nil,
        tokensUpdatedAt: nil
    )

    static let preview = UsageData(
        tokensToday: 127_482,
        costToday: 2.34,
        sessionsToday: 8,
        cacheHitRate: 0.83,
        limits: Limits(
            fiveHourUtilization: 97.0,
            fiveHourResetsAt: Date().addingTimeInterval(3600),
            weeklyUtilization: 9.0,
            weeklyResetsAt: Date().addingTimeInterval(86400 * 2),
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: 575.0,
            extraUsageLimit: 1000.0,
            extraUsageEnabled: true
        ),
        hourlyUsage: [0,0,0,0,0,0,8,15,30,55,80,100,70,43,58,33,18,5,0,0,0,0,0,0],
        limitsUpdatedAt: .now,
        tokensUpdatedAt: .now
    )
}
