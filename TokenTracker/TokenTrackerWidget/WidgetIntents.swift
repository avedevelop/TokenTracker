import AppIntents
import WidgetKit

struct SyncIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Usage"
    static var description = IntentDescription("Refresh token usage data")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
