import XCTest
@testable import TokenTracker

final class SharedStoreTests: XCTestCase {
    func test_usageData_emptyHasZeroTokens() {
        let data = UsageData.empty
        XCTAssertEqual(data.tokensToday, 0)
        XCTAssertEqual(data.costToday, 0.0)
        XCTAssertEqual(data.sessionsToday, 0)
        XCTAssertNil(data.limits)
        XCTAssertEqual(data.hourlyUsage.count, 24)
    }

    func test_usageData_roundtripsJSON() throws {
        var data = UsageData.empty
        data.tokensToday = 12345
        data.costToday = 1.23
        data.limits = UsageData.Limits(
            fiveHourUtilization: 10.0,
            fiveHourResetsAt: nil,
            weeklyUtilization: 20.0,
            weeklyResetsAt: nil,
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: nil,
            extraUsageLimit: nil,
            extraUsageEnabled: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let json = try encoder.encode(data)
        let decoded = try decoder.decode(UsageData.self, from: json)

        XCTAssertEqual(decoded.tokensToday, 12345)
        XCTAssertEqual(decoded.costToday, 1.23, accuracy: 0.001)
        XCTAssertEqual(decoded.limits?.fiveHourUtilization ?? -1, 10.0, accuracy: 0.001)
        XCTAssertEqual(decoded.limits?.weeklyUtilization ?? -1, 20.0, accuracy: 0.001)
        XCTAssertNil(decoded.limits?.sonnetUtilization)
    }

    func test_sharedStore_writeThenRead_returnsData() throws {
        var data = UsageData.empty
        data.tokensToday = 999
        data.costToday = 9.99

        try SharedStore.write(data)
        let read = SharedStore.read()

        XCTAssertEqual(read.tokensToday, 999)
        XCTAssertEqual(read.costToday, 9.99, accuracy: 0.001)
    }

    func test_sharedStore_read_whenNoFile_returnsEmpty() {
        try? FileManager.default.removeItem(at: SharedStore.fileURL)
        let data = SharedStore.read()
        XCTAssertEqual(data.tokensToday, 0)
    }

    func test_preservedWidgetAccountId_keepsExistingAccountOnly() {
        let kept = UUID()
        let removed = UUID()
        let accounts = [SharedStore.AccountListEntry(id: kept, name: "Claude.ai")]

        XCTAssertEqual(SharedStore.preservedWidgetAccountId(kept, accounts: accounts), kept)
        XCTAssertNil(SharedStore.preservedWidgetAccountId(removed, accounts: accounts))
        XCTAssertNil(SharedStore.preservedWidgetAccountId(nil, accounts: accounts))
    }
}
