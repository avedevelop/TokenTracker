import SwiftUI
import WidgetKit
import AppIntents

struct MediumWidgetView: View {
    let usage: UsageData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    ClaudeLogoView(size: 12).foregroundStyle(.white)
                    Text("TokenTracker")
                        .font(.system(size: 8, weight: .semibold))
                        .kerning(0.6)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Text(usage.costToday, format: .currency(code: "USD"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                Button(intent: SyncIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            if let limits = usage.limits {
                HStack(spacing: 0) {
                    limitColumn(WidgetL10n.fiveHour, limits.fiveHourUtilization, limits.fiveHourPercent, resetsAt: limits.fiveHourResetsAt)

                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 0.5)
                        .padding(.horizontal, 12)

                    limitColumn(WidgetL10n.weekly, limits.weeklyUtilization, limits.weeklyPercent, resetsAt: limits.weeklyResetsAt)

                    if let su = limits.sonnetUtilization {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 0.5)
                            .padding(.horizontal, 12)
                        limitColumn("Sonnet", su, su / 100, resetsAt: nil)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                Spacer()
                Text("Войдите для лимитов")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
            }
        }
        .padding(14)
        .containerBackground(Color(red: 0.09, green: 0.07, blue: 0.14).opacity(0.92), for: .widget)
    }

    private func limitColumn(_ title: String, _ value: Double, _ pct: Double, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 4)

            Text("\(Int(value))%")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                if let date = resetsAt, date.timeIntervalSinceNow > 0 {
                    Text(resetLabel(date))
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.25))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.7))
                            .frame(width: geo.size.width * min(pct, 1))
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resetLabel(_ date: Date) -> String {
        let d = date.timeIntervalSinceNow
        let h = Int(d / 3600), m = Int(d.truncatingRemainder(dividingBy: 3600) / 60)
        return h > 0 ? WidgetL10n.resetIn(h: h, m: m) : WidgetL10n.resetIn(h: 0, m: m)
    }
}

#Preview {
    MediumWidgetView(usage: .preview)
        .frame(width: 329, height: 155)
}
