import Foundation
import WidgetKit
import Combine

@MainActor
final class AppOrchestrator: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var tokenExpired: Bool = false
    @Published var fiveHourUtilization: Double = 0
    @Published var usage: UsageData = SharedStore.read()
    @Published var updateAvailable: String? = nil
    @Published var updateReleaseURL: URL? = nil
    @Published var justUpdatedFrom: String? = nil   // set on first launch after auto-update

    private var fsWatcher: FSWatcher?
    private var limitsTimer: Timer?
    private var server = LocalServer()

    func start() {
        server.start()
        checkIfJustUpdated()
        isLoggedIn = AccountStore.shared.activeToken() != nil
        // Ensure UserDefaults orgId matches the active profile's orgId on every launch
        if let orgId = AccountStore.shared.activeProfile?.orgId, !orgId.isEmpty {
            UserDefaults.standard.set(orgId, forKey: "com.tokentracker.orgId")
        }
        startFSWatcher()
        refreshTokenUsage()
        Task { await checkForUpdates() }
        Task { await NotificationManager.shared.requestPermission() }
        if isLoggedIn {
            startLimitsPolling()
            pollLimitsNow()
            pollInactiveAccountsLimits()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } else {
            Task { await tryAutoLoginFromClaudeCode() }
        }
    }

    /// Auto-login if Claude Code OAuth credentials are present in Keychain.
    func tryAutoLoginFromClaudeCode() async {
        guard !isLoggedIn,
              let token = LimitsPoller().readClaudeCodeOAuthToken() else { return }
        // Store OAuth token as the session credential
        AccountStore.shared.ensureProfile(token: token)
        isLoggedIn = true
        startLimitsPolling()
        pollLimitsNow()
    }

    func updateProjectsFolder() {
        guard ClaudeCodeReader.requestAccess() else { return }
        fsWatcher = nil
        startFSWatcher()
        refreshTokenUsage()
    }

    func forceRefresh() {
        refreshTokenUsage()
        if isLoggedIn { pollLimitsNow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func onLoginSuccess() {
        isLoggedIn = true
        tokenExpired = false
        startLimitsPolling()
        pollLimitsNow()
        Task { await refreshActiveProfileInfo() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func refreshActiveProfileInfo() async {
        guard let token = AccountStore.shared.activeToken(),
              let id = AccountStore.shared.activeId else { return }
        let poller = LimitsPoller()
        let info: LimitsPoller.UserInfo
        if token.hasPrefix("sk-ant-oat") {
            info = await poller.fetchUserInfoWithOAuth(token)
        } else {
            info = await poller.fetchUserInfo(sessionKey: token)
        }
        AccountStore.shared.updateProfileInfo(id: id, email: info.email, fullName: info.fullName)
    }

    func logout() {
        if let profile = AccountStore.shared.activeProfile {
            AccountStore.shared.remove(profile)
        }
        isLoggedIn = false
        limitsTimer?.invalidate()
        limitsTimer = nil
        var stored = SharedStore.read()
        stored.limits = nil
        stored.limitsUpdatedAt = nil
        try? SharedStore.write(stored)
        usage = stored
        WidgetCenter.shared.reloadAllTimelines()
    }

    func switchAccount(_ profile: AccountProfile) {
        AccountStore.shared.setActive(profile.id)
        limitsTimer?.invalidate()
        limitsTimer = nil
        // Sync this profile's orgId to UserDefaults so LimitsPoller picks it up immediately
        if !profile.orgId.isEmpty {
            UserDefaults.standard.set(profile.orgId, forKey: "com.tokentracker.orgId")
        } else {
            UserDefaults.standard.removeObject(forKey: "com.tokentracker.orgId")
        }
        // Clear stale limits so UI doesn't show previous account's data
        var stored = SharedStore.read()
        stored.limits = nil
        stored.limitsUpdatedAt = nil
        try? SharedStore.write(stored)
        usage = stored
        isLoggedIn = AccountStore.shared.activeToken() != nil
        if isLoggedIn {
            startLimitsPolling()
            pollLimitsNow()
            Task { await refreshActiveProfileInfo() }
        }
    }

    func checkForUpdates() async {
        let checker = UpdateChecker.shared
        if await checker.check() {
            updateAvailable = checker.availableVersion
            updateReleaseURL = checker.releaseURL
        }
    }

    private func checkIfJustUpdated() {
        let key = "com.tokentracker.previousVersion"
        guard let prev = UserDefaults.standard.string(forKey: key), !prev.isEmpty else { return }
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        if prev != current {
            justUpdatedFrom = prev
        }
        UserDefaults.standard.removeObject(forKey: key)
    }

    func dismissUpdateBanner() { justUpdatedFrom = nil }

    func stop() {
        limitsTimer?.invalidate()
        limitsTimer = nil
        fsWatcher?.stop()
        fsWatcher = nil
        server.stop()
    }

    // MARK: - Private

    private func startFSWatcher() {
        let watcher = FSWatcher { [weak self] in
            Task { @MainActor [weak self] in self?.refreshTokenUsage() }
        }
        watcher.start(watching: ClaudeCodeReader.defaultProjectsDir)
        fsWatcher = watcher
    }

    private func refreshTokenUsage() {
        let newData = ClaudeCodeReader.readTodayUsage()
        try? SharedStore.updateTokens(from: newData)
        usage = SharedStore.read()
        HistoryStore.snapshotToday(from: usage, limits: usage.limits)
        NotificationManager.shared.checkBudget(usage.costToday)

        // Monthly budget check
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        let allRecords = HistoryStore.shared.load()
        let monthlySpend = allRecords
            .filter { $0.date.hasPrefix(currentMonth) }
            .map(\.cost)
            .reduce(0, +)
        NotificationManager.shared.checkMonthlyBudget(monthlySpend)
    }

    private func startLimitsPolling() {
        limitsTimer?.invalidate()
        limitsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollLimitsNow()
                self?.pollInactiveAccountsLimits()
            }
        }
    }

    /// Polls limits for all non-active accounts and writes them to per-account snapshots
    /// so the widget can display data for any specific account, not just the active one.
    private func pollInactiveAccountsLimits() {
        let activeId = AccountStore.shared.activeId
        let inactive = AccountStore.shared.profiles.filter { $0.id != activeId && !$0.orgId.isEmpty }
        for profile in inactive {
            guard let token = AccountStore.shared.token(for: profile.id) else { continue }
            let profileId = profile.id
            let orgId = profile.orgId
            Task {
                do {
                    let poller = LimitsPoller()
                    let limits: UsageData.Limits
                    if token.hasPrefix("sk-ant-oat") {
                        // OAuth path doesn't support an arbitrary orgId override; skip for now
                        return
                    } else {
                        limits = try await poller.fetchLimits(sessionKey: token, orgId: orgId)
                    }
                    SharedStore.updateLimits(limits, forAccount: profileId)
                    await MainActor.run {
                        AccountStore.shared.markTokenStatus(id: profileId, valid: true)
                    }
                } catch LimitsPoller.PollerError.unauthorized {
                    await MainActor.run {
                        AccountStore.shared.markTokenStatus(id: profileId, valid: false)
                    }
                } catch {
                    // Network failure — keep last known snapshot for this account
                }
            }
        }
    }

    private func pollLimitsNow() {
        guard let token = AccountStore.shared.activeToken() else { return }
        Task {
            do {
                let poller = LimitsPoller()
                let limits = token.hasPrefix("sk-ant-oat")
                    ? try await poller.fetchLimitsWithOAuthToken(token)
                    : try await poller.fetchLimits(sessionKey: token)
                try SharedStore.updateLimits(limits)
                NotificationManager.shared.checkLimits(limits)
                await MainActor.run {
                    self.fiveHourUtilization = limits.fiveHourUtilization
                    self.usage = SharedStore.read()
                    HistoryStore.snapshotToday(from: self.usage, limits: self.usage.limits)
                }
            } catch LimitsPoller.PollerError.unauthorized {
                await MainActor.run {
                    self.isLoggedIn = false
                    self.tokenExpired = true
                }
            } catch {
                // Network failure — keep last known limits
            }
        }
    }
}
