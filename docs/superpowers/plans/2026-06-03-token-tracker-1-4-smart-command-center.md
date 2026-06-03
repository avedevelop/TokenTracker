# TokenTracker 1.4.0 Smart Command Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build TokenTracker 1.4.0 as a desktop-only Smart Command Center with local usage intelligence, project insights, an enhanced Insights tab, a richer menu bar dashboard, widget health UX, and no dependency on iOS/iCloud, Anthropic API support, Apple Developer signing, or notarization.

**Architecture:** Add small pure Swift analytics models first, backed by existing `UsageData`, `HistoryStore`, and `SharedStore`. Extend history snapshots to include project usage, then compose SwiftUI cards/screens from derived values instead of embedding calculations in `SettingsView`. Upgrade the existing AppKit status item into a popover-based mini dashboard without changing WidgetKit configuration.

**Tech Stack:** Swift, SwiftUI, AppKit `NSStatusItem`/`NSPopover`, WidgetKit, XCTest, Xcode macOS 26.5 target.

---

## File Structure

- Create `TokenTracker/TokenTracker/Models/UsageAnalytics.swift`: pure derived analytics types and functions for status, period comparisons, project insights, and widget health.
- Modify `TokenTracker/TokenTracker/Models/UsageData.swift`: keep existing model, no API/iCloud additions.
- Modify `TokenTracker/TokenTracker/Data/HistoryStore.swift`: add optional project snapshots to `DayRecord` and helper functions for recent periods.
- Modify `TokenTracker/TokenTracker/Data/SharedStore.swift`: expose a small widget-health-friendly last data state through existing files only.
- Create `TokenTracker/TokenTracker/Views/Components/SmartStatusCard.swift`: top dashboard status card.
- Create `TokenTracker/TokenTracker/Views/Components/LimitIntelligenceCard.swift`: replacement for the raw limits card.
- Create `TokenTracker/TokenTracker/Views/Components/ProjectInsightsCard.swift`: dashboard project insight summary.
- Create `TokenTracker/TokenTracker/Views/Components/InsightsView.swift`: enhanced History/Insights tab content.
- Create `TokenTracker/TokenTracker/Views/Components/WidgetHealthCard.swift`: settings widget status section.
- Create `TokenTracker/TokenTracker/Views/MenuBarDashboardView.swift`: SwiftUI content for menu bar popover.
- Modify `TokenTracker/TokenTracker/Views/SettingsView.swift`: wire new cards, rename History to Insights, remove main-dashboard credits row, and use extracted views.
- Modify `TokenTracker/TokenTracker/TokenTrackerApp.swift`: replace click-to-open status icon with popover mini dashboard and quick actions.
- Modify `TokenTracker/TokenTracker/L10n.swift`: add RU/EN strings for new UI copy.
- Modify `CHANGELOG.md`, `ROADMAP.md`, and `FAQ.md`: document 1.4.0 scope and widget troubleshooting.
- Create `TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift`: status, comparison, spike, sparse history, widget health tests.
- Modify `TokenTracker/TokenTrackerTests/SharedStoreTests.swift`: add coverage for history/project snapshot compatibility if needed.

---

### Task 1: Add Pure Usage Analytics Models

**Files:**
- Create: `TokenTracker/TokenTracker/Models/UsageAnalytics.swift`
- Test: `TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift`

- [ ] **Step 1: Write failing status classification tests**

Create `TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift`:

```swift
import XCTest
@testable import TokenTracker

final class UsageAnalyticsTests: XCTestCase {
    func test_usageStatus_isCriticalWhenFiveHourIsNearExhaustion() {
        let limits = UsageData.Limits(
            fiveHourUtilization: 96,
            fiveHourResetsAt: Date().addingTimeInterval(3600),
            weeklyUtilization: 20,
            weeklyResetsAt: Date().addingTimeInterval(86400),
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: nil,
            extraUsageLimit: nil,
            extraUsageEnabled: false
        )

        let status = UsageAnalytics.status(for: .empty.withLimits(limits), history: [], now: Date())

        XCTAssertEqual(status.level, .critical)
        XCTAssertEqual(status.primaryMetric, .fiveHour)
    }

    func test_usageStatus_isWatchWhenBurnRateIsHigh() {
        let now = Date()
        let limits = UsageData.Limits(
            fiveHourUtilization: 72,
            fiveHourResetsAt: now.addingTimeInterval(4 * 3600),
            weeklyUtilization: 18,
            weeklyResetsAt: now.addingTimeInterval(2 * 86400),
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: nil,
            extraUsageLimit: nil,
            extraUsageEnabled: false
        )

        let status = UsageAnalytics.status(for: .empty.withLimits(limits), history: [], now: now)

        XCTAssertEqual(status.level, .watch)
        XCTAssertEqual(status.primaryMetric, .fiveHour)
    }

    func test_usageStatus_isSafeWhenLimitsAreLow() {
        let now = Date()
        let limits = UsageData.Limits(
            fiveHourUtilization: 24,
            fiveHourResetsAt: now.addingTimeInterval(3 * 3600),
            weeklyUtilization: 12,
            weeklyResetsAt: now.addingTimeInterval(3 * 86400),
            sonnetUtilization: nil,
            opusUtilization: nil,
            extraUsageUsed: nil,
            extraUsageLimit: nil,
            extraUsageEnabled: false
        )

        let status = UsageAnalytics.status(for: .empty.withLimits(limits), history: [], now: now)

        XCTAssertEqual(status.level, .safe)
    }
}

private extension UsageData {
    func withLimits(_ limits: UsageData.Limits) -> UsageData {
        var copy = self
        copy.limits = limits
        copy.limitsUpdatedAt = Date()
        return copy
    }
}
```

- [ ] **Step 2: Run the new tests and verify they fail**

Run:

```bash
xcodebuild test -project TokenTracker.xcodeproj -scheme TokenTracker -destination 'platform=macOS' -only-testing:TokenTrackerTests/UsageAnalyticsTests
```

Expected: FAIL because `UsageAnalytics`, `UsageStatus`, and related symbols do not exist.

- [ ] **Step 3: Add the analytics model implementation**

Create `TokenTracker/TokenTracker/Models/UsageAnalytics.swift`:

```swift
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
        return hoursToExhaustion < hoursUntilReset && limits.fiveHourUtilization >= watchFiveHourThreshold
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
```

- [ ] **Step 4: Run tests and verify status tests pass**

Run:

```bash
xcodebuild test -project TokenTracker.xcodeproj -scheme TokenTracker -destination 'platform=macOS' -only-testing:TokenTrackerTests/UsageAnalyticsTests
```

Expected: PASS for the three status tests.

- [ ] **Step 5: Commit Task 1**

```bash
git add TokenTracker/TokenTracker/Models/UsageAnalytics.swift TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift
git commit -m "feat: add usage status analytics"
```

---

### Task 2: Add Period Comparison And Project Insights

**Files:**
- Modify: `TokenTracker/TokenTracker/Models/UsageAnalytics.swift`
- Modify: `TokenTracker/TokenTracker/Data/HistoryStore.swift`
- Test: `TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift`

- [ ] **Step 1: Add failing tests for comparisons and project spikes**

Append to `UsageAnalyticsTests`:

```swift
func test_periodComparison_calculatesDeltaAndPercentChange() {
    let comparison = UsageAnalytics.compare(current: 15.0, previous: 10.0)

    XCTAssertEqual(comparison.current, 15.0, accuracy: 0.001)
    XCTAssertEqual(comparison.previous, 10.0, accuracy: 0.001)
    XCTAssertEqual(comparison.delta, 5.0, accuracy: 0.001)
    XCTAssertEqual(comparison.percentChange ?? 0, 50.0, accuracy: 0.001)
}

func test_periodComparison_handlesZeroPreviousValue() {
    let comparison = UsageAnalytics.compare(current: 15.0, previous: 0.0)

    XCTAssertNil(comparison.percentChange)
    XCTAssertEqual(comparison.delta, 15.0, accuracy: 0.001)
}

func test_projectInsights_marksLargeIncreaseAsSpike() {
    let current = [
        ProjectUsage(name: "TokenTracker", tokens: 15_000, cost: 3.00)
    ]
    let previous = [
        ProjectUsage(name: "TokenTracker", tokens: 5_000, cost: 1.00)
    ]

    let insights = UsageAnalytics.projectInsights(current: current, previous: previous)

    XCTAssertEqual(insights.count, 1)
    XCTAssertEqual(insights[0].name, "TokenTracker")
    XCTAssertTrue(insights[0].isSpike)
    XCTAssertEqual(insights[0].cost.delta, 2.0, accuracy: 0.001)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
xcodebuild test -project TokenTracker.xcodeproj -scheme TokenTracker -destination 'platform=macOS' -only-testing:TokenTrackerTests/UsageAnalyticsTests
```

Expected: FAIL because comparison and project insight APIs do not exist.

- [ ] **Step 3: Extend `DayRecord` with optional projects**

Modify `TokenTracker/TokenTracker/Data/HistoryStore.swift`:

```swift
struct DayRecord: Codable, Identifiable {
    var id: String { date }
    let date: String
    let cost: Double
    let tokens: Int
    let sessions: Int
    let cacheHitRate: Double
    let maxFiveHourPct: Double
    let maxWeeklyPct: Double
    let projects: [ProjectUsage]?
}
```

Update `snapshotToday` record creation:

```swift
let record = DayRecord(
    date: today,
    cost: usage.costToday,
    tokens: usage.tokensToday,
    sessions: usage.sessionsToday,
    cacheHitRate: usage.cacheHitRate,
    maxFiveHourPct: limits?.fiveHourUtilization ?? 0,
    maxWeeklyPct: limits?.weeklyUtilization ?? 0,
    projects: usage.topProjects
)
```

If existing tests construct `DayRecord`, update each constructor with `projects: nil`.

- [ ] **Step 4: Add comparison and insight types**

Append to `UsageAnalytics.swift`:

```swift
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
    static func compare(current: Double, previous: Double) -> PeriodComparison {
        PeriodComparison(
            current: current,
            previous: previous,
            delta: current - previous,
            percentChange: previous == 0 ? nil : ((current - previous) / previous) * 100
        )
    }

    static func projectInsights(current: [ProjectUsage], previous: [ProjectUsage]) -> [ProjectInsight] {
        let previousByName = Dictionary(uniqueKeysWithValues: previous.map { ($0.name, $0) })
        return current.map { project in
            let old = previousByName[project.name] ?? ProjectUsage(name: project.name, tokens: 0, cost: 0)
            let tokenComparison = compare(current: Double(project.tokens), previous: Double(old.tokens))
            let costComparison = compare(current: project.cost, previous: old.cost)
            let spike = isSpike(current: project, previous: old)
            return ProjectInsight(name: project.name, tokens: tokenComparison, cost: costComparison, isSpike: spike)
        }
        .sorted { lhs, rhs in lhs.cost.current == rhs.cost.current ? lhs.tokens.current > rhs.tokens.current : lhs.cost.current > rhs.cost.current }
    }

    private static func isSpike(current: ProjectUsage, previous: ProjectUsage) -> Bool {
        guard previous.cost >= 0.10 || previous.tokens >= 1_000 else { return current.cost >= 1.0 || current.tokens >= 10_000 }
        let costSpike = current.cost >= previous.cost * 1.5 && current.cost - previous.cost >= 0.25
        let tokenSpike = current.tokens >= Int(Double(previous.tokens) * 1.5) && current.tokens - previous.tokens >= 2_000
        return costSpike || tokenSpike
    }
}
```

- [ ] **Step 5: Run tests and verify they pass**

Run:

```bash
xcodebuild test -project TokenTracker.xcodeproj -scheme TokenTracker -destination 'platform=macOS' -only-testing:TokenTrackerTests/UsageAnalyticsTests
```

Expected: PASS.

- [ ] **Step 6: Commit Task 2**

```bash
git add TokenTracker/TokenTracker/Models/UsageAnalytics.swift TokenTracker/TokenTracker/Data/HistoryStore.swift TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift
git commit -m "feat: add period and project analytics"
```

---

### Task 3: Build Smart Dashboard Cards

**Files:**
- Create: `TokenTracker/TokenTracker/Views/Components/SmartStatusCard.swift`
- Create: `TokenTracker/TokenTracker/Views/Components/LimitIntelligenceCard.swift`
- Create: `TokenTracker/TokenTracker/Views/Components/ProjectInsightsCard.swift`
- Modify: `TokenTracker/TokenTracker/Views/SettingsView.swift`

- [ ] **Step 1: Add `SmartStatusCard`**

Create `TokenTracker/TokenTracker/Views/Components/SmartStatusCard.swift`:

```swift
import SwiftUI

struct SmartStatusCard: View {
    let status: UsageStatus
    let updatedAt: Date?

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 9, height: 9)
                    Text(status.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    if let updatedAt {
                        Text(relative(updatedAt))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(status.reason)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.72))

                Text(status.recommendation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var color: Color {
        switch status.level {
        case .safe: return .green
        case .watch: return .orange
        case .critical: return .red
        }
    }

    private func relative(_ date: Date) -> String {
        let seconds = max(Int(Date().timeIntervalSince(date)), 0)
        if seconds < 60 { return L10n.s("сейчас", "now") }
        if seconds < 3600 { return L10n.s("\(seconds / 60) мин назад", "\(seconds / 60)m ago") }
        return L10n.s("\(seconds / 3600) ч назад", "\(seconds / 3600)h ago")
    }
}
```

- [ ] **Step 2: Add `LimitIntelligenceCard`**

Create `TokenTracker/TokenTracker/Views/Components/LimitIntelligenceCard.swift`:

```swift
import SwiftUI

struct LimitIntelligenceCard: View {
    let usage: UsageData
    let now: Date

    var body: some View {
        DarkCard {
            VStack(spacing: 0) {
                header
                if let limits = usage.limits {
                    VStack(spacing: 12) {
                        intelligenceRow(title: L10n.fiveHourLabel, value: limits.fiveHourUtilization, reset: limits.fiveHourResetsAt)
                        intelligenceRow(title: L10n.weeklyLabel, value: limits.weeklyUtilization, reset: limits.weeklyResetsAt)
                        if let su = limits.sonnetUtilization {
                            intelligenceRow(title: L10n.s("Sonnet (7д)", "Sonnet (7d)"), value: su, reset: nil)
                        }
                        if let ou = limits.opusUtilization {
                            intelligenceRow(title: L10n.s("Opus (7д)", "Opus (7d)"), value: ou, reset: nil)
                        }
                    }
                } else {
                    Text(L10n.s("Лимиты недоступны", "Limits unavailable"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.limits)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let updated = usage.limitsUpdatedAt {
                Text(updated, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 10)
    }

    private func intelligenceRow(title: String, value: Double, reset: Date?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            ProgressView(value: min(max(value / 100, 0), 1))
            HStack {
                Text(burnLabel(value))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                if let reset {
                    Text(resetText(reset))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func burnLabel(_ value: Double) -> String {
        if value >= 90 { return L10n.s("Высокое давление", "High pressure") }
        if value >= 70 { return L10n.s("Повышенный темп", "Elevated pace") }
        return L10n.s("Нормальный темп", "Normal pace")
    }

    private func resetText(_ reset: Date) -> String {
        let minutes = max(Int(reset.timeIntervalSince(now) / 60), 0)
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? L10n.s("через \(hours)ч \(mins)м", "in \(hours)h \(mins)m") : L10n.s("через \(mins)м", "in \(mins)m")
    }
}
```

- [ ] **Step 3: Add `ProjectInsightsCard`**

Create `TokenTracker/TokenTracker/Views/Components/ProjectInsightsCard.swift`:

```swift
import SwiftUI

struct ProjectInsightsCard: View {
    let insights: [ProjectInsight]

    var body: some View {
        if !insights.isEmpty {
            DarkCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.s("Инсайты проектов", "Project insights"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(insights.prefix(5)) { insight in
                        HStack(spacing: 8) {
                            Image(systemName: insight.isSpike ? "bolt.fill" : "folder.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(insight.isSpike ? .orange : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(insight.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(deltaText(insight))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", insight.cost.current))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                    }
                }
            }
        }
    }

    private func deltaText(_ insight: ProjectInsight) -> String {
        guard let percent = insight.cost.percentChange else {
            return L10n.s("новая активность", "new activity")
        }
        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(Int(percent))% \(L10n.s("к прошлому периоду", "vs previous period"))"
    }
}
```

- [ ] **Step 4: Wire dashboard to new cards**

Modify `SettingsView.dashboardTab`:

```swift
private var dashboardTab: some View {
    let records = HistoryStore.shared.load()
    let status = UsageAnalytics.status(for: orchestrator.usage, history: records, now: now)
    let previousProjects = records.dropLast().last?.projects ?? []
    let insights = UsageAnalytics.projectInsights(current: orchestrator.usage.topProjects, previous: previousProjects)

    return Group {
        SmartStatusCard(status: status, updatedAt: orchestrator.usage.tokensUpdatedAt ?? orchestrator.usage.limitsUpdatedAt)
        LimitIntelligenceCard(usage: orchestrator.usage, now: now)
        statsSection
        chartSection
        ProjectInsightsCard(insights: insights)
    }
}
```

Keep the old `limitsSection` temporarily in the file only if other code still references it; remove it in Task 7 if unused.

- [ ] **Step 5: Build the app**

Run:

```bash
xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Debug -derivedDataPath /private/tmp/TokenTracker14PlanBuild build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit Task 3**

```bash
git add TokenTracker/TokenTracker/Views/Components/SmartStatusCard.swift TokenTracker/TokenTracker/Views/Components/LimitIntelligenceCard.swift TokenTracker/TokenTracker/Views/Components/ProjectInsightsCard.swift TokenTracker/TokenTracker/Views/SettingsView.swift
git commit -m "feat: add smart dashboard cards"
```

---

### Task 4: Replace History With Insights

**Files:**
- Create: `TokenTracker/TokenTracker/Views/Components/InsightsView.swift`
- Modify: `TokenTracker/TokenTracker/Views/SettingsView.swift`

- [ ] **Step 1: Create `InsightsView`**

Create `TokenTracker/TokenTracker/Views/Components/InsightsView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct InsightsView: View {
    let records: [DayRecord]
    let periodDays: Int
    let metric: SettingsView.HistoryMetric
    let onPeriodChange: (Int) -> Void
    let onMetricChange: (SettingsView.HistoryMetric) -> Void
    let onExport: ([DayRecord]) -> Void

    var body: some View {
        Group {
            periodPicker
            if records.isEmpty {
                emptyState
            } else {
                summaryCard
                recordsList
            }
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 6) {
            ForEach([7, 30, 90], id: \.self) { days in
                Button { onPeriodChange(days) } label: {
                    Text("\(days) \(L10n.s("дн", "d"))")
                        .font(.system(size: 12, weight: periodDays == days ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        DarkCard {
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(L10n.s("Инсайты появятся после накопления истории", "Insights appear after history is collected"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var summaryCard: some View {
        let totalCost = records.map(\.cost).reduce(0, +)
        let totalTokens = records.map(\.tokens).reduce(0, +)
        let maxFiveHour = records.map(\.maxFiveHourPct).max() ?? 0

        return DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.s("Инсайты", "Insights"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("$\(String(format: "%.2f", totalCost))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Button { onExport(records) } label: {
                        Label("CSV", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 0) {
                    insightCell(L10n.s("Токены", "Tokens"), formatTokens(totalTokens), icon: "cpu")
                    insightCell(L10n.s("5ч пик", "5h peak"), "\(Int(maxFiveHour))%", icon: "gauge.with.dots.needle.67percent")
                    insightCell(L10n.s("Дней", "Days"), "\(records.count)", icon: "calendar")
                }

                if metric == .cost {
                    WeeklyBarChart(records: records).frame(height: 64)
                } else {
                    LimitBarChart(records: records).frame(height: 64)
                }
            }
        }
    }

    private var recordsList: some View {
        ForEach(records.reversed()) { record in
            DarkCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.date)
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(formatTokens(record.tokens)) · \(record.sessions) \(L10n.s("сесс.", "sessions"))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$\(String(format: "%.2f", record.cost))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private func insightCell(_ label: String, _ value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded))
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}
```

- [ ] **Step 2: Rename tab label to Insights**

Modify `SettingsView.AppTab.label` for `.history`:

```swift
case .history: return L10n.s("Инсайты", "Insights")
```

Modify `.history` icon:

```swift
case .history: return "chart.xyaxis.line"
```

- [ ] **Step 3: Replace `historyTab` body**

Modify `SettingsView.historyTab`:

```swift
private var historyTab: some View {
    let records = Array(HistoryStore.shared.load().suffix(historyDays))
    return InsightsView(
        records: records,
        periodDays: historyDays,
        metric: historyMetric,
        onPeriodChange: { historyDays = $0 },
        onMetricChange: { historyMetric = $0 },
        onExport: { exportCSV(records: $0) }
    )
}
```

Keep `exportCSV(records:)` in `SettingsView` for now because it uses `NSSavePanel`.

- [ ] **Step 4: Build the app**

Run:

```bash
xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Debug -derivedDataPath /private/tmp/TokenTracker14PlanBuild build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit Task 4**

```bash
git add TokenTracker/TokenTracker/Views/Components/InsightsView.swift TokenTracker/TokenTracker/Views/SettingsView.swift
git commit -m "feat: expand history into insights"
```

---

### Task 5: Add Menu Bar Mini Dashboard

**Files:**
- Create: `TokenTracker/TokenTracker/Views/MenuBarDashboardView.swift`
- Modify: `TokenTracker/TokenTracker/TokenTrackerApp.swift`

- [ ] **Step 1: Create menu bar dashboard view**

Create `TokenTracker/TokenTracker/Views/MenuBarDashboardView.swift`:

```swift
import SwiftUI

struct MenuBarDashboardView: View {
    @ObservedObject var orchestrator: AppOrchestrator
    let onOpenDashboard: () -> Void
    let onOpenInsights: () -> Void
    let onSync: () -> Void

    var body: some View {
        let status = UsageAnalytics.status(for: orchestrator.usage, history: HistoryStore.shared.load())

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TokenTracker")
                        .font(.system(size: 13, weight: .bold))
                    Text(status.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(color(status.level)).frame(width: 9, height: 9)
            }

            if let limits = orchestrator.usage.limits {
                miniRow("5h", "\(Int(limits.fiveHourUtilization))%")
                miniRow("Week", "\(Int(limits.weeklyUtilization))%")
            } else {
                Text(L10n.s("Лимиты недоступны", "Limits unavailable"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            miniRow(L10n.s("Сегодня", "Today"), "$\(String(format: "%.2f", orchestrator.usage.costToday))")

            Divider()

            HStack(spacing: 8) {
                Button(L10n.sync) { onSync() }
                Button(L10n.dashboard) { onOpenDashboard() }
                Button(L10n.s("Инсайты", "Insights")) { onOpenInsights() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 260)
    }

    private func miniRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded))
        }
    }

    private func color(_ level: UsageStatus.Level) -> Color {
        switch level {
        case .safe: return .green
        case .watch: return .orange
        case .critical: return .red
        }
    }
}
```

- [ ] **Step 2: Add popover to `AppDelegate`**

Modify `TokenTrackerApp.swift` properties:

```swift
var statusItem: NSStatusItem!
var popover: NSPopover!
```

Modify `createStatusItem()`:

```swift
func createStatusItem() {
    guard statusItem == nil else { return }
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
        button.title = "◆"
        button.target = self
        button.action = #selector(statusItemClicked)
    }

    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentSize = NSSize(width: 260, height: 220)
    popover.contentViewController = NSHostingController(rootView: MenuBarDashboardView(
        orchestrator: orchestrator,
        onOpenDashboard: { [weak self] in self?.showMainWindow() },
        onOpenInsights: { [weak self] in self?.showMainWindow() },
        onSync: { [weak self] in self?.orchestrator.forceRefresh() }
    ))
    self.popover = popover
}
```

Modify `statusItemClicked()`:

```swift
@objc func statusItemClicked() {
    guard let button = statusItem.button else {
        showMainWindow()
        return
    }
    if popover?.isShown == true {
        popover?.performClose(nil)
    } else {
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
```

- [ ] **Step 3: Build the app**

Run:

```bash
xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Debug -derivedDataPath /private/tmp/TokenTracker14PlanBuild build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit Task 5**

```bash
git add TokenTracker/TokenTracker/Views/MenuBarDashboardView.swift TokenTracker/TokenTracker/TokenTrackerApp.swift
git commit -m "feat: add menu bar mini dashboard"
```

---

### Task 6: Add Widget Health And Settings Cleanup

**Files:**
- Create: `TokenTracker/TokenTracker/Views/Components/WidgetHealthCard.swift`
- Modify: `TokenTracker/TokenTracker/Models/UsageAnalytics.swift`
- Modify: `TokenTracker/TokenTracker/Views/SettingsView.swift`
- Test: `TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift`

- [ ] **Step 1: Add failing widget health test**

Append to `UsageAnalyticsTests`:

```swift
func test_widgetHealth_reportsReadyWhenUsageIsFreshAndAccountExists() {
    let manifest = SharedStore.AccountsManifest(
        activeId: UUID(),
        accounts: [SharedStore.AccountListEntry(id: UUID(), name: "Main")],
        widgetAccountId: nil
    )
    let usage = UsageData.empty.withFreshTokenDate()

    let health = UsageAnalytics.widgetHealth(usage: usage, manifest: manifest, now: Date())

    XCTAssertEqual(health.state, .ready)
}
```

Add helper:

```swift
private extension UsageData {
    func withFreshTokenDate() -> UsageData {
        var copy = self
        copy.tokensUpdatedAt = Date()
        return copy
    }
}
```

- [ ] **Step 2: Implement widget health model**

Append to `UsageAnalytics.swift`:

```swift
struct WidgetHealth: Equatable {
    enum State: Equatable {
        case ready
        case stale
        case noAccount
        case noData
    }

    let state: State
    let title: String
    let detail: String
}

extension UsageAnalytics {
    static func widgetHealth(usage: UsageData, manifest: SharedStore.AccountsManifest, now: Date = Date()) -> WidgetHealth {
        if manifest.activeId == nil && manifest.accounts.isEmpty {
            return WidgetHealth(
                state: .noAccount,
                title: L10n.s("Аккаунт не выбран", "No account selected"),
                detail: L10n.s("Добавьте аккаунт, чтобы виджет получил данные", "Add an account so the widget can receive data")
            )
        }

        guard let updated = usage.tokensUpdatedAt ?? usage.limitsUpdatedAt else {
            return WidgetHealth(
                state: .noData,
                title: L10n.s("Данных пока нет", "No data yet"),
                detail: L10n.s("Синхронизируйте приложение один раз", "Sync the app once")
            )
        }

        if now.timeIntervalSince(updated) > 2 * 3600 {
            return WidgetHealth(
                state: .stale,
                title: L10n.s("Данные устарели", "Data is stale"),
                detail: L10n.s("Виджет покажет последнее сохранённое состояние", "Widget will show the last saved state")
            )
        }

        return WidgetHealth(
            state: .ready,
            title: L10n.s("Виджет готов", "Widget ready"),
            detail: L10n.s("Данные доступны локально", "Data is available locally")
        )
    }
}
```

- [ ] **Step 3: Create widget health card**

Create `TokenTracker/TokenTracker/Views/Components/WidgetHealthCard.swift`:

```swift
import SwiftUI

struct WidgetHealthCard: View {
    let health: WidgetHealth
    let selectedAccountName: String

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.s("Виджет", "Widget"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle().fill(color).frame(width: 8, height: 8)
                }
                Text(health.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(health.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Divider()
                Text(L10n.s("Аккаунт: \(selectedAccountName)", "Account: \(selectedAccountName)"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(L10n.s("Если TokenTracker не появился в списке виджетов после установки, перезапустите macOS или выйдите и войдите обратно.", "If TokenTracker does not appear in the widget picker after install, restart macOS or log out and back in."))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var color: Color {
        switch health.state {
        case .ready: return .green
        case .stale: return .orange
        case .noAccount, .noData: return .secondary
        }
    }
}
```

- [ ] **Step 4: Add widget health to settings tab**

In `SettingsView.settingsTab`, add `WidgetHealthCard` near the existing widget account section:

```swift
let manifest = SharedStore.readAccountsManifest()
let selectedName = manifest.widgetAccountId.flatMap { id in manifest.accounts.first(where: { $0.id == id })?.name } ?? L10n.s("Активный аккаунт", "Active account")
let health = UsageAnalytics.widgetHealth(usage: orchestrator.usage, manifest: manifest, now: now)
WidgetHealthCard(health: health, selectedAccountName: selectedName)
```

Keep existing widget account selection controls.

- [ ] **Step 5: Run tests and build**

Run:

```bash
xcodebuild test -project TokenTracker.xcodeproj -scheme TokenTracker -destination 'platform=macOS' -only-testing:TokenTrackerTests/UsageAnalyticsTests
xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Debug -derivedDataPath /private/tmp/TokenTracker14PlanBuild build
```

Expected: tests PASS and build succeeds.

- [ ] **Step 6: Commit Task 6**

```bash
git add TokenTracker/TokenTracker/Views/Components/WidgetHealthCard.swift TokenTracker/TokenTracker/Models/UsageAnalytics.swift TokenTracker/TokenTracker/Views/SettingsView.swift TokenTracker/TokenTrackerTests/UsageAnalyticsTests.swift
git commit -m "feat: add widget health status"
```

---

### Task 7: Final Cleanup, Docs, And Release Verification

**Files:**
- Modify: `TokenTracker/TokenTracker/Views/SettingsView.swift`
- Modify: `TokenTracker/TokenTracker/L10n.swift`
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md`
- Modify: `FAQ.md`

- [ ] **Step 1: Remove unused old dashboard/history helpers**

In `SettingsView.swift`, remove helpers that are no longer referenced after Tasks 3 and 4:

```swift
private var limitsSection: some View
private var projectsSection: some View
private func historyStatCell(_ label: String, _ value: String, icon: String) -> some View
private func formatHistoryDate(_ dateStr: String) -> String
```

Only delete a helper after confirming `rg "helperName" TokenTracker/TokenTracker/Views/SettingsView.swift` returns no active references.

- [ ] **Step 2: Add or consolidate localization strings**

Add missing strings in `TokenTracker/TokenTracker/L10n.swift` as static helpers only when the same copy appears in two or more files. Use `L10n.s("RU", "EN")` inline for one-off copy.

- [ ] **Step 3: Update roadmap**

Modify `ROADMAP.md`:

```markdown
## Recently shipped / Недавно выпущено

- ✅ **Smart Command Center / Умный центр управления** — Safe/Watch/Critical status, limit intelligence, project insights, enhanced Insights screen, menu bar mini-dashboard, and widget health *(v1.4.0)*
```

Remove `Rate limit history` from `Next` once it is covered by 1.4.0.

- [ ] **Step 4: Update changelog**

Add at the top of `CHANGELOG.md`:

```markdown
## v1.4.0 — June 2026

### New features
- Smart dashboard status: Safe, Watch, and Critical.
- Limit intelligence with reset context and burn-rate hints.
- Project insights with period deltas and spike detection.
- Enhanced Insights tab for cost, tokens, limit history, and project trends.
- Menu bar mini-dashboard with quick actions.
- Widget Health section with selected account, data freshness, and WidgetKit cache troubleshooting.

### Improved
- Dashboard hierarchy and Settings organization.
- Main dashboard no longer shows extra usage credits as a primary limit row.
```

- [ ] **Step 5: Update widget FAQ**

Add to `FAQ.md` widget section:

```markdown
**RU:** Если TokenTracker не появился в списке виджетов сразу после установки или обновления, перезапустите macOS или выйдите и войдите обратно. WidgetKit иногда кеширует список расширений.

**EN:** If TokenTracker does not appear in the widget picker immediately after install or update, restart macOS or log out and back in. WidgetKit sometimes caches the extension list.
```

- [ ] **Step 6: Run full test suite**

Run:

```bash
xcodebuild test -project TokenTracker.xcodeproj -scheme TokenTracker -destination 'platform=macOS'
```

Expected: all tests PASS.

- [ ] **Step 7: Run Debug build**

Run:

```bash
xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Debug -derivedDataPath /private/tmp/TokenTracker14FinalDebug build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Run Release build**

Run:

```bash
xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Release -derivedDataPath /private/tmp/TokenTracker14FinalRelease build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Verify widget extension is still embedded**

Run:

```bash
find /private/tmp/TokenTracker14FinalRelease/Build/Products/Release/TokenTracker.app/Contents/PlugIns -maxdepth 2 -type d -name '*.appex' -print
```

Expected output includes:

```text
/private/tmp/TokenTracker14FinalRelease/Build/Products/Release/TokenTracker.app/Contents/PlugIns/TokenTrackerWidgetExtension.appex
```

- [ ] **Step 10: Commit Task 7**

```bash
git add TokenTracker/TokenTracker/Views/SettingsView.swift TokenTracker/TokenTracker/L10n.swift CHANGELOG.md ROADMAP.md FAQ.md
git commit -m "docs: prepare 1.4 smart command center release notes"
```

---

## Manual QA Checklist

- [ ] Launch the Debug app.
- [ ] Confirm dashboard starts with Smart Status card.
- [ ] Confirm main limits card does not show the credits row.
- [ ] Confirm 5-hour and weekly reset copy fits in the 340 px window.
- [ ] Confirm Project Insights appears when `topProjects` has data.
- [ ] Confirm Insights tab works for 7, 30, and 90 days.
- [ ] Confirm CSV export still opens `NSSavePanel`.
- [ ] Confirm menu bar click opens the mini dashboard instead of immediately opening the main window.
- [ ] Confirm menu bar Sync triggers `orchestrator.forceRefresh()`.
- [ ] Confirm Settings includes Widget Health and existing widget account selection still works.
- [ ] Confirm light, dark, and system themes have readable text and no overlapping card content.
- [ ] Confirm widget extension remains `StaticConfiguration` and still builds.

## Self-Review

- Spec coverage: Smart Dashboard is Task 3, Limit Intelligence is Task 3, Project Insights is Tasks 2 and 3, Insights screen is Task 4, Menu Bar Mini Dashboard is Task 5, Widget Health is Task 6, Settings cleanup/docs are Task 7.
- Non-goals honored: no iOS/iCloud work, no Anthropic API work, no Developer ID/notarization requirement, no WidgetKit configuration rewrite.
- Type consistency: `UsageStatus`, `PeriodComparison`, `ProjectInsight`, and `WidgetHealth` are defined before UI tasks consume them.
- Scope: the plan is large but composed into independently shippable commits.
