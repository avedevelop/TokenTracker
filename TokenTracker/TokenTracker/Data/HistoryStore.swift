import Foundation

struct DayRecord: Codable, Identifiable {
    var id: String { date }
    let date: String          // yyyy-MM-dd
    let cost: Double
    let tokens: Int
    let sessions: Int
    let cacheHitRate: Double
    let maxFiveHourPct: Double
    let maxWeeklyPct: Double
}

final class HistoryStore {
    static let shared = HistoryStore()
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.tokentracker")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
    }

    func load() -> [DayRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([DayRecord].self, from: data) else { return [] }
        return records.sorted { $0.date < $1.date }
    }

    func save(snapshot: DayRecord) {
        var records = load()
        records.removeAll { $0.date == snapshot.date }
        records.append(snapshot)
        if records.count > 90 { records = Array(records.suffix(90)) }
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL)
        }
    }

    static func snapshotToday(from usage: UsageData, limits: UsageData.Limits?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let record = DayRecord(
            date: today,
            cost: usage.costToday,
            tokens: usage.tokensToday,
            sessions: usage.sessionsToday,
            cacheHitRate: usage.cacheHitRate,
            maxFiveHourPct: limits?.fiveHourUtilization ?? 0,
            maxWeeklyPct: limits?.weeklyUtilization ?? 0
        )
        shared.save(snapshot: record)
    }
}
