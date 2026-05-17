import Foundation

// Widget-local localization (mirrors main app L10n logic)
enum WidgetL10n {
    static var isRussian: Bool {
        let lang = Locale.preferredLanguages.first ?? ""
        return lang.hasPrefix("ru") || lang.hasPrefix("uk") || lang.hasPrefix("be")
    }
    static func s(_ ru: String, _ en: String) -> String { isRussian ? ru : en }

    static var now: String       { s("сейчас", "now") }
    static var updated: String   { s("обновлено", "updated") }
    static var sessions: String  { s("сессий", "sessions") }
    static var tokens: String    { s("токенов", "tokens") }
    static var cache: String     { s("кэш", "cache") }

    static func resetIn(h: Int, m: Int) -> String {
        if h > 0 { return s("через \(h)ч \(m)м", "in \(h)h \(m)m") }
        return s("через \(m)м", "in \(m)m")
    }

    static var fiveHour: String  { s("5-часовой", "5-hour") }
    static var weekly: String    { s("Недельный", "Weekly") }
    static var loginForLimits: String { s("Войдите для лимитов", "Log in for limits") }
    static var week: String      { s("Неделя", "Weekly") }
}
