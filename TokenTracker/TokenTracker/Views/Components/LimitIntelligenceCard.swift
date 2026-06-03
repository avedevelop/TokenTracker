import SwiftUI

struct LimitIntelligenceCard: View {
    let limits: UsageData.Limits?
    let updatedAt: Date?
    let isLoggedIn: Bool
    let hasOrgId: Bool
    let now: Date

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.55) : .secondary }
    private var textTertiary: Color { isDark ? .white.opacity(0.28) : Color(.tertiaryLabelColor) }

    var body: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader

                if let updatedAt, now.timeIntervalSince(updatedAt) > 7200 {
                    staleNotice
                }

                if let limits {
                    VStack(spacing: 12) {
                        limitRow(
                            label: L10n.fiveHourLabel,
                            percent: limits.fiveHourPercent,
                            rawPercent: limits.fiveHourUtilization,
                            resetsAt: limits.fiveHourResetsAt,
                            icon: "clock.fill"
                        )
                        limitRow(
                            label: L10n.weeklyLabel,
                            percent: limits.weeklyPercent,
                            rawPercent: limits.weeklyUtilization,
                            resetsAt: limits.weeklyResetsAt,
                            icon: "calendar"
                        )
                        if let sonnet = limits.sonnetUtilization {
                            limitRow(
                                label: L10n.s("Sonnet (7д)", "Sonnet (7d)"),
                                percent: sonnet / 100,
                                rawPercent: sonnet,
                                resetsAt: nil,
                                icon: "sparkles"
                            )
                        }
                        if let opus = limits.opusUtilization {
                            limitRow(
                                label: L10n.s("Opus (7д)", "Opus (7d)"),
                                percent: opus / 100,
                                rawPercent: opus,
                                resetsAt: nil,
                                icon: "sparkle.magnifyingglass"
                            )
                        }
                        burnLabel(for: limits)
                    }
                } else {
                    unavailableContent
                }
            }
        }
    }

    private var cardHeader: some View {
        HStack {
            Text(L10n.s("Лимиты", "Limits"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textTertiary)
            Spacer()
            if let updatedAt {
                Text("\(updatedAt, style: .relative)\(L10n.agoSuffix)")
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary.opacity(0.6))
            }
        }
        .padding(.bottom, 10)
    }

    private var staleNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange.opacity(0.8))
            Text(L10n.dataOutdated)
                .font(.system(size: 10))
                .foregroundStyle(.orange.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(unavailableTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary)
            Text(unavailableSubtitle)
                .font(.system(size: 11))
                .foregroundStyle(textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var unavailableTitle: String {
        if isLoggedIn && !hasOrgId {
            return L10n.s("Лимиты недоступны", "Limits unavailable")
        }
        if isLoggedIn {
            return L10n.s("Загрузка лимитов…", "Loading limits…")
        }
        return L10n.loginForLimits
    }

    private var unavailableSubtitle: String {
        if isLoggedIn && !hasOrgId {
            return L10n.s("Укажите Org ID в настройках аккаунта", "Set Org ID in the account settings")
        }
        return L10n.s("Данные появятся после синхронизации", "Data appears after sync")
    }

    private func limitRow(
        label: String,
        percent: Double,
        rawPercent: Double,
        resetsAt: Date?,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(textTertiary)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondary)
                if let resetsAt, resetsAt.timeIntervalSince(now) > 0 {
                    Text("· \(resetLabel(resetsAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(Int(rawPercent.rounded()))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color(for: percent))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.4))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: percent).opacity(0.82))
                        .frame(width: geometry.size.width * min(max(percent, 0), 1))
                }
            }
            .frame(height: 4)
        }
    }

    private func burnLabel(for limits: UsageData.Limits) -> some View {
        let burn = estimatedFiveHourBurn(for: limits)
        return HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange.opacity(0.75))
            Text(burn)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textTertiary)
            Spacer()
        }
        .padding(.top, 2)
    }

    private func estimatedFiveHourBurn(for limits: UsageData.Limits) -> String {
        guard let reset = limits.fiveHourResetsAt else {
            return L10n.s("Темп: reset неизвестен", "Burn: reset unknown")
        }
        let hoursUntilReset = max(reset.timeIntervalSince(now) / 3600, 0.25)
        let elapsed = max(5 - hoursUntilReset, 0.25)
        let burnPerHour = limits.fiveHourUtilization / elapsed
        return L10n.s(
            "Темп: \(Int(burnPerHour.rounded()))%/ч до reset",
            "Burn: \(Int(burnPerHour.rounded()))%/h until reset"
        )
    }

    private func resetLabel(_ date: Date) -> String {
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return L10n.didReset }
        let hours = Int(interval / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        return hours > 0
            ? "\(L10n.resetsLabel) \(hours)\(L10n.hoursShort) \(minutes)\(L10n.minutesShort)"
            : "\(L10n.resetsLabel) \(minutes)\(L10n.minutesShort)"
    }

    private func color(for percent: Double) -> Color {
        if percent > 0.8 { return .red }
        if percent > 0.6 { return .orange }
        return isDark ? .white.opacity(0.72) : Color.accentColor.opacity(0.82)
    }
}
