import SwiftUI

struct MenuBarDashboardView: View {
    @ObservedObject var orchestrator: AppOrchestrator

    let onSync: () -> Void
    let onOpen: () -> Void
    let onInsights: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var usage: UsageData { orchestrator.usage }
    private var history: [DayRecord] { HistoryStore.shared.load() }
    private var status: UsageStatus {
        UsageAnalytics.status(for: usage, history: history)
    }
    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.62) : .secondary }
    private var textTertiary: Color { isDark ? .white.opacity(0.38) : Color(.tertiaryLabelColor) }
    private var panelFill: Color {
        isDark ? Color(red: 0.09, green: 0.07, blue: 0.14) : Color(.windowBackgroundColor)
    }
    private var sectionFill: Color {
        isDark ? .white.opacity(0.055) : Color(.controlBackgroundColor).opacity(0.78)
    }
    private var borderColor: Color {
        isDark ? .white.opacity(0.08) : Color(.separatorColor).opacity(0.52)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statusRow
            limitsSection
            metricsSection
            actions
        }
        .padding(14)
        .frame(width: 260)
        .background(panelFill)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("TokenTracker")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
            Spacer()
            Text(usage.provider.shortName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textTertiary)
                .lineLimit(1)
        }
    }

    private var statusRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                Text(status.reason)
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(L10n.limits)

            if let limits = usage.limits {
                limitRow(
                    title: L10n.fiveHourLabel,
                    utilization: limits.fiveHourUtilization,
                    icon: "clock.fill"
                )
                limitRow(
                    title: L10n.weeklyLabel,
                    utilization: limits.weeklyUtilization,
                    icon: "calendar"
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.s("Лимиты недоступны", "Limits unavailable"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textSecondary)
                        Text(unavailableLimitsReason)
                            .font(.system(size: 10))
                            .foregroundStyle(textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(10)
        .background(sectionFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        }
    }

    private var metricsSection: some View {
        HStack(spacing: 8) {
            metricCell(
                title: L10n.cost,
                value: formatCurrency(usage.costToday),
                icon: "dollarsign.circle"
            )
            metricCell(
                title: L10n.tokens,
                value: formatTokens(usage.tokensToday),
                icon: "cpu"
            )
            metricCell(
                title: L10n.sessions,
                value: "\(usage.sessionsToday)",
                icon: "terminal"
            )
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            actionButton(title: L10n.sync, systemImage: "arrow.clockwise", action: onSync)
            actionButton(title: L10n.dashboard, systemImage: "rectangle.stack", action: onOpen)
            actionButton(title: L10n.s("Инсайты", "Insights"), systemImage: "chart.xyaxis.line", action: onInsights)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(textTertiary)
    }

    private func limitRow(title: String, utilization: Double, icon: String) -> some View {
        let clamped = min(max(utilization / 100, 0), 1)
        let color = color(for: utilization)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textTertiary)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text("\(Int(utilization.rounded()))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isDark ? .white.opacity(0.09) : Color(.separatorColor).opacity(0.35))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.86))
                        .frame(width: geometry.size.width * clamped)
                }
            }
            .frame(height: 4)
        }
    }

    private func metricCell(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(sectionFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        }
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDark ? .white.opacity(0.07) : Color(.controlBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var unavailableLimitsReason: String {
        if orchestrator.isLoggedIn {
            return L10n.s("Синхронизация или Org ID", "Sync or Org ID")
        }
        return L10n.loginForLimits
    }

    private var statusColor: Color {
        switch status.level {
        case .safe: return .green
        case .watch: return .orange
        case .critical: return .red
        }
    }

    private func color(for utilization: Double) -> Color {
        switch utilization {
        case UsageAnalytics.criticalFiveHourThreshold...:
            return .red
        case UsageAnalytics.watchFiveHourThreshold...:
            return .orange
        default:
            return .green
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 100 {
            return "$\(Int(value.rounded()))"
        }
        return "$\(String(format: "%.2f", value))"
    }

    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return "\(value / 1_000)K"
        }
        return "\(value)"
    }
}

#Preview {
    MenuBarDashboardView(
        orchestrator: AppOrchestrator(),
        onSync: {},
        onOpen: {},
        onInsights: {}
    )
}
