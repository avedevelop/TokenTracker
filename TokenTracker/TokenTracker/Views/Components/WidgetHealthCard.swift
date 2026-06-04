import SwiftUI

struct WidgetHealthCard: View {
    let health: WidgetHealth
    let accountLabel: String

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.55) : .secondary }
    private var textTertiary: Color { isDark ? .white.opacity(0.32) : Color(.tertiaryLabelColor) }

    var body: some View {
        DarkCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                statusBlock
                accountBlock
                troubleshootingBlock
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(L10n.s("Виджет", "Widget"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textTertiary)
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .accessibilityLabel(statusTitle)
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(statusTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Text(statusDetail)
                .font(.system(size: 11))
                .foregroundStyle(textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accountBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 12))
                .foregroundStyle(textTertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.s("Аккаунт виджета", "Widget account"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textTertiary)
                Text(accountLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textPrimary.opacity(0.72))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isDark ? Color.white.opacity(0.045) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.4), lineWidth: 0.5))
    }

    private var troubleshootingBlock: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 11))
                .foregroundStyle(textTertiary)
                .frame(width: 16)
            Text(L10n.s(
                "Если TokenTracker не появился в выборе виджетов после установки или обновления, перезапустите macOS или выйдите из системы и войдите снова: WidgetKit может кэшировать список расширений.",
                "If TokenTracker does not appear in the widget picker after install or update, restart macOS or log out and back in because WidgetKit can cache the extension list."
            ))
            .font(.system(size: 10))
            .foregroundStyle(textTertiary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusTitle: String {
        switch health.state {
        case .ready:
            return L10n.s("Виджет готов", "Widget ready")
        case .stale:
            return L10n.s("Данные устарели", "Data is stale")
        case .noAccount:
            return L10n.s("Нет аккаунта", "No account")
        case .noData:
            return L10n.s("Нет локальных данных", "No local data")
        }
    }

    private var statusDetail: String {
        switch health.state {
        case .ready:
            if let freshest = health.freshestSnapshotAt {
                let age = relativeSnapshotAge(freshest)
                return L10n.s(
                    "Последний снимок: \(age). Виджет должен показывать свежие данные.",
                    "Last snapshot: \(age). The widget should show fresh data."
                )
            }
            return L10n.s("Виджет должен показывать свежие данные.", "The widget should show fresh data.")
        case .stale:
            if let freshest = health.freshestSnapshotAt {
                let age = relativeSnapshotAge(freshest)
                return L10n.s(
                    "Последний снимок: \(age). Синхронизируйте TokenTracker, чтобы обновить виджет.",
                    "Last snapshot: \(age). Sync TokenTracker to refresh the widget."
                )
            }
            return L10n.s("Синхронизируйте TokenTracker, чтобы обновить виджет.", "Sync TokenTracker to refresh the widget.")
        case .noAccount:
            return L10n.s(
                "Добавьте аккаунт, чтобы TokenTracker мог выбрать данные для виджета.",
                "Add an account so TokenTracker can choose data for the widget."
            )
        case .noData:
            return L10n.s(
                "Локальные снимки токенов и лимитов ещё не записаны. Выполните синхронизацию после входа.",
                "Local token and limit snapshots have not been written yet. Sync after signing in."
            )
        }
    }

    private var statusColor: Color {
        switch health.state {
        case .ready: return .green
        case .stale: return .orange
        case .noAccount, .noData: return .red
        }
    }

    private func relativeSnapshotAge(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
