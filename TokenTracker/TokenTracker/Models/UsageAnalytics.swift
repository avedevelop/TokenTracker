import Foundation

enum UsageAnalytics {
    static let criticalFiveHourThreshold = 95.0
    static let criticalWeeklyThreshold = 90.0
    static let watchFiveHourThreshold = 70.0
    static let watchWeeklyThreshold = 65.0

    static func status(for usage: UsageData, history: [DayRecord], now: Date = Date()) -> UsageStatus {
        guard let limits = usage.limits else {
            return UsageStatus(
                level: .watch,
                primaryMetric: .limits,
                title: L10n.s("Лимиты недоступны", "Limits unavailable"),
                reason: L10n.s("Нет свежих данных по лимитам", "No fresh limit data"),
                recommendation: L10n.s("Синхронизируйте данные или проверьте Org ID", "Sync data or check Org ID")
            )
        }

        if limits.fiveHourUtilization >= criticalFiveHourThreshold {
            return UsageStatus(
                level: .critical,
                primaryMetric: .fiveHour,
                title: L10n.s("Критично", "Critical"),
                reason: L10n.s("5-часовой лимит почти исчерпан", "5-hour limit is nearly exhausted"),
                recommendation: L10n.s("Лучше дождаться reset перед активной работой", "Wait for reset before heavy work")
            )
        }

        if limits.weeklyUtilization >= criticalWeeklyThreshold {
            return UsageStatus(
                level: .critical,
                primaryMetric: .weekly,
                title: L10n.s("Критично", "Critical"),
                reason: L10n.s("Недельный лимит близок к максимуму", "Weekly limit is close to max"),
                recommendation: L10n.s("Планируйте работу аккуратнее до недельного reset", "Plan work carefully until weekly reset")
            )
        }

        if limits.fiveHourUtilization >= watchFiveHourThreshold || projectedExhaustsBeforeReset(limits: limits, now: now) {
            return UsageStatus(
                level: .watch,
                primaryMetric: .fiveHour,
                title: L10n.s("Следить", "Watch"),
                reason: L10n.s("5-часовой лимит расходуется быстро", "5-hour limit is climbing quickly"),
                recommendation: L10n.s("Можно работать, но лучше избегать длинных тяжёлых сессий", "You can work, but avoid long heavy sessions")
            )
        }

        if limits.weeklyUtilization >= watchWeeklyThreshold {
            return UsageStatus(
                level: .watch,
                primaryMetric: .weekly,
                title: L10n.s("Следить", "Watch"),
                reason: L10n.s("Недельный лимит повышен", "Weekly limit is elevated"),
                recommendation: L10n.s("Следите за темпом до конца периода", "Watch the pace until the period ends")
            )
        }

        return UsageStatus(
            level: .safe,
            primaryMetric: .none,
            title: L10n.s("Безопасно", "Safe"),
            reason: L10n.s("Лимиты в норме", "Limits look normal"),
            recommendation: L10n.s("Хорошее окно для работы", "Good window to work")
        )
    }

    private static func projectedExhaustsBeforeReset(limits: UsageData.Limits, now: Date) -> Bool {
        guard let reset = limits.fiveHourResetsAt else { return false }
        let hoursUntilReset = max(reset.timeIntervalSince(now) / 3600, 0.25)
        let remaining = max(100 - limits.fiveHourUtilization, 0)
        let burnPerHour = limits.fiveHourUtilization / max(5 - hoursUntilReset, 1)
        guard burnPerHour > 0 else { return false }
        let hoursToExhaustion = remaining / burnPerHour
        return hoursToExhaustion < hoursUntilReset
    }
}

struct UsageStatus: Equatable {
    enum Level: Equatable {
        case safe
        case watch
        case critical
    }

    enum Metric: Equatable {
        case none
        case limits
        case fiveHour
        case weekly
        case cost
        case tokens
    }

    let level: Level
    let primaryMetric: Metric
    let title: String
    let reason: String
    let recommendation: String
}
