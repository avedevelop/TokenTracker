import SwiftUI

struct ProjectInsightsCard: View {
    let insights: [ProjectInsight]

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.55) : .secondary }
    private var textTertiary: Color { isDark ? .white.opacity(0.28) : Color(.tertiaryLabelColor) }

    var body: some View {
        if !insights.isEmpty {
            DarkCard {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: 9) {
                        ForEach(Array(insights.prefix(5))) { insight in
                            insightRow(insight)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(L10n.s("Инсайты проектов", "Project insights"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textTertiary)
            Spacer()
            Text(L10n.s("до 5", "top 5"))
                .font(.system(size: 10))
                .foregroundStyle(textTertiary.opacity(0.6))
        }
        .padding(.bottom, 10)
    }

    private func insightRow(_ insight: ProjectInsight) -> some View {
        HStack(spacing: 9) {
            Image(systemName: insight.isSpike ? "bolt.fill" : "folder.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(insight.isSpike ? .orange : textTertiary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary.opacity(0.78))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(formatTokens(Int(insight.tokens.current)))
                    Text("·")
                    Text("$\(String(format: "%.4f", insight.cost.current))")
                    if insight.isSpike {
                        Text("·")
                        Text(L10n.s("скачок", "spike"))
                            .foregroundStyle(.orange.opacity(0.85))
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(textTertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatCostDelta(insight.cost.delta))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(deltaColor(insight.cost.delta))
                Text(formatPercentChange(insight.cost.percentChange))
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
            }
        }
    }

    private func formatTokens(_ value: Int) -> String {
        value >= 1_000_000
            ? String(format: "%.1fM", Double(value) / 1_000_000)
            : value >= 1000 ? "\(value / 1000)K" : "\(value)"
    }

    private func formatCostDelta(_ value: Double) -> String {
        if abs(value) < 0.0001 { return "$0" }
        let sign = value > 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", abs(value)))"
    }

    private func formatPercentChange(_ value: Double?) -> String {
        guard let value else { return L10n.s("новый", "new") }
        if abs(value) < 0.5 { return L10n.s("без изм.", "flat") }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int(value.rounded()))%"
    }

    private func deltaColor(_ value: Double) -> Color {
        if value > 0.0001 { return .orange }
        if value < -0.0001 { return .green }
        return textSecondary
    }
}
