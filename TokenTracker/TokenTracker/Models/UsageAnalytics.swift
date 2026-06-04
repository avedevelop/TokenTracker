import Foundation

enum UsageAnalytics {
    static let criticalFiveHourThreshold = 95.0
    static let criticalWeeklyThreshold = 90.0
    static let watchFiveHourThreshold = 70.0
    static let watchWeeklyThreshold = 65.0
    static let widgetFreshnessInterval: TimeInterval = 2 * 3600

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

struct WidgetHealth: Equatable {
    enum State: Equatable {
        case ready
        case stale
        case noAccount
        case noData
    }

    let state: State
    let freshestSnapshotAt: Date?
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

struct PeriodComparison: Equatable {
    let current: Double
    let previous: Double
    let delta: Double
    let percentChange: Double?
}

struct ProjectInsight: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let tokens: PeriodComparison
    let cost: PeriodComparison
    let isSpike: Bool
}

extension UsageAnalytics {
    static func widgetHealth(
        usage: UsageData,
        manifest: SharedStore.AccountsManifest,
        now: Date = Date()
    ) -> WidgetHealth {
        guard manifest.activeId != nil || !manifest.accounts.isEmpty else {
            return WidgetHealth(state: .noAccount, freshestSnapshotAt: nil)
        }

        let freshestSnapshotAt = freshestDate(usage.tokensUpdatedAt, usage.limitsUpdatedAt)
        guard let freshestSnapshotAt else {
            return WidgetHealth(state: .noData, freshestSnapshotAt: nil)
        }

        if now.timeIntervalSince(freshestSnapshotAt) > widgetFreshnessInterval {
            return WidgetHealth(state: .stale, freshestSnapshotAt: freshestSnapshotAt)
        }

        return WidgetHealth(state: .ready, freshestSnapshotAt: freshestSnapshotAt)
    }

    static func compare(current: Double, previous: Double) -> PeriodComparison {
        PeriodComparison(
            current: current,
            previous: previous,
            delta: current - previous,
            percentChange: previous == 0 ? nil : ((current - previous) / previous) * 100
        )
    }

    static func projectInsights(current: [ProjectUsage], previous: [ProjectUsage]) -> [ProjectInsight] {
        let currentProjects = aggregateProjects(current)
        let previousByName = Dictionary(uniqueKeysWithValues: aggregateProjects(previous).map { ($0.name, $0) })
        return currentProjects.map { project in
            let old = previousByName[project.name] ?? ProjectUsage(name: project.name, tokens: 0, cost: 0)
            let tokenComparison = compare(current: Double(project.tokens), previous: Double(old.tokens))
            let costComparison = compare(current: project.cost, previous: old.cost)
            let spike = isSpike(current: project, previous: old)
            return ProjectInsight(name: project.name, tokens: tokenComparison, cost: costComparison, isSpike: spike)
        }
        .sorted { lhs, rhs in
            lhs.cost.current == rhs.cost.current
                ? lhs.tokens.current > rhs.tokens.current
                : lhs.cost.current > rhs.cost.current
        }
    }

    private static func aggregateProjects(_ projects: [ProjectUsage]) -> [ProjectUsage] {
        let totals = projects.reduce(into: [String: (tokens: Int, cost: Double)]()) { result, project in
            result[project.name, default: (tokens: 0, cost: 0)].tokens += project.tokens
            result[project.name, default: (tokens: 0, cost: 0)].cost += project.cost
        }
        return totals.map { name, total in
            ProjectUsage(name: name, tokens: total.tokens, cost: total.cost)
        }
    }

    private static func freshestDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private static func isSpike(current: ProjectUsage, previous: ProjectUsage) -> Bool {
        guard previous.cost >= 0.10 || previous.tokens >= 1_000 else {
            return current.cost >= 1.0 || current.tokens >= 10_000
        }
        let costSpike = current.cost >= previous.cost * 1.5 && current.cost - previous.cost >= 0.25
        let tokenSpike = Double(current.tokens) >= Double(previous.tokens) * 1.5 && current.tokens - previous.tokens >= 2_000
        return costSpike || tokenSpike
    }
}
