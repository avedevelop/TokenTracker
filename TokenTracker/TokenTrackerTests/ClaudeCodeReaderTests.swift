import XCTest
@testable import TokenTracker

final class ClaudeCodeReaderTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_readUsage_parsesTokensFromTodaysEntries() throws {
        let todayISO = ISO8601DateFormatter().string(from: Date())
        let jsonl = """
        {"type":"assistant","timestamp":"\(todayISO)","sessionId":"sess1","message":{"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":200}}}
        {"type":"assistant","timestamp":"\(todayISO)","sessionId":"sess1","message":{"usage":{"input_tokens":200,"output_tokens":100,"cache_creation_input_tokens":500,"cache_read_input_tokens":0}}}
        """
        let file = try makeProjectFile()
        try jsonl.write(to: file, atomically: true, encoding: .utf8)

        let usage = ClaudeCodeReader.readTodayUsage(projectsDir: tempDir)

        XCTAssertEqual(usage.tokensToday, 450)  // (100+50) + (200+100)
        XCTAssertEqual(usage.sessionsToday, 1)
        XCTAssertGreaterThan(usage.costToday, 0)
        XCTAssertGreaterThan(usage.cacheHitRate, 0)
    }

    func test_readUsage_ignoresYesterdaysEntries() throws {
        let yesterday = Date().addingTimeInterval(-86400)
        let yISO = ISO8601DateFormatter().string(from: yesterday)
        let todayISO = ISO8601DateFormatter().string(from: Date())
        let jsonl = """
        {"type":"assistant","timestamp":"\(yISO)","sessionId":"old","message":{"usage":{"input_tokens":9999,"output_tokens":9999,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        {"type":"assistant","timestamp":"\(todayISO)","sessionId":"new","message":{"usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
        let file = try makeProjectFile()
        try jsonl.write(to: file, atomically: true, encoding: .utf8)

        let usage = ClaudeCodeReader.readTodayUsage(projectsDir: tempDir)

        XCTAssertEqual(usage.tokensToday, 15)
    }

    func test_readUsage_countsUniqueSessions() throws {
        let todayISO = ISO8601DateFormatter().string(from: Date())
        let jsonl = """
        {"type":"assistant","timestamp":"\(todayISO)","sessionId":"s1","message":{"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        {"type":"assistant","timestamp":"\(todayISO)","sessionId":"s2","message":{"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        {"type":"assistant","timestamp":"\(todayISO)","sessionId":"s1","message":{"usage":{"input_tokens":1,"output_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
        let file = try makeProjectFile()
        try jsonl.write(to: file, atomically: true, encoding: .utf8)

        let usage = ClaudeCodeReader.readTodayUsage(projectsDir: tempDir)

        XCTAssertEqual(usage.sessionsToday, 2)
    }

    func test_readUsage_emptyDirectory_returnsEmpty() {
        let usage = ClaudeCodeReader.readTodayUsage(projectsDir: tempDir)
        XCTAssertEqual(usage.tokensToday, 0)
        XCTAssertEqual(usage.costToday, 0)
    }

    private func makeProjectFile() throws -> URL {
        let projectDir = tempDir.appendingPathComponent("-Users-vlad-test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        return projectDir.appendingPathComponent("test.jsonl")
    }
}
