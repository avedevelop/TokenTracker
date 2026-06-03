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

    func test_projectInsights_aggregatesDuplicateProjectNames() {
        let current = [
            ProjectUsage(name: "TokenTracker", tokens: 7_000, cost: 1.20),
            ProjectUsage(name: "TokenTracker", tokens: 3_000, cost: 0.80)
        ]
        let previous = [
            ProjectUsage(name: "TokenTracker", tokens: 4_000, cost: 0.50),
            ProjectUsage(name: "TokenTracker", tokens: 1_000, cost: 0.50)
        ]

        let insights = UsageAnalytics.projectInsights(current: current, previous: previous)

        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights[0].tokens.current, 10_000, accuracy: 0.001)
        XCTAssertEqual(insights[0].tokens.previous, 5_000, accuracy: 0.001)
        XCTAssertEqual(insights[0].cost.current, 2.00, accuracy: 0.001)
        XCTAssertEqual(insights[0].cost.previous, 1.00, accuracy: 0.001)
    }

    func test_projectInsights_doesNotRoundTokenThresholdIntoSpike() {
        let current = [
            ProjectUsage(name: "Boundary", tokens: 6_001, cost: 0.20)
        ]
        let previous = [
            ProjectUsage(name: "Boundary", tokens: 4_001, cost: 0.20)
        ]

        let insights = UsageAnalytics.projectInsights(current: current, previous: previous)

        XCTAssertFalse(insights[0].isSpike)
    }

    func test_dayRecord_decodesOldJSONWithoutProjects() throws {
        let json = """
        {
          "date": "2026-06-03",
          "cost": 1.25,
          "tokens": 12000,
          "sessions": 3,
          "cacheHitRate": 0.42,
          "maxFiveHourPct": 66,
          "maxWeeklyPct": 12
        }
        """

        let record = try JSONDecoder().decode(DayRecord.self, from: Data(json.utf8))

        XCTAssertEqual(record.date, "2026-06-03")
        XCTAssertNil(record.projects)
    }

    func test_insightsPeriodDataSplitsCurrentAndPreviousPeriods() {
        let records = (1...6).map { day in
            DayRecord(
                date: String(format: "2026-06-%02d", day),
                cost: Double(day),
                tokens: day * 100,
                sessions: day,
                cacheHitRate: 0,
                maxFiveHourPct: Double(day * 10),
                maxWeeklyPct: 0,
                projects: nil
            )
        }

        let data = InsightsPeriodData(records: records, periodDays: 3)

        XCTAssertEqual(data.selectedRecords.map(\.date), ["2026-06-04", "2026-06-05", "2026-06-06"])
        XCTAssertEqual(data.previousRecords.map(\.date), ["2026-06-01", "2026-06-02", "2026-06-03"])
        XCTAssertEqual(data.totalCost, 15, accuracy: 0.001)
        XCTAssertEqual(data.totalTokens, 1500)
        XCTAssertEqual(data.totalSessions, 15)
        XCTAssertEqual(data.peakFiveHourPct, 60, accuracy: 0.001)
        XCTAssertEqual(data.costComparison.delta, 9, accuracy: 0.001)
    }

    func test_insightsPeriodDataUsesCalendarWindowsForSparseHistory() {
        let records = [
            makeRecord(date: "2026-05-01", cost: 100, tokens: 10000, sessions: 10),
            makeRecord(date: "2026-05-26", cost: 2, tokens: 200, sessions: 2),
            makeRecord(date: "2026-05-30", cost: 3, tokens: 300, sessions: 3),
            makeRecord(date: "2026-06-01", cost: 5, tokens: 500, sessions: 5),
            makeRecord(date: "2026-06-03", cost: 7, tokens: 700, sessions: 7)
        ]

        let data = InsightsPeriodData(records: records, periodDays: 7)

        XCTAssertEqual(data.selectedRecords.map(\.date), ["2026-06-01", "2026-06-03"])
        XCTAssertEqual(data.previousRecords.map(\.date), ["2026-05-26", "2026-05-30"])
        XCTAssertEqual(data.totalCost, 12, accuracy: 0.001)
        XCTAssertEqual(data.costComparison.previous, 5, accuracy: 0.001)
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

private func makeRecord(date: String, cost: Double, tokens: Int, sessions: Int) -> DayRecord {
    DayRecord(
        date: date,
        cost: cost,
        tokens: tokens,
        sessions: sessions,
        cacheHitRate: 0,
        maxFiveHourPct: 0,
        maxWeeklyPct: 0,
        projects: nil
    )
}
