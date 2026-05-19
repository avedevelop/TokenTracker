import AppIntents
import WidgetKit
import Foundation

struct SyncIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Usage"
    static var description = IntentDescription("Refresh token usage data")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Account selection

struct AccountEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Account")
    }
    static var defaultQuery = AccountEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

struct AccountEntityQuery: EntityQuery {
    func entities(for identifiers: [AccountEntity.ID]) async throws -> [AccountEntity] {
        let all = await Self.all()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [AccountEntity] {
        await Self.all()
    }

    static func all() async -> [AccountEntity] {
        var list = [AccountEntity(id: "active", name: "Active account")]
        guard let url = URL(string: "http://127.0.0.1:51234/accounts"),
              let (data, _) = try? await URLSession.shared.data(from: url)
        else { return list }
        struct Entry: Decodable { let id: UUID; let name: String }
        struct Manifest: Decodable { let accounts: [Entry] }
        if let m = try? JSONDecoder().decode(Manifest.self, from: data) {
            list += m.accounts.map { AccountEntity(id: $0.id.uuidString, name: $0.name) }
        }
        return list
    }
}

struct SelectAccountIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Account"
    static var description = IntentDescription("Choose which Claude account to display")

    // Non-optional with default — matches Apple sample code pattern
    @Parameter(title: "Account", default: AccountEntity(id: "active", name: "Active account"))
    var account: AccountEntity

    init() {
        account = AccountEntity(id: "active", name: "Active account")
    }

    init(account: AccountEntity) {
        self.account = account
    }
}
