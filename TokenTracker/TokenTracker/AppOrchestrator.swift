import Foundation
import WidgetKit
import Combine

@MainActor
final class AppOrchestrator: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var tokenExpired: Bool = false
    @Published var fiveHourUtilization: Double = 0
    @Published var usage: UsageData = SharedStore.read()

    private var fsWatcher: FSWatcher?
    private var limitsTimer: Timer?
    private var server = LocalServer()

    func start() {
        server.start()
        isLoggedIn = KeychainStore.load() != nil
        startFSWatcher()
        refreshTokenUsage()
        Task { await NotificationManager.shared.requestPermission() }
        if isLoggedIn {
            startLimitsPolling()
            pollLimitsNow()
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
        try? KeychainStore.save(token)
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
        // Reload widgets after limits arrive (give network request time to complete)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func logout() {
        KeychainStore.delete()
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
    }

    private func startLimitsPolling() {
        limitsTimer?.invalidate()
        limitsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollLimitsNow() }
        }
    }

    private func pollLimitsNow() {
        guard let token = KeychainStore.load() else { return }
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
