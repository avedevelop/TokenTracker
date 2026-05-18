import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
    let usage: UsageData
    let accountName: String?
}

struct UsageTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = SelectAccountIntent
    typealias Entry = SimpleEntry

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static func fetchUsage(for account: AccountEntity) async -> UsageData {
        let urlStr: String
        if account.id != "active" {
            urlStr = "http://localhost:51234/usage?account=\(account.id)"
        } else {
            urlStr = "http://localhost:51234/usage"
        }
        guard let url = URL(string: urlStr) else { return .preview }
        if let (data, response) = try? await URLSession.shared.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let usage = try? decoder.decode(UsageData.self, from: data) {
            return usage
        }
        return .preview
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now, usage: .preview, accountName: nil)
    }

    func snapshot(for configuration: SelectAccountIntent, in context: Context) async -> SimpleEntry {
        let usage = await Self.fetchUsage(for: configuration.account)
        return SimpleEntry(date: .now, usage: usage, accountName: configuration.account.name)
    }

    func timeline(for configuration: SelectAccountIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let usage = await Self.fetchUsage(for: configuration.account)
        let entry = SimpleEntry(date: .now, usage: usage, accountName: configuration.account.name)
        let resetsAt = usage.limits?.fiveHourResetsAt
        let nextRefreshInterval: Int
        if let r = resetsAt, r.timeIntervalSinceNow < 3600 {
            nextRefreshInterval = 5
        } else {
            nextRefreshInterval = 1
        }
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: nextRefreshInterval, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextRefresh))
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
    let kind: String = "TokenTrackerWidgetV2"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectAccountIntent.self,
            provider: UsageTimelineProvider()
        ) { entry in
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
