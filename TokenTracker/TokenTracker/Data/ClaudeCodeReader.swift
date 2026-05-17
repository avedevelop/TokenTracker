import Foundation
import AppKit

final class ClaudeCodeReader {
    // Sonnet 4.6 pricing per token
    private static let inputPrice     = 3.00    / 1_000_000
    private static let outputPrice    = 15.00   / 1_000_000
    private static let cacheCreatePx  = 3.75    / 1_000_000
    private static let cacheReadPx    = 0.30    / 1_000_000

    private static let bookmarkKey = "com.tokentracker.claudeProjectsBookmark"

    /// Returns the user-selected projects dir (from security-scoped bookmark),
    /// or falls back to the default path if the app is not sandboxed.
    static var defaultProjectsDir: URL {
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData,
                                  options: URL.BookmarkResolutionOptions.withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale),
               !isStale {
                return url
            }
        }
        // Fallback for non-sandboxed / first launch
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    /// Show NSOpenPanel and store a security-scoped bookmark to ~/.claude/projects.
    /// Returns true if user selected the folder.
    @MainActor
    static func requestAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.message = "TokenTracker needs access to your Claude Code data.\nPlease select the ~/.claude/projects folder."
        panel.prompt = "Allow Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        if let bookmark = try? url.bookmarkData(options: URL.BookmarkCreationOptions.withSecurityScope,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        }
        return true
    }

    static var hasAccess: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    static func readTodayUsage(projectsDir: URL? = nil) -> UsageData {
        let projectsDir = projectsDir ?? defaultProjectsDir
        _ = projectsDir.startAccessingSecurityScopedResource()
        defer { projectsDir.stopAccessingSecurityScopedResource() }
        return _readTodayUsage(projectsDir: projectsDir)
    }

    private static func _readTodayUsage(projectsDir: URL) -> UsageData {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        var totalInput = 0
        var totalOutput = 0
        var totalCacheCreate = 0
        var totalCacheRead = 0
        var sessions = Set<String>()
        var hourlyUsage = Array(repeating: 0, count: 24)
        var projectTokens: [String: Int] = [:]
        var projectCost: [String: Double] = [:]

        let projectDirs = (try? FileManager.default.contentsOfDirectory(
            at: projectsDir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ))?.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true } ?? []

        for projectDir in projectDirs {
            let projectName = friendlyProjectName(projectDir.lastPathComponent)
            for fileURL in jsonlFiles(in: projectDir) {
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                for line in content.components(separatedBy: "\n") where !line.isEmpty {
                    guard let data = line.data(using: .utf8),
                          let entry = try? JSONDecoder().decode(ClaudeEntry.self, from: data),
                          entry.type == "assistant",
                          let usage = entry.message?.usage,
                          let tsStr = entry.timestamp,
                          let date = parseISO8601(tsStr),
                          date >= startOfDay
                    else { continue }

                    let tokens = usage.inputTokens + usage.outputTokens
                    let entryCost = Double(usage.inputTokens) * inputPrice
                                  + Double(usage.outputTokens) * outputPrice
                                  + Double(usage.cacheCreationInputTokens) * cacheCreatePx
                                  + Double(usage.cacheReadInputTokens) * cacheReadPx

                    let hour = calendar.component(.hour, from: date)
                    hourlyUsage[hour] += tokens
                    if let sid = entry.sessionId { sessions.insert(sid) }

                    totalInput       += usage.inputTokens
                    totalOutput      += usage.outputTokens
                    totalCacheCreate += usage.cacheCreationInputTokens
                    totalCacheRead   += usage.cacheReadInputTokens

                    projectTokens[projectName, default: 0] += tokens
                    projectCost[projectName, default: 0]   += entryCost
                }
            }
        }

        let cost = Double(totalInput)       * inputPrice
                 + Double(totalOutput)      * outputPrice
                 + Double(totalCacheCreate) * cacheCreatePx
                 + Double(totalCacheRead)   * cacheReadPx

        let cacheHitDenominator = totalInput + totalOutput + totalCacheRead
        let cacheHit = cacheHitDenominator > 0 ? Double(totalCacheRead) / Double(cacheHitDenominator) : 0

        let topProjects = projectTokens
            .map { ProjectUsage(name: $0.key, tokens: $0.value, cost: projectCost[$0.key] ?? 0) }
            .filter { $0.tokens > 0 }
            .sorted { $0.tokens > $1.tokens }
            .prefix(5)
            .map { $0 }

        var result = UsageData.empty
        result.tokensToday    = totalInput + totalOutput
        result.costToday      = cost
        result.sessionsToday  = sessions.count
        result.cacheHitRate   = cacheHit
        result.hourlyUsage    = hourlyUsage
        result.topProjects    = topProjects
        result.tokensUpdatedAt = Date()
        return result
    }

    private static func friendlyProjectName(_ folderName: String) -> String {
        // ~/.claude/projects stores folder names as path-with-dashes, e.g. "-Users-vlad-dev-my-project"
        // Extract the last meaningful path component
        let parts = folderName.split(separator: "-").map(String.init).filter { !$0.isEmpty }
        return parts.last ?? folderName
    }

    private static func jsonlFiles(in dir: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }
}

// MARK: - Private JSONL models

private struct ClaudeEntry: Decodable {
    let type: String
    let timestamp: String?
    let sessionId: String?
    let message: Message?

    struct Message: Decodable {
        let usage: Usage?
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationInputTokens: Int
        let cacheReadInputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens             = "input_tokens"
            case outputTokens            = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens    = "cache_read_input_tokens"
        }
    }
}
