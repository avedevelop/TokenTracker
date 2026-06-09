import SwiftUI
import WidgetKit
import ServiceManagement
import Combine
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var orchestrator: AppOrchestrator
    @State private var isSyncing = false
    @State private var noUpdateToast = false
    @State private var activeTab: AppTab = .dashboard
    @State private var now = Date()
    @State private var exportedCSV = false
    @State private var historyDays: Int = 7
    @State private var historyMetric: HistoryMetric = .cost

    enum HistoryMetric: Equatable { case cost, fiveHour }

    @AppStorage("appColorScheme") private var appColorScheme: String = "dark"
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.45) : .secondary }
    private var textTertiary: Color { isDark ? .white.opacity(0.28) : Color(.tertiaryLabelColor) }
    private var cardFill: Color { isDark ? .white.opacity(0.05) : Color(.controlBackgroundColor) }
    private var cardBorder: Color { isDark ? .white.opacity(0.08) : Color(.separatorColor).opacity(0.5) }
    private var appBg: Color { isDark ? Color(red: 0.09, green: 0.07, blue: 0.14) : Color(.windowBackgroundColor) }

    let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    enum AppTab: CaseIterable {
        case dashboard, history, account, settings

        var label: String {
            switch self {
            case .dashboard: return L10n.dashboard
            case .history:   return L10n.s("Инсайты", "Insights")
            case .account:   return L10n.account
            case .settings:  return L10n.settings
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .history:   return "chart.xyaxis.line"
            case .account:   return "person.fill"
            case .settings:  return "gearshape.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        switch activeTab {
                        case .dashboard: dashboardTab
                        case .history:   historyTab
                        case .account:   accountTab
                        case .settings:  settingsTab
                        }
                    }
                    .padding(16)
                }

                tabBar
            }
        }
        .frame(width: 340)
        .onReceive(countdownTimer) { date in now = date }
        .onAppear {
            now = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            now = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            now = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tokenTrackerOpenTab)) { notification in
            guard let tab = notification.userInfo?["tab"] as? String else { return }
            switch tab {
            case "dashboard":
                activeTab = .dashboard
            case "insights":
                activeTab = .history
            case "account":
                activeTab = .account
            case "settings":
                activeTab = .settings
            default:
                break
            }
        }
        .background(
            Button("") { activeTab = .settings }
                .keyboardShortcut(",", modifiers: .command)
                .opacity(0)
        )
        .overlay {
            if showAddAccount {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.25)) { showAddAccount = false }
                        }

                    VStack(spacing: 0) {
                        HStack {
                            Text(L10n.addAccount)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(textPrimary.opacity(0.7))
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.25)) { showAddAccount = false }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(textSecondary)
                                    .frame(width: 22, height: 22)
                                    .background(.white.opacity(0.08), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 14)

                        Divider()

                        LoginView(onLoginSuccess: {
                            withAnimation(.spring(duration: 0.25)) { showAddAccount = false }
                            orchestrator.onLoginSuccess()
                        }, isSheet: true)
                        .environmentObject(orchestrator)
                    }
                    .background(Color(red: 0.11, green: 0.09, blue: 0.17))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 40)
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                }
                .environment(\.colorScheme, .dark)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .center)))
            }
        }
        .animation(.spring(duration: 0.25), value: showAddAccount)
        .overlay {
            if let profile = refreshingTokenProfile {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.25)) { refreshingTokenProfile = nil }
                            refreshTokenInput = ""; refreshTokenError = nil
                        }

                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.s("Обновить токен", "Refresh token"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(profile.displayName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.25)) { refreshingTokenProfile = nil }
                                refreshTokenInput = ""; refreshTokenError = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .frame(width: 22, height: 22)
                                    .background(.white.opacity(0.08), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 14)

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.s(
                                "Вставьте свежий sessionKey из DevTools\nclaude.ai → Cmd+Option+I → Application → Cookies",
                                "Paste a fresh sessionKey from DevTools\nclaude.ai → Cmd+Option+I → Application → Cookies"
                            ))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.35))
                            .lineSpacing(2)

                            SecureField("sk-ant-sid02-...", text: $refreshTokenInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 9)
                                    .fill(.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(refreshTokenError != nil ? Color.red.opacity(0.5) : .white.opacity(0.12), lineWidth: 0.5)))
                                .background(
                                    Button("") {
                                        if let s = NSPasteboard.general.string(forType: .string) {
                                            refreshTokenInput = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                            refreshTokenError = nil
                                        }
                                    }
                                    .keyboardShortcut("v", modifiers: .command)
                                    .opacity(0)
                                )

                            if let err = refreshTokenError {
                                HStack(spacing: 5) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red.opacity(0.8))
                                    Text(err)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                            }

                            HStack {
                                Spacer()
                                Button {
                                    Task { await performTokenRefresh(for: profile) }
                                } label: {
                                    HStack(spacing: 6) {
                                        if refreshTokenValidating {
                                            ProgressView().controlSize(.mini).tint(.white)
                                        }
                                        Text(refreshTokenValidating
                                             ? L10n.s("Проверка…", "Checking…")
                                             : L10n.s("Сохранить", "Save"))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(refreshTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.3) : .white)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 9)
                                        .fill(.white.opacity(refreshTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.05 : 0.12))
                                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.15), lineWidth: 0.5)))
                                }
                                .buttonStyle(.plain)
                                .disabled(refreshTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || refreshTokenValidating)
                            }
                        }
                        .padding(20)
                    }
                    .background(Color(red: 0.11, green: 0.09, blue: 0.17))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 60)
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                }
                .environment(\.colorScheme, .dark)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .center)))
            }
        }
        .animation(.spring(duration: 0.25), value: refreshingTokenProfile == nil)
    }

    // MARK: - Token Refresh

    private func performTokenRefresh(for profile: AccountProfile) async {
        let token = refreshTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        await MainActor.run { refreshTokenValidating = true; refreshTokenError = nil }

        do {
            let poller = LimitsPoller()
            let limits: UsageData.Limits
            // Always discover orgId fresh — the stored one may belong to a different account.
            // e.g. user logs into account B in incognito and copies its sessionKey into account A's refresh form.
            if token.hasPrefix("sk-ant-oat") {
                limits = try await poller.fetchLimitsWithOAuthToken(token)
            } else {
                let freshOrgId = await poller.fetchOrgIdFromAPI(auth: .cookie(token))
                if let freshOrgId, !freshOrgId.isEmpty {
                    limits = try await poller.fetchLimits(sessionKey: token, orgId: freshOrgId)
                    // Persist the newly discovered orgId if it changed
                    if freshOrgId != profile.orgId {
                        await accountStore.updateOrgId(freshOrgId, for: profile.id)
                    }
                } else {
                    // org discovery failed — token may be for a free account (no org)
                    limits = try await poller.fetchLimits(sessionKey: token)
                }
            }
            try? accountStore.updateToken(token, for: profile.id)
            accountStore.markTokenStatus(id: profile.id, valid: true)
            if accountStore.activeId == profile.id {
                try? SharedStore.updateLimits(limits)
                orchestrator.onLoginSuccess()
            }
            await MainActor.run {
                refreshTokenValidating = false
                withAnimation(.spring(duration: 0.25)) { refreshingTokenProfile = nil }
                refreshTokenInput = ""; refreshTokenError = nil
            }
        } catch LimitsPoller.PollerError.unauthorized {
            await MainActor.run {
                refreshTokenValidating = false
                refreshTokenError = L10n.s("Токен недействителен или истёк", "Token is invalid or expired")
            }
        } catch LimitsPoller.PollerError.missingOrgId {
            // Token valid but org ID needed — accept it anyway, mark valid, orgId can be set separately
            try? accountStore.updateToken(token, for: profile.id)
            accountStore.markTokenStatus(id: profile.id, valid: true)
            if accountStore.activeId == profile.id { orchestrator.onLoginSuccess() }
            await MainActor.run {
                refreshTokenValidating = false
                withAnimation(.spring(duration: 0.25)) { refreshingTokenProfile = nil }
                refreshTokenInput = ""; refreshTokenError = nil
            }
        } catch LimitsPoller.PollerError.unexpectedResponse {
            try? accountStore.updateToken(token, for: profile.id)
            accountStore.markTokenStatus(id: profile.id, valid: true)
            if accountStore.activeId == profile.id { orchestrator.onLoginSuccess() }
            await MainActor.run {
                refreshTokenValidating = false
                withAnimation(.spring(duration: 0.25)) { refreshingTokenProfile = nil }
                refreshTokenInput = ""; refreshTokenError = nil
            }
        } catch {
            await MainActor.run {
                refreshTokenValidating = false
                refreshTokenError = L10n.s("Ошибка сети. Проверьте интернет.", "Network error. Check your connection.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image("ClaudeLogo")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(textPrimary.opacity(0.8))
            Text("TokenTracker")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)
            Spacer()
            Button { sync() } label: {
                HStack(spacing: 5) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.55)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isSyncing ? L10n.syncing : L10n.sync)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textPrimary.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isDark ? Color.white.opacity(0.08) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isSyncing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(appBg)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.icon) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { activeTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(activeTab == tab ? textPrimary : textTertiary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(appBg)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Tab: Dashboard

    private var dashboardTab: some View {
        let history = HistoryStore.shared.load()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        let previousProjects = history.reversed().first { $0.date != today && $0.projects != nil }?.projects ?? []
        return Group {
            SmartStatusCard(
                status: UsageAnalytics.status(for: orchestrator.usage, history: history, now: now),
                updatedAt: orchestrator.usage.limitsUpdatedAt ?? orchestrator.usage.tokensUpdatedAt
            )
            LimitIntelligenceCard(
                limits: orchestrator.usage.limits,
                updatedAt: orchestrator.usage.limitsUpdatedAt,
                isLoggedIn: orchestrator.isLoggedIn,
                hasOrgId: !(accountStore.activeProfile?.orgId ?? "").isEmpty,
                now: now
            )
            statsSection
            chartSection
            ProjectInsightsCard(
                insights: UsageAnalytics.projectInsights(
                    current: orchestrator.usage.topProjects,
                    previous: previousProjects
                )
            )
        }
    }

    private var limitsSection: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.limits, updated: orchestrator.usage.limitsUpdatedAt)
                if let updated = orchestrator.usage.limitsUpdatedAt,
                   Date().timeIntervalSince(updated) > 7200 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange.opacity(0.8))
                        Text(L10n.dataOutdated)
                            .font(.system(size: 10))
                            .foregroundStyle(.orange.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }
                if let limits = orchestrator.usage.limits {
                    VStack(spacing: 12) {
                        limitRow(L10n.fiveHourLabel,
                                 limits.fiveHourPercent,
                                 limits.fiveHourUtilization,
                                 resetsAt: limits.fiveHourResetsAt)
                        limitRow(L10n.weeklyLabel,
                                 limits.weeklyPercent,
                                 limits.weeklyUtilization,
                                 resetsAt: limits.weeklyResetsAt)
                        if let su = limits.sonnetUtilization {
                            limitRow(L10n.s("Sonnet (7д)", "Sonnet (7d)"), su / 100, su, resetsAt: nil)
                        }
                        if let ou = limits.opusUtilization {
                            limitRow(L10n.s("Opus (7д)", "Opus (7d)"), ou / 100, ou, resetsAt: nil)
                        }
                        if let used = limits.extraUsageUsed,
                           let cap = limits.extraUsageLimit,
                           limits.extraUsageEnabled, cap > 0 {
                            limitRow(
                                L10n.s("Кредиты $\(Int(used))/$\(Int(cap))", "Credits $\(Int(used))/$\(Int(cap))"),
                                used / cap,
                                used / cap * 100,
                                resetsAt: nil
                            )
                        }
                    }
                } else if orchestrator.isLoggedIn && (accountStore.activeProfile?.orgId ?? "").isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.s("Лимиты недоступны", "Limits unavailable"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textSecondary)
                        Text(L10n.s("Укажите Org ID в настройках аккаунта", "Set Org ID in the account settings"))
                            .font(.system(size: 11))
                            .foregroundStyle(textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                } else if orchestrator.isLoggedIn {
                    Text(L10n.s("Загрузка лимитов…", "Loading limits…"))
                        .font(.system(size: 12))
                        .foregroundStyle(textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                } else {
                    Text(L10n.loginForLimits)
                        .font(.system(size: 12))
                        .foregroundStyle(textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var statsSection: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.today, updated: orchestrator.usage.tokensUpdatedAt)
                VStack(spacing: 10) {
                    statRow(L10n.cost,
                            "$\(String(format: "%.4f", orchestrator.usage.costToday))",
                            icon: "dollarsign.circle")
                    statRow(L10n.tokens,
                            formatTokens(orchestrator.usage.tokensToday),
                            icon: "cpu")
                    statRow(L10n.sessions,
                            "\(orchestrator.usage.sessionsToday)",
                            icon: "terminal")
                }
            }
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        if orchestrator.usage.hourlyUsage.contains(where: { $0 > 0 }) {
            DarkCard {
                VStack(alignment: .leading, spacing: 10) {
                    cardHeader(L10n.dailyActivity, updated: nil)
                    HourlyBarChart(hourlyUsage: orchestrator.usage.hourlyUsage)
                        .frame(height: 80)
                    HStack {
                        Text("0:00"); Spacer()
                        Text("6:00"); Spacer()
                        Text("12:00"); Spacer()
                        Text("18:00"); Spacer()
                        Text(L10n.now)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var projectsSection: some View {
        let projects = orchestrator.usage.topProjects
        if !projects.isEmpty {
            DarkCard {
                VStack(spacing: 0) {
                    cardHeader(L10n.s("Проекты сегодня", "Projects today"), updated: nil)
                    VStack(spacing: 8) {
                        let maxTokens = projects.first?.tokens ?? 1
                        ForEach(projects) { project in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(project.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(textPrimary.opacity(0.7))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text("$\(String(format: "%.4f", project.cost))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(textTertiary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2).fill(isDark ? Color.white.opacity(0.06) : Color(.separatorColor).opacity(0.3))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(isDark ? Color.white.opacity(0.4) : Color.accentColor.opacity(0.4))
                                            .frame(width: geo.size.width * CGFloat(project.tokens) / CGFloat(maxTokens))
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab: Account

    @State private var editingOrgIdFor: UUID? = nil
    @State private var orgIdDraft = ""
    @FocusState private var orgIdFieldFocused: Bool
    @ObservedObject private var accountStore = AccountStore.shared
    @State private var showAddAccount = false
    @State private var refreshingTokenProfile: AccountProfile? = nil
    @State private var refreshTokenInput = ""
    @State private var refreshTokenValidating = false
    @State private var refreshTokenError: String? = nil

    private var accountTab: some View {
        Group {
            accountsSection
            sessionSection
            signOutSection
        }
    }

    private var accountsSection: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.s("Аккаунты", "Accounts"), updated: nil)
                VStack(spacing: 8) {
                    ForEach(accountStore.profiles) { profile in
                        let isActive = accountStore.activeId == profile.id
                        VStack(spacing: 0) {
                            // — Main row —
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(isActive ? Color.purple.opacity(0.22) : (isDark ? Color.white.opacity(0.06) : Color(.separatorColor).opacity(0.4)))
                                        .overlay(Circle().strokeBorder(
                                            isActive ? Color.purple.opacity(0.35) : (isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.5)),
                                            lineWidth: 1))
                                        .frame(width: 36, height: 36)
                                    Text(profile.initials)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isActive ? .white : textSecondary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(textPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(profile.tokenValid ? Color.green : Color.red)
                                            .frame(width: 5, height: 5)
                                        Text(profile.tokenValid
                                             ? L10n.s("Токен активен", "Token active")
                                             : L10n.s("Токен истёк", "Token expired"))
                                            .font(.system(size: 10))
                                            .foregroundStyle(profile.tokenValid ? .green.opacity(0.7) : .red.opacity(0.7))
                                    }
                                }

                                Spacer()

                                HStack(spacing: 6) {
                                    if !profile.tokenValid {
                                        Button {
                                            refreshTokenInput = ""
                                            refreshTokenError = nil
                                            refreshingTokenProfile = profile
                                        } label: {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.orange.opacity(0.85))
                                                .frame(width: 28, height: 22)
                                                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(.plain)
                                        .help(L10n.s("Обновить токен", "Refresh token"))
                                    }

                                    if !isActive {
                                        Button { orchestrator.switchAccount(profile) } label: {
                                            Image(systemName: "arrow.left.arrow.right")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(textSecondary)
                                                .frame(width: 28, height: 22)
                                                .background(isDark ? Color.white.opacity(0.08) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(.plain)
                                        .help(L10n.switchAccount)
                                    } else {
                                        Text(L10n.s("Активен", "Active"))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.purple.opacity(0.85))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(.purple.opacity(0.12), in: Capsule())
                                    }

                                    if accountStore.profiles.count > 1 {
                                        Button { accountStore.remove(profile) } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.red.opacity(0.4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)

                            // — Org ID row —
                            Divider()

                            if editingOrgIdFor == profile.id {
                                VStack(spacing: 7) {
                                    TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $orgIdDraft)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(textPrimary)
                                        .focused($orgIdFieldFocused)
                                        .padding(.horizontal, 8).padding(.vertical, 6)
                                        .background(isDark ? Color.white.opacity(0.06) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isDark ? Color.white.opacity(0.1) : Color(.separatorColor).opacity(0.4), lineWidth: 0.5))
                                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { orgIdFieldFocused = true } }
                                    HStack {
                                        Button(L10n.s("Отмена", "Cancel")) { editingOrgIdFor = nil; orgIdDraft = "" }
                                            .font(.system(size: 10)).foregroundStyle(textSecondary).buttonStyle(.plain)
                                        Spacer()
                                        Button(L10n.s("Сохранить", "Save")) {
                                            let v = orgIdDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !v.isEmpty { accountStore.updateOrgId(v, for: profile.id) }
                                            editingOrgIdFor = nil; orgIdDraft = ""
                                            orchestrator.forceRefresh()
                                        }
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(orgIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? textTertiary : textPrimary)
                                        .buttonStyle(.plain)
                                        .disabled(orgIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                            } else {
                                HStack(spacing: 6) {
                                    Text("Org ID")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(textTertiary)
                                    if !profile.orgId.isEmpty {
                                        Text(profile.orgId)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(textTertiary)
                                            .lineLimit(1).truncationMode(.middle)
                                    } else {
                                        Text(L10n.s("Не задан", "Not set"))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange.opacity(0.55))
                                    }
                                    Spacer()
                                    Button {
                                        orgIdDraft = profile.orgId
                                        editingOrgIdFor = profile.id
                                    } label: {
                                        Text(profile.orgId.isEmpty ? L10n.s("Добавить", "Add") : L10n.s("Изменить", "Edit"))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(textTertiary)
                                            .padding(.horizontal, 7).padding(.vertical, 2)
                                            .overlay(Capsule().strokeBorder(isDark ? .white.opacity(0.12) : Color(.separatorColor).opacity(0.5), lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isActive
                                      ? (isDark ? .white.opacity(0.05) : Color(.controlBackgroundColor))
                                      : (isDark ? .white.opacity(0.025) : Color(.windowBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(isDark
                                                  ? (isActive ? .white.opacity(0.1) : .white.opacity(0.06))
                                                  : Color(.separatorColor).opacity(isActive ? 0.4 : 0.2), lineWidth: 0.5))
                        )
                    }

                    Divider()

                    if accountStore.profiles.count < 5 {
                    Button {
                        showAddAccount = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                            Text(L10n.addAccount)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(isDark ? .white.opacity(0.05) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isDark ? .white.opacity(0.08) : Color(.separatorColor).opacity(0.4), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    } // if count < 5
                }
            }
        }
    }


    private func instructionRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(textSecondary)
                .frame(width: 14, height: 14)
                .background(Circle().fill(isDark ? .white.opacity(0.08) : Color(.controlBackgroundColor)))
            Text(LocalizedStringKey(text))
                .font(.system(size: 10))
                .foregroundStyle(textSecondary)
                .lineSpacing(2)
        }
    }

    private var avatarSection: some View {
        DarkCard {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.08) : Color(.controlBackgroundColor))
                        .overlay(Circle().strokeBorder(isDark ? Color.white.opacity(0.12) : Color(.separatorColor).opacity(0.4), lineWidth: 0.5))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(textSecondary)
                }

                VStack(spacing: 6) {
                    subscriptionBadge
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private var subscriptionBadge: some View {
        let label = subscriptionDisplayName()
        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isDark ? Color.white.opacity(0.1) : Color(.controlBackgroundColor), in: Capsule())
            .overlay(Capsule().strokeBorder(isDark ? Color.white.opacity(0.15) : Color(.separatorColor).opacity(0.6), lineWidth: 0.5))
    }

    private var sessionSection: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.session, updated: nil)
                VStack(spacing: 10) {
                    HStack {
                        IconLabel(text: L10n.sessionKey, icon: "key.fill")
                        Spacer()
                        HStack(spacing: 4) {
                            Text("••••••••••••••••••••")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(textTertiary)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(textTertiary)
                        }
                    }
                    HStack {
                        IconLabel(text: L10n.status, icon: "checkmark.shield.fill")
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(AccountStore.shared.activeToken() != nil ? Color.green.opacity(0.8) : Color.red.opacity(0.7))
                                .frame(width: 6, height: 6)
                            Text(AccountStore.shared.activeToken() != nil ? L10n.statusActive : L10n.statusUnauthorized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(textPrimary.opacity(0.7))
                        }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 9))
                            .foregroundStyle(textTertiary)
                        Text(L10n.s("Хранится в Keychain macOS", "Stored in macOS Keychain"))
                            .font(.system(size: 10))
                            .foregroundStyle(textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var signOutSection: some View {
        Button {
            orchestrator.logout()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13))
                Text(L10n.signOut)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.red.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.red.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab: Settings

    private var settingsTab: some View {
        Group {
            behaviorSection
            widgetHealthSection
            widgetAccountSection
            notificationsSection
            budgetSection
            aboutSection
        }
    }

    // MARK: - Widget account section

    private var widgetHealthSection: some View {
        let manifest = SharedStore.readAccountsManifest()
        let usage = widgetUsage(for: manifest)
        return WidgetHealthCard(
            health: UsageAnalytics.widgetHealth(usage: usage, manifest: manifest, now: now),
            accountLabel: widgetAccountLabel(for: manifest)
        )
    }

    private var widgetAccountSection: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.s("Виджет", "Widget"), updated: nil)
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.s("Аккаунт в виджете", "Widget account"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(textPrimary.opacity(0.7))
                            Text(L10n.s("Какие данные показывает виджет", "Which account data the widget displays"))
                                .font(.system(size: 10))
                                .foregroundStyle(textTertiary)
                        }
                        Spacer()
                    }

                    // "Active account" option
                    widgetAccountRow(id: nil,
                                     name: L10n.s("Активный аккаунт", "Active account"),
                                     subtitle: L10n.s("Следует за выбором в приложении", "Follows app's active account"))

                    // One row per profile
                    ForEach(accountStore.profiles) { profile in
                        widgetAccountRow(id: profile.id,
                                         name: profile.displayName,
                                         subtitle: profile.orgId.isEmpty
                                             ? L10n.s("Org ID не задан", "Org ID not set")
                                             : String(profile.orgId.prefix(8)) + "…")
                    }
                }
            }
        }
    }

    @State private var widgetAccountId: UUID? = SharedStore.readAccountsManifest().widgetAccountId

    private func widgetUsage(for manifest: SharedStore.AccountsManifest) -> UsageData {
        if let widgetId = manifest.widgetAccountId, widgetId != manifest.activeId {
            return SharedStore.readAccount(id: widgetId)
        }
        return SharedStore.read()
    }

    private func widgetAccountLabel(for manifest: SharedStore.AccountsManifest) -> String {
        guard let selectedId = manifest.widgetAccountId else {
            return L10n.s("Активный аккаунт", "Active account")
        }

        if let entry = manifest.accounts.first(where: { $0.id == selectedId }) {
            return entry.name.isEmpty
                ? L10n.s("Выбранный аккаунт", "Selected account")
                : entry.name
        }

        if let profile = accountStore.profiles.first(where: { $0.id == selectedId }) {
            return profile.displayName
        }

        return L10n.s("Выбранный аккаунт недоступен", "Selected account unavailable")
    }

    private func widgetAccountRow(id: UUID?, name: String, subtitle: String) -> some View {
        let selected = widgetAccountId == id
        return HStack(spacing: 10) {
            Circle()
                .fill(selected ? Color.purple : (isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.4)))
                .overlay(Circle().strokeBorder(
                    selected ? Color.purple.opacity(0.6) : (isDark ? Color.white.opacity(0.12) : Color(.separatorColor).opacity(0.5)), lineWidth: 0.5))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? (isDark ? .white : textPrimary) : textPrimary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.purple)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color.purple.opacity(isDark ? 0.12 : 0.08) : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 0.5))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            widgetAccountId = id
            SharedStore.setWidgetAccount(id)
        }
    }

    private var budgetSection: some View {
        BudgetCard(currentSpend: orchestrator.usage.costToday)
    }

    private var projectsFolderLabel: String {
        let url = ClaudeCodeReader.defaultProjectsDir
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private var behaviorSection: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.behavior, updated: nil)
                VStack(spacing: 10) {
                    LaunchAtLoginToggle()
                    Divider()
                    DockToggleRow()
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        IconLabel(text: L10n.s("Тема оформления", "App theme"), icon: "circle.lefthalf.filled")
                        Picker("", selection: $appColorScheme) {
                            Text(L10n.s("Системная", "System")).tag("system")
                            Text(L10n.s("Светлая", "Light")).tag("light")
                            Text(L10n.s("Тёмная", "Dark")).tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            IconLabel(text: L10n.projectsFolder, icon: "folder.fill")
                            Spacer()
                            Text(projectsFolderLabel)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(textTertiary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        Button {
                            orchestrator.updateProjectsFolder()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 11))
                                Text(L10n.s("Выбрать папку…", "Choose folder…"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isDark ? Color.white.opacity(0.06) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isDark ? Color.white.opacity(0.12) : Color(.separatorColor).opacity(0.4), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var notificationsSection: some View {
        NotificationsCard()
    }

    private var aboutSection: some View {
        DarkCard {
            VStack(spacing: 10) {
                // Header row: name + version
                HStack {
                    Text("TokenTracker")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.7))
                    Spacer()
                    Text("v\(appVersion())")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(textTertiary)
                }

                // Update banner
                // "Just updated" success banner
                if let prev = orchestrator.justUpdatedFrom {
                    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.s("Обновление установлено", "Update installed"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                            Text(L10n.s("v\(prev) → v\(current)", "v\(prev) → v\(current)"))
                                .font(.system(size: 10))
                                .foregroundStyle(.green.opacity(0.7))
                        }
                        Spacer()
                        Button { orchestrator.dismissUpdateBanner() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.green.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.green.opacity(0.15), lineWidth: 0.5))
                }

                // Update available banner
                if let ver = orchestrator.updateAvailable {
                    let checker = UpdateChecker.shared
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                            Text(L10n.s("Доступно обновление \(ver)", "Update available \(ver)"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                            Spacer()
                            Button { checker.downloadAndOpen() } label: {
                                Group {
                                    if checker.isInstalling {
                                        HStack(spacing: 4) {
                                            ProgressView().controlSize(.mini).tint(.green)
                                            Text(L10n.s("Установка…", "Installing…"))
                                                .font(.system(size: 10))
                                                .foregroundStyle(.green.opacity(0.8))
                                        }
                                    } else if checker.isDownloading {
                                        HStack(spacing: 4) {
                                            ProgressView().controlSize(.mini).tint(.green)
                                            Text("\(Int(checker.downloadProgress * 100))%")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.green.opacity(0.7))
                                        }
                                    } else {
                                        Text(L10n.s("Установить", "Install"))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.green.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(checker.isDownloading || checker.isInstalling)
                        }
                        if checker.isDownloading {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.4)).frame(height: 3)
                                    RoundedRectangle(cornerRadius: 2).fill(.green.opacity(0.6))
                                        .frame(width: geo.size.width * checker.downloadProgress, height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.green.opacity(0.15), lineWidth: 0.5))
                }

                Divider()

                // Compact stats
                VStack(spacing: 6) {
                    statRow(L10n.limitsRefresh, L10n.every60s, icon: "clock.arrow.circlepath")
                    statRow(L10n.tokensRefresh, L10n.realtime, icon: "bolt.fill")
                }

                Divider()

                // 2×2 link grid
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        linkChip(L10n.viewOnGitHub, icon: "arrow.up.right.square",
                                 url: "https://github.com/avedevelop/TokenTracker")
                        linkChip(L10n.starOnGitHub, icon: "star",
                                 url: "https://github.com/avedevelop/TokenTracker")
                    }
                    HStack(spacing: 6) {
                        linkChip("FAQ", icon: "questionmark.circle",
                                 url: "https://github.com/avedevelop/TokenTracker/blob/main/FAQ.md")
                        linkChip(L10n.s("Условия", "Terms"), icon: "doc.text",
                                 url: "https://github.com/avedevelop/TokenTracker/blob/main/TERMS.md")
                    }
                    checkUpdatesButton
                }
            }
        }
    }

    @State private var isCheckingUpdate = false

    private var checkUpdatesButton: some View {
        Button {
            isCheckingUpdate = true
            Task {
                let start = Date()
                await orchestrator.checkForUpdates()
                // Минимум 1.2с чтобы спиннер был заметен
                let elapsed = Date().timeIntervalSince(start)
                if elapsed < 1.2 { try? await Task.sleep(nanoseconds: UInt64((1.2 - elapsed) * 1_000_000_000)) }
                isCheckingUpdate = false
                if orchestrator.updateAvailable == nil {
                    noUpdateToast = true
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    noUpdateToast = false
                }
            }
        } label: {
            HStack(spacing: 5) {
                if isCheckingUpdate {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.55).frame(width: 12, height: 12)
                } else {
                    Image(systemName: noUpdateToast ? "checkmark" : "arrow.clockwise")
                        .font(.system(size: 11))
                }
                Text(noUpdateToast
                     ? L10n.s("Уже актуальная версия", "Already up to date")
                     : L10n.s("Проверить обновления", "Check for updates"))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isDark ? Color.white.opacity(0.05) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isDark ? Color.white.opacity(0.08) : Color(.separatorColor), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(isCheckingUpdate)
    }

    private func linkChip(_ label: String, icon: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isDark ? Color.white.opacity(0.05) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isDark ? Color.white.opacity(0.08) : Color(.separatorColor), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func githubButton(label: String, icon: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(textPrimary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isDark ? Color.white.opacity(0.06) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isDark ? Color.white.opacity(0.1) : Color(.separatorColor), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String, updated: Date?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textTertiary)
                .kerning(0.3)
            Spacer()
            if let date = updated {
                Text("\(date, style: .relative)\(L10n.agoSuffix)")
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary.opacity(0.6))
            }
        }
        .padding(.bottom, 10)
    }

    private func limitRow(
        _ label: String, _ pct: Double, _ raw: Double, resetsAt: Date?
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondary)
                if let date = resetsAt, date.timeIntervalSince(now) > 0 {
                    Text("· \(resetLabel(date, relativeTo: now))")
                        .font(.system(size: 10))
                        .foregroundStyle(textTertiary)
                }
                Spacer()
                Text("\(Int(raw))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(pct > 0.8 ? .red : pct > 0.6 ? .orange : textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.4))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            pct > 0.8
                                ? Color.red.opacity(0.8)
                                : pct > 0.6
                                    ? Color.orange.opacity(0.8)
                                    : isDark ? Color.white.opacity(0.7) : Color.accentColor.opacity(0.7)
                        )
                        .frame(width: geo.size.width * min(pct, 1))
                }
            }
            .frame(height: 4)
        }
    }

    private func statRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(textTertiary)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
        }
    }

    private func resetLabel(_ date: Date, relativeTo base: Date = Date()) -> String {
        let d = date.timeIntervalSince(base)
        if d <= 0 { return L10n.didReset }
        let h = Int(d / 3600)
        let m = Int(d.truncatingRemainder(dividingBy: 3600) / 60)
        return h > 0
            ? "\(L10n.resetsLabel) \(h)\(L10n.hoursShort) \(m)\(L10n.minutesShort)"
            : "\(L10n.resetsLabel) \(m)\(L10n.minutesShort)"
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1_000_000
            ? String(format: "%.1fM", Double(n) / 1_000_000)
            : n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }

    private func maskedSessionKey() -> String {
        guard let key = AccountStore.shared.activeToken(), !key.isEmpty else { return "—" }
        let prefix = String(key.prefix(20))
        return "\(prefix)…"
    }

    private func subscriptionDisplayName() -> String {
        guard let json = LimitsPoller().readRawClaudeCodeCredentials(),
              let sub = json["subscriptionType"] as? String else {
            return "Claude"
        }
        switch sub {
        case "claude_max": return "Claude Max"
        case "pro":        return "Claude Pro"
        case "free":       return "Claude Free"
        default:           return sub.capitalized
        }
    }

    private func shortVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func appVersion() -> String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(ver) (\(build))"
    }

    private func sync() {
        isSyncing = true
        orchestrator.forceRefresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSyncing = false
        }
    }

    // MARK: - Tab: History

    private var historyTab: some View {
        InsightsView(
            historyDays: $historyDays,
            historyMetric: $historyMetric,
            exportedCSV: exportedCSV,
            onExport: exportCSV(records:)
        )
    }

    private func exportCSV(records: [DayRecord]) {
        var lines = ["date,cost,tokens,sessions,max_5h_pct,max_weekly_pct"]
        for r in records {
            lines.append("\(r.date),\(String(format: "%.4f", r.cost)),\(r.tokens),\(r.sessions),\(String(format: "%.1f", r.maxFiveHourPct)),\(String(format: "%.1f", r.maxWeeklyPct))")
        }
        let csv = lines.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "tokentracker-history.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                exportedCSV = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exportedCSV = false }
            } catch { }
        }
    }

}

// MARK: - Notifications Card (uses @AppStorage)

private struct NotificationsCard: View {
    @AppStorage("notif.enabled")   private var notifEnabled: Bool = true
    @AppStorage("notif.threshold") private var threshold: Double = 0.8
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var textSecondary: Color { isDark ? .white.opacity(0.45) : .secondary }

    var body: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.notifications)
                VStack(spacing: 10) {
                    // Enable toggle
                    HStack {
                        IconLabel(text: L10n.limitNotifications, icon: "bell.badge.fill")
                        Spacer()
                        Toggle("", isOn: $notifEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }

                    // Threshold row — shown only when enabled
                    if notifEnabled {
                        Divider()
                        VStack(spacing: 6) {
                            HStack {
                                IconLabel(text: L10n.notificationThreshold, icon: "slider.horizontal.3")
                                Spacer()
                                Text("\(Int(threshold * 100))%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(textSecondary)
                            }
                            Slider(value: $threshold, in: 0.5...1.0, step: 0.05)
                        }
                    }
                }
            }
        }
    }

    private func cardHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textSecondary)
                .kerning(0.3)
            Spacer()
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Budget Card

private struct BudgetCard: View {
    let currentSpend: Double

    @AppStorage("budget.daily")   private var dailyBudget: Double = 0
    @AppStorage("budget.monthly") private var monthlyBudget: Double = 0
    @State private var budgetEnabled: Bool = false
    @State private var monthlyEnabled: Bool = false
    @State private var customAmount: String = ""
    @State private var showingCustomField: Bool = false
    @State private var customMonthlyAmount: String = ""
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var textPrimary: Color { isDark ? .white : Color(.labelColor) }
    private var textSecondary: Color { isDark ? .white.opacity(0.45) : .secondary }
    @State private var showingMonthlyCustomField: Bool = false

    private let presets: [Double] = [5, 10, 25, 50]
    private let monthlyPresets: [Double] = [50, 100, 250, 500]

    private var monthlySpend: Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        return HistoryStore.shared.load()
            .filter { $0.date.hasPrefix(currentMonth) }
            .map(\.cost)
            .reduce(0, +)
    }

    var body: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.s("Бюджет", "Budget"))
                VStack(spacing: 10) {
                    HStack {
                        IconLabel(text: L10n.s("Лимит расходов", "Spend limit"), icon: "creditcard.fill")
                        Spacer()
                        Toggle("", isOn: $budgetEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: budgetEnabled) { _, enabled in
                                if !enabled { dailyBudget = 0 }
                                else if dailyBudget == 0 { dailyBudget = 10 }
                            }
                    }

                    if budgetEnabled {
                        Divider()

                        // Preset buttons
                        HStack(spacing: 6) {
                            ForEach(presets, id: \.self) { amount in
                                Button {
                                    dailyBudget = amount
                                    showingCustomField = false
                                } label: {
                                    let active = dailyBudget == amount && !showingCustomField
                                    Text("$\(Int(amount))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(active ? textPrimary : textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(active
                                                    ? (isDark ? Color.white.opacity(0.15) : Color.accentColor.opacity(0.12))
                                                    : (isDark ? Color.white.opacity(0.05) : Color(.controlBackgroundColor)))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                showingCustomField.toggle()
                                if showingCustomField {
                                    customAmount = dailyBudget > 0 && !presets.contains(dailyBudget)
                                        ? String(format: "%.2f", dailyBudget)
                                        : ""
                                }
                            } label: {
                                Text(L10n.s("Своё", "Custom"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(showingCustomField ? textPrimary : textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(showingCustomField
                                                ? (isDark ? Color.white.opacity(0.15) : Color.accentColor.opacity(0.12))
                                                : (isDark ? Color.white.opacity(0.05) : Color(.controlBackgroundColor)))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if showingCustomField {
                            HStack(spacing: 8) {
                                Text("$")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(textSecondary)
                                TextField("0.00", text: $customAmount)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(textPrimary)
                                    .onSubmit {
                                        if let val = Double(customAmount), val > 0 {
                                            dailyBudget = val
                                            showingCustomField = false
                                        }
                                    }
                                Button("OK") {
                                    if let val = Double(customAmount), val > 0 {
                                        dailyBudget = val
                                        showingCustomField = false
                                    }
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(textSecondary)
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isDark ? Color.white.opacity(0.06) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }

                        Divider()

                        // Today's spend vs budget
                        let pct = dailyBudget > 0 ? min(currentSpend / dailyBudget, 1.0) : 0
                        VStack(spacing: 6) {
                            HStack {
                                Text(L10n.today)
                                    .font(.system(size: 11))
                                    .foregroundStyle(textSecondary)
                                Spacer()
                                Text(String(format: "$%.2f / $%.2f", currentSpend, dailyBudget))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(pct >= 1.0 ? .red : pct >= 0.8 ? .orange : textPrimary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.3))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(pct >= 1.0 ? Color.red.opacity(0.8) : pct >= 0.8 ? Color.orange.opacity(0.8) : Color.accentColor.opacity(0.7))
                                        .frame(width: geo.size.width * pct)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                }

                // MARK: - Monthly budget section
                Divider().padding(.vertical, 10)

                cardHeader(L10n.monthlyBudget)
                VStack(spacing: 10) {
                    HStack {
                        IconLabel(text: L10n.s("Месячный лимит", "Monthly limit"), icon: "calendar.badge.clock")
                        Spacer()
                        Toggle("", isOn: $monthlyEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: monthlyEnabled) { _, enabled in
                                if !enabled { monthlyBudget = 0 }
                                else if monthlyBudget == 0 { monthlyBudget = 100 }
                            }
                    }

                    if monthlyEnabled {
                        Divider()

                        HStack(spacing: 6) {
                            ForEach(monthlyPresets, id: \.self) { amount in
                                Button {
                                    monthlyBudget = amount
                                    showingMonthlyCustomField = false
                                } label: {
                                    let active = monthlyBudget == amount && !showingMonthlyCustomField
                                    Text("$\(Int(amount))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(active ? textPrimary : textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(active
                                                    ? (isDark ? Color.white.opacity(0.15) : Color.accentColor.opacity(0.12))
                                                    : (isDark ? Color.white.opacity(0.05) : Color(.controlBackgroundColor)))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                showingMonthlyCustomField.toggle()
                                if showingMonthlyCustomField {
                                    customMonthlyAmount = monthlyBudget > 0 && !monthlyPresets.contains(monthlyBudget)
                                        ? String(format: "%.2f", monthlyBudget)
                                        : ""
                                }
                            } label: {
                                Text(L10n.s("Своё", "Custom"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(showingMonthlyCustomField ? textPrimary : textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(showingMonthlyCustomField
                                                ? (isDark ? Color.white.opacity(0.15) : Color.accentColor.opacity(0.12))
                                                : (isDark ? Color.white.opacity(0.05) : Color(.controlBackgroundColor)))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if showingMonthlyCustomField {
                            HStack(spacing: 8) {
                                Text("$")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(textSecondary)
                                TextField("0.00", text: $customMonthlyAmount)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(textPrimary)
                                    .onSubmit {
                                        if let val = Double(customMonthlyAmount), val > 0 {
                                            monthlyBudget = val
                                            showingMonthlyCustomField = false
                                        }
                                    }
                                Button("OK") {
                                    if let val = Double(customMonthlyAmount), val > 0 {
                                        monthlyBudget = val
                                        showingMonthlyCustomField = false
                                    }
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(textSecondary)
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isDark ? Color.white.opacity(0.06) : Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }

                        Divider()

                        let spend = monthlySpend
                        let mPct = monthlyBudget > 0 ? min(spend / monthlyBudget, 1.0) : 0
                        VStack(spacing: 6) {
                            HStack {
                                Text(L10n.s("Этот месяц", "This month"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(textSecondary)
                                Spacer()
                                Text(String(format: "$%.2f / $%.2f", spend, monthlyBudget))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(mPct >= 1.0 ? .red : mPct >= 0.8 ? .orange : textPrimary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(isDark ? Color.white.opacity(0.08) : Color(.separatorColor).opacity(0.3))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(mPct >= 1.0 ? Color.red.opacity(0.8) : mPct >= 0.8 ? Color.orange.opacity(0.8) : Color.accentColor.opacity(0.7))
                                        .frame(width: geo.size.width * mPct)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                }
            }
        }
        .onAppear {
            budgetEnabled = dailyBudget > 0
            monthlyEnabled = monthlyBudget > 0
        }
    }

    private func cardHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textSecondary)
                .kerning(0.3)
            Spacer()
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Launch at Login Toggle

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            IconLabel(text: L10n.launchAtLogin, icon: "power")
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.accentColor)
                .onChange(of: isEnabled) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        isEnabled = !newValue
                    }
                }
        }
    }
}

// MARK: - Dock Toggle

private struct DockToggleRow: View {
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true

    var body: some View {
        HStack {
            IconLabel(text: L10n.s("Иконка в строке меню", "Menu bar icon"), icon: "menubar.rectangle")
            Spacer()
            Toggle("", isOn: $showMenuBarIcon)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.accentColor)
                .onChange(of: showMenuBarIcon) { _, newValue in
                    (NSApplication.shared.delegate as? AppDelegate)?.setShowMenuBarIcon(newValue)
                }
        }
    }
}

// MARK: - IconLabel (fixed-width icon for alignment)

private struct IconLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let icon: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 16, alignment: .center)
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.35) : .secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.45) : Color(.labelColor))
        }
    }
}

// MARK: - DarkCard

struct DarkCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .background(
                Group {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(.separatorColor).opacity(0.8), lineWidth: 1))
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                }
            )
    }
}

// MARK: - Hourly Bar Chart

struct HourlyBarChart: View {
    let hourlyUsage: [Int]
    @State private var hoveredHour: Int? = nil
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000)
            : n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }

    var body: some View {
        let maxVal = max(hourlyUsage.max() ?? 1, 1)
        let barActive: Color = isDark ? .white.opacity(0.55) : Color.accentColor.opacity(0.6)
        let barEmpty: Color = isDark ? .white.opacity(0.08) : Color(.separatorColor).opacity(0.3)
        let barHover: Color = isDark ? .white.opacity(0.9) : Color.accentColor.opacity(0.9)

        VStack(spacing: 4) {
            ZStack {
                if let h = hoveredHour, hourlyUsage[h] > 0 {
                    Text("\(String(format: "%02d", h)):00  \(fmt(hourlyUsage[h]))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isDark ? .white : Color(.labelColor))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(isDark ? .white.opacity(0.15) : Color(.controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isDark ? .white.opacity(0.2) : Color(.separatorColor).opacity(0.4), lineWidth: 0.5))
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .frame(height: 20)
            .animation(.easeInOut(duration: 0.12), value: hoveredHour)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<hourlyUsage.count, id: \.self) { h in
                    let v = hourlyUsage[h]
                    let pct = Double(v) / Double(maxVal)
                    let past = h <= Calendar.current.component(.hour, from: Date())
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hoveredHour == h && v > 0 ? barHover
                              : past && v > 0 ? barActive : barEmpty)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(y: max(pct, 0.04), anchor: .bottom)
                        .onHover { hoveredHour = $0 ? h : nil }
                }
            }
        }
    }
}

// MARK: - Limit Bar Chart (5h utilisation %)

struct LimitBarChart: View {
    let records: [DayRecord]
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    private func dayLabel(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "" }
        let df = DateFormatter(); df.dateFormat = "d"
        return df.string(from: d)
    }

    var body: some View {
        let allZero = records.allSatisfy { $0.maxFiveHourPct == 0 }
        let barNormal: Color = isDark ? .white.opacity(0.55) : Color.accentColor.opacity(0.5)
        let barEmpty: Color = isDark ? .white.opacity(0.08) : Color(.separatorColor).opacity(0.25)

        if allZero || records.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 20))
                    .foregroundStyle(isDark ? .white.opacity(0.15) : Color(.tertiaryLabelColor))
                Text(L10n.s("Нет данных за этот период", "No data for this period"))
                    .font(.system(size: 11))
                    .foregroundStyle(isDark ? .white.opacity(0.25) : Color(.secondaryLabelColor))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: records.count > 15 ? 2 : 5) {
                ForEach(records) { record in
                    let pct = record.maxFiveHourPct / 100.0
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(pct > 0.8 ? Color.red.opacity(0.7)
                                  : pct > 0.6 ? Color.orange.opacity(0.7)
                                  : pct > 0 ? barNormal : barEmpty)
                            .frame(maxHeight: .infinity)
                            .scaleEffect(y: max(pct, pct > 0 ? 0.04 : 0.02), anchor: .bottom)
                        if records.count <= 14 {
                            Text(dayLabel(record.date))
                                .font(.system(size: 8))
                                .foregroundStyle(isDark ? .white.opacity(0.2) : Color(.tertiaryLabelColor))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Weekly Bar Chart

struct WeeklyBarChart: View {
    let records: [DayRecord]
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }

    private func dayLabel(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "" }
        let df = DateFormatter(); df.dateFormat = "d"
        return df.string(from: d)
    }

    var body: some View {
        let maxCost = max(records.map(\.cost).max() ?? 0, 0.001)
        let allZero = records.allSatisfy { $0.cost == 0 }
        let barActive: Color = isDark ? .white.opacity(0.55) : Color.accentColor.opacity(0.55)
        let barEmpty: Color = isDark ? .white.opacity(0.08) : Color(.separatorColor).opacity(0.25)

        if allZero || records.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 20))
                    .foregroundStyle(isDark ? .white.opacity(0.15) : Color(.tertiaryLabelColor))
                Text(L10n.s("Нет данных за этот период", "No data for this period"))
                    .font(.system(size: 11))
                    .foregroundStyle(isDark ? .white.opacity(0.25) : Color(.secondaryLabelColor))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: records.count > 15 ? 2 : 5) {
                ForEach(records) { record in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(record.cost > 0 ? barActive : barEmpty)
                            .frame(maxHeight: .infinity)
                            .scaleEffect(y: max(record.cost / maxCost, record.cost > 0 ? 0.04 : 0.02), anchor: .bottom)
                        if records.count <= 14 {
                            Text(dayLabel(record.date))
                                .font(.system(size: 8))
                                .foregroundStyle(isDark ? .white.opacity(0.2) : Color(.tertiaryLabelColor))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
