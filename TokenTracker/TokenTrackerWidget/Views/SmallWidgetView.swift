import SwiftUI
import WidgetKit
import AppIntents

struct SmallWidgetView: View {
    let usage: UsageData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    ClaudeLogoView(size: 12).foregroundStyle(.white)
                    Text("TokenTracker")
                        .font(.system(size: 8, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Button(intent: SyncIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let limits = usage.limits {
                // 5-hour — hero (no split % sign)
                Text("\(Int(limits.fiveHourUtilization))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)

                Text(WidgetL10n.fiveHour)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 1)

                Spacer()

                // Weekly compact
                VStack(spacing: 4) {
                    HStack {
                        Text(WidgetL10n.week)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.35))
                        Spacer()
                        Text("\(Int(limits.weeklyUtilization))%")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.7))
                                .frame(width: geo.size.width * min(limits.weeklyPercent, 1))
                        }
                    }
                    .frame(height: 3)
                }
            } else {
                Text("—")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white.opacity(0.15))
                Spacer()
                Text("Войдите для лимитов")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(14)
        .containerBackground(Color(red: 0.09, green: 0.07, blue: 0.14).opacity(0.92), for: .widget)
    }
}

#Preview {
    SmallWidgetView(usage: .preview)
        .frame(width: 155, height: 155)
}
