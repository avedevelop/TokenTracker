import SwiftUI

struct SmartStatusCard: View {
    let status: UsageStatus
    let updatedAt: Date?

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.55) : .secondary }
    private var textTertiary: Color { isDark ? .white.opacity(0.28) : Color(.tertiaryLabelColor) }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 26, height: 26)
                        .background(accentColor.opacity(isDark ? 0.16 : 0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text(status.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)

                        Text(status.reason)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(status.recommendation)
                            .font(.system(size: 11))
                            .foregroundStyle(textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.s("Умный статус", "Smart status"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textTertiary)
            Spacer()
            if let updatedAt {
                Text("\(updatedAt, style: .relative)\(L10n.agoSuffix)")
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary.opacity(0.6))
            }
        }
    }

    private var iconName: String {
        switch status.level {
        case .safe: return "checkmark.shield.fill"
        case .watch: return "eye.fill"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }

    private var accentColor: Color {
        switch status.level {
        case .safe: return .green
        case .watch: return .orange
        case .critical: return .red
        }
    }
}
