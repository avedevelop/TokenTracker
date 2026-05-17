import SwiftUI
import WidgetKit
import AppIntents

struct LargeWidgetView: View {
    let usage: UsageData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    ClaudeLogoView(size: 15).foregroundStyle(.white)
                    Text("TokenTracker")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(0.7)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(usage.costToday, format: .currency(code: "USD"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                        if let updated = usage.limitsUpdatedAt {
                            Text("\(WidgetL10n.updated) \(updated, style: .time)")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.18))
                        }
                    }
                    Button(intent: SyncIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Limits — compact, fixed spacing
            if let limits = usage.limits {
                VStack(spacing: 10) {
                    limitRow("5-часовой лимит", limits.fiveHourPercent, limits.fiveHourUtilization, resetsAt: limits.fiveHourResetsAt)
                    limitRow("Недельный лимит", limits.weeklyPercent, limits.weeklyUtilization, resetsAt: limits.weeklyResetsAt)
                    if let su = limits.sonnetUtilization {
                        limitRow("Sonnet (7 дней)", su / 100, su, resetsAt: nil)
                    }
                    if let ou = limits.opusUtilization {
                        limitRow("Opus (7 дней)", ou / 100, ou, resetsAt: nil)
                    }
                    if let used = limits.extraUsageUsed, let cap = limits.extraUsageLimit,
                       limits.extraUsageEnabled, cap > 0 {
                        limitRow("Кредиты $\(Int(used))/$\(Int(cap))", used / cap, used / cap * 100, resetsAt: nil)
                    }
                }
            } else {
                Text("Войдите в аккаунт для отображения лимитов")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }

            // Chart — fills remaining space
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(formatTokens(usage.tokensToday)) токенов")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("\(usage.sessionsToday) \(WidgetL10n.sessions)")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                    Spacer()
                }
                HourlyChartView(hourlyUsage: usage.hourlyUsage)
                HStack {
                    Text("0:00"); Spacer()
                    Text("6:00"); Spacer()
                    Text("12:00"); Spacer()
                    Text("18:00"); Spacer()
                    Text(WidgetL10n.now)
                }
                .font(.system(size: 7.5))
                .foregroundStyle(.white.opacity(0.15))
            }
        }
        .padding(16)
        .containerBackground(Color(red: 0.09, green: 0.07, blue: 0.14).opacity(0.92), for: .widget)
    }

    private func limitRow(_ label: String, _ pct: Double, _ raw: Double, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                if let date = resetsAt, date.timeIntervalSinceNow > 0 {
                    Text(resetLabel(date))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.22))
                }
                Text("\(Int(raw))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.72))
                        .frame(width: geo.size.width * min(pct, 1))
                }
            }
            .frame(height: 4)
        }
    }

    private func resetLabel(_ date: Date) -> String {
        let d = date.timeIntervalSinceNow
        let h = Int(d / 3600), m = Int(d.truncatingRemainder(dividingBy: 3600) / 60)
        return h > 0 ? "через \(h)ч \(m)м" : "через \(m)м"
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000) : n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }
}

struct HourlyChartView: View {
    let hourlyUsage: [Int]
    var body: some View {
        let maxVal = max(hourlyUsage.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<hourlyUsage.count, id: \.self) { h in
                let val = hourlyUsage[h]
                let pct = Double(val) / Double(maxVal)
                let past = h <= Calendar.current.component(.hour, from: .now)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(past && val > 0 ? 0.5 : 0.1))
                    .frame(maxHeight: .infinity)
                    .scaleEffect(y: max(pct, 0.03), anchor: .bottom)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    LargeWidgetView(usage: .preview)
        .frame(width: 329, height: 329)
}
