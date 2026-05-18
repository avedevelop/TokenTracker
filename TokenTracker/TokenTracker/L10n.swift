import Foundation

// Simple localization — detects system language, falls back to English
enum L10n {
    /// Russian UI for ru / uk (Ukrainian) / be (Belarusian), English for everything else
    static var isRussian: Bool {
        let lang = Locale.preferredLanguages.first ?? ""
        return lang.hasPrefix("ru") || lang.hasPrefix("uk") || lang.hasPrefix("be")
    }
    static func s(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    // MARK: - Tab names
    static var dashboard: String { s("Дашборд", "Dashboard") }
    static var account: String { s("Аккаунт", "Account") }
    static var settings: String { s("Настройки", "Settings") }

    // MARK: - Header / sync
    static var sync: String { s("Синхронизировать", "Sync") }
    static var syncing: String { s("Синхронизация…", "Syncing…") }

    // MARK: - Dashboard — limits card
    static var limits: String { s("Лимиты", "Limits") }
    static var loginForLimits: String { s("Войдите в аккаунт для отображения лимитов", "Log in to view limits") }
    static var fiveHourLabel: String { s("5-часовой", "5-hour") }
    static var weeklyLabel: String { s("Недельный", "Weekly") }

    // MARK: - Dashboard — stats card
    static var today: String { s("Сегодня", "Today") }
    static var cost: String { s("Стоимость", "Cost") }
    static var tokens: String { s("Токены", "Tokens") }
    static var sessions: String { s("Сессии", "Sessions") }
    static var cacheHit: String { s("Кэш хит", "Cache hit") }
    static var dataOutdated: String { s("Данные могут быть устаревшими", "Data may be outdated") }

    // MARK: - Dashboard — chart card
    static var dailyActivity: String { s("Активность за день", "Daily activity") }
    static var now: String { s("сейчас", "now") }

    // MARK: - Account tab
    static var orgId: String { "Org ID" }
    static var session: String { s("Сессия", "Session") }
    static var sessionKey: String { s("Ключ сессии", "Session key") }
    static var status: String { s("Статус", "Status") }
    static var statusActive: String { s("Активен", "Active") }
    static var statusUnauthorized: String { s("Не авторизован", "Unauthorized") }
    static var signOut: String { s("Выйти из аккаунта", "Sign out") }

    // MARK: - Settings tab
    static var behavior: String { s("Поведение", "Behavior") }
    static var launchAtLogin: String { s("Запуск при входе", "Launch at login") }
    static var projectsFolder: String { s("Папка проектов", "Projects folder") }
    static var notifications: String { s("Уведомления", "Notifications") }
    static var limitNotifications: String { s("Уведомления о лимитах", "Limit Notifications") }
    static var notificationThreshold: String { s("Порог уведомления", "Notification threshold") }
    static var aboutApp: String { s("О приложении", "About") }
    static var limitsRefresh: String { s("Обновление лимитов", "Limits refresh") }
    static var tokensRefresh: String { s("Обновление токенов", "Tokens refresh") }
    static var every60s: String { s("каждые 60с", "every 60s") }
    static var realtime: String { s("в реальном времени", "real-time") }
    static var version: String { s("Версия", "Version") }
    static var viewOnGitHub: String { s("Открыть на GitHub", "View on GitHub") }
    static var starOnGitHub: String { s("Звезда на GitHub", "Star on GitHub") }
    static var tagline: String {
        s(
            "Отслеживание использования Claude AI в реальном времени",
            "Real-time Claude AI usage tracker"
        )   
    }

    // MARK: - Reset label helpers
    static var resetsLabel: String { s("через", "in") }
    static var hoursShort: String { s("ч", "h") }
    static var minutesShort: String { s("м", "m") }
    static var didReset: String { s("сбросился", "reset") }
    static var agoSuffix: String { s(" назад", " ago") }

    // MARK: - Notifications (body strings)
    static func fiveHourLimitBody(percent: Int) -> String {
        s("5-часовой лимит: \(percent)% использован",
          "5-hour limit: \(percent)% used")
    }
    static func weeklyLimitBody(percent: Int) -> String {
        s("Недельный лимит: \(percent)% использован",
          "Weekly limit: \(percent)% used")
    }

    // MARK: - Onboarding
    static var onboardingSubtitle: String { s("Отслеживай использование AI в реальном времени", "Track your AI usage in real time") }
    static var onboardingNext: String { s("Далее", "Next") }
    static var onboardingStart: String { s("Начать", "Get Started") }
    static var onboardingFeaturesTitle: String { s("Возможности", "Features") }
    static var onboardingSetupTitle: String { s("Всё готово", "Ready to go") }
    static var onboardingClaudeDetected: String { s("Claude Code обнаружен ✓", "Claude Code detected ✓") }
    static var onboardingNoCredentials: String { s("Откройте приложение и войдите в аккаунт", "Open the app and log in to get started") }
    static var feat1Title: String { s("Лимиты в реальном времени", "Live Limits") }
    static var feat1Body: String { s("5-часовой и недельный лимиты Claude", "5-hour and weekly Claude limits") }
    static var feat2Title: String { s("Умные уведомления", "Smart Alerts") }
    static var feat2Body: String { s("Узнавай заранее об исчерпании лимита", "Get notified before your limit runs out") }
    static var feat3Title: String { s("История", "History") }
    static var feat3Body: String { s("7-дневная история использования", "7-day usage history") }

    // MARK: - Settings — corrected labels
    static var notificationsLabel: String { s("Уведомления", "Notifications") }
    static var aboutLabel: String { s("О приложении", "About") }

    // MARK: - Accounts / multi-account
    static var monthlyBudget: String { s("Месячный бюджет", "Monthly budget") }
    static var followSystemTheme: String { s("Системная тема", "System theme") }
    static var addAccount: String { s("Добавить аккаунт", "Add account") }
    static var switchAccount: String { s("Переключить", "Switch") }

    // MARK: - Login view
    static var connectClaude: String { s("Подключите Claude.ai", "Connect Claude.ai") }
    static var loginDescription: String {
        s(
            "TokenTracker читает лимиты напрямую из Claude.ai.\nПотребуется скопировать session token из браузера.",
            "TokenTracker reads limits directly from Claude.ai.\nYou will need to copy the session token from your browser."
        )
    }
    static var openClaudeAi: String { s("Открыть Claude.ai", "Open Claude.ai") }
    static var pasteSessionToken: String { s("Вставьте session token", "Paste session token") }
    static var back: String { s("Назад", "Back") }
    static var connect: String { s("Подключить", "Connect") }
}
