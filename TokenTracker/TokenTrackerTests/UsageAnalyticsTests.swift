import XCTest
@testable import TokenTracker

final class UsageAnalyticsTests: XCTestCase {
    func test_usageStatus_isCriticalWhenFiveHourIsNearExhaustion() {
        let limits = UsageData.Limits(
            fiveHourUtilization: 96,
            fiveHourResetsAt: Date().addingTimeInterval(3600),
            weeklyUtilization: 20,
            weeklyResetsAt: Date().addingTimeInterval(86400),
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: nil,
            extraUsageLimit: nil,
            extraUsageEnabled: false
        )

        let status = UsageAnalytics.status(for: .empty.withLimits(limits), history: [], now: Date())

        XCTAssertEqual(status.level, .critical)
        XCTAssertEqual(status.primaryMetric, .fiveHour)
    }

    func test_usageStatus_isWatchWhenProjectedExhaustionIsBeforeReset() {
        let now = Date()
        let limits = UsageData.Limits(
            fiveHourUtilization: 65,
            fiveHourResetsAt: now.addingTimeInterval(4.5 * 3600),
            weeklyUtilization: 18,
            weeklyResetsAt: now.addingTimeInterval(2 * 86400),
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: nil,
            extraUsageLimit: nil,
            extraUsageEnabled: false
        )

        let status = UsageAnalytics.status(for: .empty.withLimits(limits), history: [], now: now)

        XCTAssertEqual(status.level, .watch)
        XCTAssertEqual(status.primaryMetric, .fiveHour)
    }

    func test_usageStatus_isSafeWhenLimitsAreLow() {
        let now = Date()
        let limits = UsageData.Limits(
            fiveHourUtilization: 24,
            fiveHourResetsAt: now.addingTimeInterval(3 * 3600),
            weeklyUtilization: 12,
            weeklyResetsAt: now.addingTimeInterval(3 * 86400),
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: nil,
            extraUsageLimit: nil,
            extraUsageEnabled: false
        )

        let status = UsageAnalytics.status(for: .empty.withLimits(limits), history: [], now: now)

        XCTAssertEqual(status.level, .safe)
    }
}

private extension UsageData {
    func withLimits(_ limits: UsageData.Limits) -> UsageData {
        var copy = self
        copy.limits = limits
        copy.limitsUpdatedAt = Date()
        return copy
    }
}
