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

    func test_periodComparison_calculatesDeltaAndPercentChange() {
        let comparison = UsageAnalytics.compare(current: 15.0, previous: 10.0)

        XCTAssertEqual(comparison.current, 15.0, accuracy: 0.001)
        XCTAssertEqual(comparison.previous, 10.0, accuracy: 0.001)
        XCTAssertEqual(comparison.delta, 5.0, accuracy: 0.001)
        XCTAssertEqual(comparison.percentChange ?? 0, 50.0, accuracy: 0.001)
    }

    func test_periodComparison_handlesZeroPreviousValue() {
        let comparison = UsageAnalytics.compare(current: 15.0, previous: 0.0)

        XCTAssertNil(comparison.percentChange)
        XCTAssertEqual(comparison.delta, 15.0, accuracy: 0.001)
    }

    func test_projectInsights_marksLargeIncreaseAsSpike() {
        let current = [
            ProjectUsage(name: "TokenTracker", tokens: 15_000, cost: 3.00)
        ]
        let previous = [
            ProjectUsage(name: "TokenTracker", tokens: 5_000, cost: 1.00)
        ]

        let insights = UsageAnalytics.projectInsights(current: current, previous: previous)

        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights[0].name, "TokenTracker")
        XCTAssertTrue(insights[0].isSpike)
        XCTAssertEqual(insights[0].cost.delta, 2.0, accuracy: 0.001)
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
