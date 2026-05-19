import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
    let usage: UsageData
}

struct UsageTimelineProvider: TimelineProvider {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static func fetchUsage() async -> UsageData {
        guard let url = URL(string: "http://127.0.0.1:51234/usage") else { return .preview }
        if let (data, response) = try? await URLSession.shared.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let usage = try? decoder.decode(UsageData.self, from: data) {
            return usage
        }
        return .preview
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now, usage: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        Task {
            let usage = await Self.fetchUsage()
            completion(SimpleEntry(date: .now, usage: usage))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task {
            let usage = await Self.fetchUsage()
            let entry = SimpleEntry(date: .now, usage: usage)
            let resetsAt = usage.limits?.fiveHourResetsAt
            let nextRefreshInterval: Int
            if let r = resetsAt, r.timeIntervalSinceNow < 3600 {
                nextRefreshInterval = 5
            } else {
                nextRefreshInterval = 1
            }
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: nextRefreshInterval, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

struct TokenTrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SimpleEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(usage: entry.usage)
        case .systemMedium: MediumWidgetView(usage: entry.usage)
        case .systemLarge:  LargeWidgetView(usage: entry.usage)
        default:            SmallWidgetView(usage: entry.usage)
        }
    }
}

struct TokenTrackerWidget: Widget {
    let kind: String = "TokenTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            TokenTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TokenTracker")
        .description("Отслеживание токенов Claude в реальном времени")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct TokenTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TokenTrackerWidget()
    }
}
