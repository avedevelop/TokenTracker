import SwiftUI
import WidgetKit
import ServiceManagement
import Combine
import UniformTypeIdentifiers

private let bg = Color(red: 0.09, green: 0.07, blue: 0.14)

struct SettingsView: View {
    @EnvironmentObject var orchestrator: AppOrchestrator
    @State private var isSyncing = false
    @State private var activeTab: AppTab = .dashboard
    @State private var now = Date()
    @State private var exportedCSV = false
    @State private var historyDays: Int = 7

    let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    enum AppTab: CaseIterable {
        case dashboard, history, account, settings

        var label: String {
            switch self {
            case .dashboard: return L10n.dashboard
            case .history:   return L10n.s("История", "History")
            case .account:   return L10n.account
            case .settings:  return L10n.settings
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .history:   return "calendar"
            case .account:   return "person.fill"
            case .settings:  return "gearshape.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

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
        .environment(\.colorScheme, .dark)
        .onReceive(countdownTimer) { date in now = date }
        .background(
            Button("") { activeTab = .settings }
                .keyboardShortcut(",", modifiers: .command)
                .opacity(0)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image("ClaudeLogo")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white.opacity(0.8))
            Text("TokenTracker")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
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
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isSyncing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
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
                    .foregroundStyle(activeTab == tab ? .white : .white.opacity(0.35))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(bg)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)
        }
    }

    // MARK: - Tab: Dashboard

    private var dashboardTab: some View {
        Group {
            limitsSection
            statsSection
            chartSection
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
                } else {
                    Text(L10n.loginForLimits)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
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
                    .foregroundStyle(.white.opacity(0.2))
                }
            }
        }
    }

    // MARK: - Tab: Account

    @State private var showOrgIdEditor = false
    @State private var orgIdDraft = ""
    @FocusState private var orgIdFieldFocused: Bool

    private var accountTab: some View {
        Group {
            avatarSection
            orgIdSection
            sessionSection
            signOutSection
        }
    }

    private var orgIdSection: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader("Org ID", updated: nil)
                let current = UserDefaults.standard.string(forKey: "com.tokentracker.orgId")

                if showOrgIdEditor {
                    VStack(alignment: .leading, spacing: 10) {
                        // Instructions
                        VStack(alignment: .leading, spacing: 6) {
                            instructionRow(1, L10n.s("Откройте **claude.ai** → **Cmd+Option+I**", "Open **claude.ai** → **Cmd+Option+I**"))
                            instructionRow(2, L10n.s("**Application** → **Cookies** → **claude.ai**", "**Application** → **Cookies** → **claude.ai**"))
                            instructionRow(3, L10n.s("Найдите **lastActiveOrg** → скопируйте", "Find **lastActiveOrg** → copy value"))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

                        TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $orgIdDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white)
                            .focused($orgIdFieldFocused)
                            .padding(10)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
                            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { orgIdFieldFocused = true } }

                        HStack {
                            Button(L10n.s("Отмена", "Cancel")) {
                                showOrgIdEditor = false
                                orgIdDraft = ""
                            }
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4)).buttonStyle(.plain)
                            Spacer()
                            Button(L10n.s("Сохранить", "Save")) {
                                let v = orgIdDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !v.isEmpty {
                                    UserDefaults.standard.set(v, forKey: "com.tokentracker.orgId")
                                }
                                showOrgIdEditor = false
                                orgIdDraft = ""
                                orchestrator.forceRefresh()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(orgIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.3) : .white)
                            .buttonStyle(.plain)
                            .disabled(orgIdDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                } else {
                    HStack {
                        if let id = current {
                            Text(id)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1).truncationMode(.middle)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11)).foregroundStyle(.orange.opacity(0.8))
                                Text(L10n.s("Не установлен", "Not set"))
                                    .font(.system(size: 12)).foregroundStyle(.orange.opacity(0.8))
                            }
                        }
                        Spacer()
                        Button {
                            orgIdDraft = current ?? ""
                            showOrgIdEditor = true
                        } label: {
                            Text(current == nil ? L10n.s("Добавить", "Add") : L10n.s("Изменить", "Edit"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func instructionRow(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 14, height: 14)
                .background(Circle().fill(.white.opacity(0.08)))
            Text(LocalizedStringKey(text))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .lineSpacing(2)
        }
    }

    private var avatarSection: some View {
        DarkCard {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.5))
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
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
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
                                .foregroundStyle(.white.opacity(0.3))
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                    }
                    HStack {
                        IconLabel(text: L10n.status, icon: "checkmark.shield.fill")
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(KeychainStore.load() != nil ? Color.green.opacity(0.8) : Color.red.opacity(0.7))
                                .frame(width: 6, height: 6)
                            Text(KeychainStore.load() != nil ? L10n.statusActive : L10n.statusUnauthorized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.2))
                        Text(L10n.s("Хранится в Keychain macOS", "Stored in macOS Keychain"))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
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
            notificationsSection
            budgetSection
            aboutSection
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
                    Divider().background(.white.opacity(0.06))
                    DockToggleRow()
                    Divider().background(.white.opacity(0.06))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            IconLabel(text: L10n.projectsFolder, icon: "folder.fill")
                            Spacer()
                            Text(projectsFolderLabel)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
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
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
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
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("v\(appVersion())")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Divider().background(.white.opacity(0.06))

                // Compact stats
                VStack(spacing: 6) {
                    statRow(L10n.limitsRefresh, L10n.every60s, icon: "clock.arrow.circlepath")
                    statRow(L10n.tokensRefresh, L10n.realtime, icon: "bolt.fill")
                }

                Divider().background(.white.opacity(0.06))

                // 2×2 link grid
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        linkChip(L10n.viewOnGitHub, icon: "arrow.up.right.square",
                                 url: "https://github.com/bvsmma/TokenTracker")
                        linkChip(L10n.starOnGitHub, icon: "star",
                                 url: "https://github.com/bvsmma/TokenTracker")
                    }
                    HStack(spacing: 6) {
                        linkChip("FAQ", icon: "questionmark.circle",
                                 url: "https://github.com/bvsmma/TokenTracker/blob/main/FAQ.md")
                        linkChip(L10n.s("Условия", "Terms"), icon: "doc.text",
                                 url: "https://github.com/bvsmma/TokenTracker/blob/main/TERMS.md")
                    }
                }
            }
        }
    }

    private func linkChip(_ label: String, icon: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
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
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String, updated: Date?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(0.3)
            Spacer()
            if let date = updated {
                Text("\(date, style: .relative)\(L10n.agoSuffix)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.2))
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
                    .foregroundStyle(.white.opacity(0.6))
                if let date = resetsAt, date.timeIntervalSince(now) > 0 {
                    Text("· \(resetLabel(date, relativeTo: now))")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                }
                Spacer()
                Text("\(Int(raw))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(pct > 0.8 ? .red : pct > 0.6 ? .orange : .white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            pct > 0.8
                                ? Color.red.opacity(0.8)
                                : pct > 0.6
                                    ? Color.orange.opacity(0.8)
                                    : Color.white.opacity(0.7)
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
                    .foregroundStyle(.white.opacity(0.35))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
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
        guard let key = KeychainStore.load(), !key.isEmpty else { return "—" }
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
        let records = Array(HistoryStore.shared.load().suffix(historyDays))
        return Group {
            HStack(spacing: 6) {
                ForEach([7, 30, 90], id: \.self) { d in
                    Button {
                        historyDays = d
                    } label: {
                        Text("\(d) \(L10n.s("дн", "d"))")
                            .font(.system(size: 12, weight: historyDays == d ? .semibold : .regular))
                            .foregroundStyle(historyDays == d ? .white : .white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(historyDays == d ? .white.opacity(0.12) : .white.opacity(0.04))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(historyDays == d ? .white.opacity(0.2) : .clear, lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if records.isEmpty {
                DarkCard {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.2))
                        Text(L10n.s("История появится после первого дня использования", "History appears after your first day of usage"))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                DarkCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(historyDays) \(L10n.s("дн.", "days"))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.4))
                                let total = records.map(\.cost).reduce(0, +)
                                Text("$\(String(format: "%.2f", total))")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Button {
                                exportCSV(records: records)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: exportedCSV ? "checkmark" : "square.and.arrow.up")
                                        .font(.system(size: 11))
                                    Text(exportedCSV ? L10n.s("Экспортировано", "Exported") : "CSV")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        WeeklyBarChart(records: records)
                            .frame(height: 60)
                    }
                }

                ForEach(records.reversed()) { record in
                    DarkCard {
                        VStack(spacing: 8) {
                            HStack {
                                Text(formatHistoryDate(record.date))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                Spacer()
                                Text("$\(String(format: "%.2f", record.cost))")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Divider().background(.white.opacity(0.06))
                            HStack(spacing: 0) {
                                historyStatCell(L10n.s("Токены", "Tokens"), formatTokens(record.tokens), icon: "cpu")
                                historyStatCell(L10n.s("Сессии", "Sessions"), "\(record.sessions)", icon: "terminal")
                                historyStatCell(L10n.s("5ч макс", "5h max"), "\(Int(record.maxFiveHourPct))%", icon: "gauge.with.dots.needle.67percent")
                            }
                        }
                    }
                }
            }
        }
    }

    private func historyStatCell(_ label: String, _ value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Notifications Card (uses @AppStorage)

private struct NotificationsCard: View {
    @AppStorage("notif.enabled")   private var notifEnabled: Bool = true
    @AppStorage("notif.threshold") private var threshold: Double = 0.8

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
                            .tint(.white.opacity(0.6))
                    }

                    // Threshold row — shown only when enabled
                    if notifEnabled {
                        Divider().background(.white.opacity(0.06))
                        VStack(spacing: 6) {
                            HStack {
                                IconLabel(text: L10n.notificationThreshold, icon: "slider.horizontal.3")
                                Spacer()
                                Text("\(Int(threshold * 100))%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            Slider(value: $threshold, in: 0.5...1.0, step: 0.05)
                                .tint(.white.opacity(0.5))
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
                .foregroundStyle(.white.opacity(0.4))
                .kerning(0.3)
            Spacer()
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Budget Card

private struct BudgetCard: View {
    let currentSpend: Double

    @AppStorage("budget.daily") private var dailyBudget: Double = 0
    @State private var budgetEnabled: Bool = false
    @State private var customAmount: String = ""
    @State private var showingCustomField: Bool = false

    private let presets: [Double] = [5, 10, 25, 50]

    var body: some View {
        DarkCard {
            VStack(spacing: 0) {
                cardHeader(L10n.s("Дневной бюджет", "Daily budget"))
                VStack(spacing: 10) {
                    HStack {
                        IconLabel(text: L10n.s("Лимит расходов", "Spend limit"), icon: "creditcard.fill")
                        Spacer()
                        Toggle("", isOn: $budgetEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.white.opacity(0.6))
                            .onChange(of: budgetEnabled) { _, enabled in
                                if !enabled { dailyBudget = 0 }
                                else if dailyBudget == 0 { dailyBudget = 10 }
                            }
                    }

                    if budgetEnabled {
                        Divider().background(.white.opacity(0.06))

                        // Preset buttons
                        HStack(spacing: 6) {
                            ForEach(presets, id: \.self) { amount in
                                Button {
                                    dailyBudget = amount
                                    showingCustomField = false
                                } label: {
                                    Text("$\(Int(amount))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(dailyBudget == amount && !showingCustomField
                                            ? .white
                                            : .white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(dailyBudget == amount && !showingCustomField
                                                    ? .white.opacity(0.15)
                                                    : .white.opacity(0.05))
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
                                    .foregroundStyle(showingCustomField ? .white : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(showingCustomField
                                                ? .white.opacity(0.15)
                                                : .white.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if showingCustomField {
                            HStack(spacing: 8) {
                                Text("$")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                                TextField("0.00", text: $customAmount)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.white)
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
                                .foregroundStyle(.white.opacity(0.7))
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }

                        Divider().background(.white.opacity(0.06))

                        // Today's spend vs budget
                        let pct = dailyBudget > 0 ? min(currentSpend / dailyBudget, 1.0) : 0
                        VStack(spacing: 6) {
                            HStack {
                                Text(L10n.today)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.4))
                                Spacer()
                                Text(String(format: "$%.2f / $%.2f", currentSpend, dailyBudget))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(pct >= 1.0 ? .red : pct >= 0.8 ? .orange : .white.opacity(0.8))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(pct >= 1.0 ? Color.red.opacity(0.8) : pct >= 0.8 ? Color.orange.opacity(0.8) : Color.white.opacity(0.7))
                                        .frame(width: geo.size.width * pct)
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
        }
    }

    private func cardHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
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
                .tint(.white.opacity(0.6))
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
                .tint(.white.opacity(0.6))
                .onChange(of: showMenuBarIcon) { _, newValue in
                    (NSApplication.shared.delegate as? AppDelegate)?.setShowMenuBarIcon(newValue)
                }
        }
    }
}

// MARK: - IconLabel (fixed-width icon for alignment)

private struct IconLabel: View {
    let text: String
    let icon: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 16, alignment: .center)
                .foregroundStyle(.white.opacity(0.35))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

// MARK: - DarkCard

struct DarkCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Hourly Bar Chart

struct HourlyBarChart: View {
    let hourlyUsage: [Int]
    @State private var hoveredHour: Int? = nil

    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000)
            : n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }

    var body: some View {
        let maxVal = max(hourlyUsage.max() ?? 1, 1)
        VStack(spacing: 4) {
            // Tooltip row — always takes up space so bars don't shift
            ZStack {
                if let h = hoveredHour, hourlyUsage[h] > 0 {
                    Text("\(String(format: "%02d", h)):00  \(fmt(hourlyUsage[h]))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .frame(height: 20)
            .animation(.easeInOut(duration: 0.12), value: hoveredHour)

            // Bars
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<hourlyUsage.count, id: \.self) { h in
                    let v = hourlyUsage[h]
                    let pct = Double(v) / Double(maxVal)
                    let past = h <= Calendar.current.component(.hour, from: Date())
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hoveredHour == h && v > 0
                              ? Color.white.opacity(0.9)
                              : past && v > 0
                                  ? Color.white.opacity(0.55)
                                  : Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(y: max(pct, 0.04), anchor: .bottom)
                        .onHover { hoveredHour = $0 ? h : nil }
                }
            }
        }
    }
}

// MARK: - Weekly Bar Chart

struct WeeklyBarChart: View {
    let records: [DayRecord]

    private func dayLabel(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "" }
        let df = DateFormatter(); df.dateFormat = "d"
        return df.string(from: d)
    }

    var body: some View {
        let maxCost = max(records.map(\.cost).max() ?? 0, 0.001)
        let allZero = records.allSatisfy { $0.cost == 0 }

        if allZero || records.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.15))
                Text(L10n.s("Нет данных за этот период", "No data for this period"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: records.count > 15 ? 2 : 5) {
                ForEach(records) { record in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(record.cost > 0 ? Color.white.opacity(0.55) : Color.white.opacity(0.08))
                            .frame(maxHeight: .infinity)
                            .scaleEffect(y: max(record.cost / maxCost, record.cost > 0 ? 0.04 : 0.02), anchor: .bottom)
                        if records.count <= 14 {
                            Text(dayLabel(record.date))
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
