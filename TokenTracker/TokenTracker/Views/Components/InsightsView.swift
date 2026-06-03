import SwiftUI

struct InsightsView: View {
    @Binding var historyDays: Int
    @Binding var historyMetric: SettingsView.HistoryMetric

    let exportedCSV: Bool
    let onExport: ([DayRecord]) -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.45) : .secondary }
    private var textTertiary: Color { isDark ? .white.opacity(0.28) : Color(.tertiaryLabelColor) }

    private var data: InsightsPeriodData {
        InsightsPeriodData(records: HistoryStore.shared.load(), periodDays: historyDays)
    }

    var body: some View {
        Group {
            periodSelector

            if data.selectedRecords.isEmpty {
                emptyState
            } else {
                overviewCard
                comparisonCard
                chartCard
                dailyRecords
            }
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 6) {
            ForEach([7, 30, 90], id: \.self) { days in
                selectorButton(
                    title: "\(days) \(L10n.s("дн", "d"))",
                    isSelected: historyDays == days
                ) {
                    historyDays = days
                }
            }
        }
    }

    private var overviewCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.s("Инсайты", "Insights"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(textSecondary)
                        Text("\(historyDays) \(L10n.s("дн.", "days"))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)
                    }

                    Spacer(minLength: 8)

                    Button {
                        onExport(data.selectedRecords)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: exportedCSV ? "checkmark" : "square.and.arrow.up")
                                .font(.system(size: 11))
                            Text(exportedCSV ? L10n.s("Готово", "Done") : "CSV")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(
                            Capsule()
                                .strokeBorder(isDark ? .white.opacity(0.2) : Color(.separatorColor).opacity(0.7), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    overviewMetric(L10n.cost, formatCurrency(data.totalCost), icon: "dollarsign.circle")
                    overviewMetric(L10n.s("Токены", "Tokens"), formatTokens(data.totalTokens), icon: "cpu")
                    overviewMetric(L10n.s("Сессии", "Sessions"), "\(data.totalSessions)", icon: "terminal")
                    overviewMetric(L10n.s("Пик 5ч", "Peak 5h"), "\(Int(data.peakFiveHourPct.rounded()))%", icon: "gauge.with.dots.needle.67percent")
                }
            }
        }
    }

    private var comparisonCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.s("Сравнение", "Comparison"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textSecondary)

                VStack(spacing: 8) {
                    comparisonRow(
                        label: L10n.cost,
                        value: formatCurrency(data.costComparison.current),
                        comparison: data.costComparison,
                        icon: "dollarsign.circle"
                    )
                    Divider()
                    comparisonRow(
                        label: L10n.s("Токены", "Tokens"),
                        value: formatTokens(Int(data.tokensComparison.current)),
                        comparison: data.tokensComparison,
                        icon: "cpu"
                    )
                    Divider()
                    comparisonRow(
                        label: L10n.s("Сессии", "Sessions"),
                        value: "\(Int(data.sessionsComparison.current))",
                        comparison: data.sessionsComparison,
                        icon: "terminal"
                    )
                }
            }
        }
    }

    private var chartCard: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    selectorButton(title: L10n.cost, isSelected: historyMetric == .cost) {
                        historyMetric = .cost
                    }
                    selectorButton(title: L10n.s("5ч лимит", "5h limit"), isSelected: historyMetric == .fiveHour) {
                        historyMetric = .fiveHour
                    }
                }

                if historyMetric == .cost {
                    WeeklyBarChart(records: data.selectedRecords)
                        .frame(height: 70)
                } else {
                    LimitBarChart(records: data.selectedRecords)
                        .frame(height: 70)
                }
            }
        }
    }

    private var dailyRecords: some View {
        ForEach(data.selectedRecords.reversed()) { record in
            DarkCard {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(formatHistoryDate(record.date))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 8)
                        Text(formatCurrency(record.cost))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)
                            .lineLimit(1)
                    }

                    Divider()

                    HStack(spacing: 0) {
                        statCell(L10n.s("Токены", "Tokens"), formatTokens(record.tokens), icon: "cpu")
                        statCell(L10n.s("Сессии", "Sessions"), "\(record.sessions)", icon: "terminal")
                        statCell(L10n.s("5ч макс", "5h max"), "\(Int(record.maxFiveHourPct.rounded()))%", icon: "gauge.with.dots.needle.67percent")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        DarkCard {
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 28))
                    .foregroundStyle(textTertiary)
                Text(L10n.s("Инсайты появятся после первого дня использования", "Insights appear after your first day of usage"))
                    .font(.system(size: 12))
                    .foregroundStyle(textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func selectorButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let foreground = isSelected ? textPrimary : textSecondary
        let fill = selectorFill(isSelected: isSelected)
        let border = selectorBorder(isSelected: isSelected)

        return Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(border, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func selectorFill(isSelected: Bool) -> Color {
        if isSelected {
            return isDark ? Color.white.opacity(0.12) : Color.accentColor.opacity(0.12)
        }
        return isDark ? Color.white.opacity(0.04) : Color(.controlBackgroundColor)
    }

    private func selectorBorder(isSelected: Bool) -> Color {
        guard isSelected else { return .clear }
        return isDark ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.3)
    }

    private func overviewMetric(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(textTertiary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDark ? Color.white.opacity(0.04) : Color(.controlBackgroundColor))
        )
    }

    private func comparisonRow(label: String, value: String, comparison: PeriodComparison, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(textTertiary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            comparisonBadge(comparison)
        }
    }

    private func comparisonBadge(_ comparison: PeriodComparison) -> some View {
        let positive = comparison.delta > 0
        let neutral = abs(comparison.delta) < 0.001
        let color: Color = neutral ? textTertiary : (positive ? .orange : .green)
        let symbol = neutral ? "minus" : (positive ? "arrow.up.right" : "arrow.down.right")
        let label = comparison.percentChange.map { "\(Int(abs($0).rounded()))%" } ?? formatSignedDelta(comparison.delta)

        return HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(isDark ? 0.14 : 0.10), in: Capsule())
    }

    private func statCell(_ label: String, _ value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatCurrency(_ value: Double) -> String {
        "$\(String(format: "%.2f", value))"
    }

    private func formatTokens(_ value: Int) -> String {
        value >= 1_000_000
            ? String(format: "%.1fM", Double(value) / 1_000_000)
            : value >= 1000 ? "\(value / 1000)K" : "\(value)"
    }

    private func formatSignedDelta(_ value: Double) -> String {
        let rounded = Int(abs(value).rounded())
        return rounded == 0 ? "0" : "\(rounded)"
    }

    private func formatHistoryDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }
}

struct InsightsPeriodData {
    let selectedRecords: [DayRecord]
    let previousRecords: [DayRecord]
    let costComparison: PeriodComparison
    let tokensComparison: PeriodComparison
    let sessionsComparison: PeriodComparison

    init(records: [DayRecord], periodDays: Int) {
        let sorted = records.sorted { $0.date < $1.date }
        selectedRecords = Array(sorted.suffix(periodDays))
        previousRecords = Array(sorted.dropLast(selectedRecords.count).suffix(periodDays))
        costComparison = UsageAnalytics.compare(
            current: selectedRecords.map(\.cost).reduce(0, +),
            previous: previousRecords.map(\.cost).reduce(0, +)
        )
        tokensComparison = UsageAnalytics.compare(
            current: Double(selectedRecords.map(\.tokens).reduce(0, +)),
            previous: Double(previousRecords.map(\.tokens).reduce(0, +))
        )
        sessionsComparison = UsageAnalytics.compare(
            current: Double(selectedRecords.map(\.sessions).reduce(0, +)),
            previous: Double(previousRecords.map(\.sessions).reduce(0, +))
        )
    }

    var totalCost: Double {
        costComparison.current
    }

    var totalTokens: Int {
        Int(tokensComparison.current)
    }

    var totalSessions: Int {
        Int(sessionsComparison.current)
    }

    var peakFiveHourPct: Double {
        selectedRecords.map(\.maxFiveHourPct).max() ?? 0
    }
}
