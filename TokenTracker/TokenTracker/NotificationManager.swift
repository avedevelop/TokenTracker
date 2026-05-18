import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Silently ignore — user may deny
        }
    }

    // MARK: - Limit Checks

    func checkLimits(_ limits: UsageData.Limits) {
        guard UserDefaults.standard.object(forKey: "notif.enabled") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "notif.enabled")
        else { return }

        let threshold = UserDefaults.standard.object(forKey: "notif.threshold") == nil
            ? 0.8
            : UserDefaults.standard.double(forKey: "notif.threshold")

        let fivePct = limits.fiveHourPercent        // 0.0 – 1.0
        let weekPct = limits.weeklyPercent           // 0.0 – 1.0

        checkAndFire(
            id: "5h-limit",
            lastKey: "notif.last5h",
            currentValue: fivePct,
            threshold: threshold,
            body: L10n.fiveHourLimitBody(percent: Int(fivePct * 100))
        )

        checkAndFire(
            id: "weekly-limit",
            lastKey: "notif.lastWeekly",
            currentValue: weekPct,
            threshold: threshold,
            body: L10n.weeklyLimitBody(percent: Int(weekPct * 100))
        )
    }

    // MARK: - Budget Check

    func checkBudget(_ cost: Double) {
        let dailyBudget = UserDefaults.standard.double(forKey: "budget.daily")
        guard dailyBudget > 0, cost >= dailyBudget else { return }

        let todayStr = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        let alreadyNotified = UserDefaults.standard.string(forKey: "budget.notified.today") == todayStr
        guard !alreadyNotified else { return }

        UserDefaults.standard.set(todayStr, forKey: "budget.notified.today")

        let content = UNMutableNotificationContent()
        content.title = L10n.s("Бюджет исчерпан", "Daily budget reached")
        content.body = String(format: "$%.2f / $%.2f", cost, dailyBudget)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "budget-limit",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func checkMonthlyBudget(_ monthlySpend: Double) {
        let monthlyBudget = UserDefaults.standard.double(forKey: "budget.monthly")
        guard monthlyBudget > 0, monthlySpend >= monthlyBudget else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthStr = formatter.string(from: Date())
        let alreadyNotified = UserDefaults.standard.string(forKey: "budget.notified.month") == monthStr
        guard !alreadyNotified else { return }

        UserDefaults.standard.set(monthStr, forKey: "budget.notified.month")

        let content = UNMutableNotificationContent()
        content.title = L10n.s("Месячный бюджет исчерпан", "Monthly budget reached")
        content.body = String(format: "$%.2f / $%.2f", monthlySpend, monthlyBudget)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "monthly-budget-limit",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    // MARK: - Private

    private func checkAndFire(
        id: String,
        lastKey: String,
        currentValue: Double,
        threshold: Double,
        body: String
    ) {
        guard currentValue >= threshold else {
            // Value dropped below threshold — reset so we fire again on next crossing
            if UserDefaults.standard.double(forKey: lastKey) > 0 {
                UserDefaults.standard.set(0.0, forKey: lastKey)
            }
            return
        }

        let lastNotified = UserDefaults.standard.double(forKey: lastKey)
        // Only fire if we have crossed a new 5% band since last notification
        let band = (currentValue * 20).rounded(.down) / 20   // round down to nearest 5%
        let lastBand = (lastNotified * 20).rounded(.down) / 20
        guard band > lastBand else { return }

        UserDefaults.standard.set(currentValue, forKey: lastKey)

        let content = UNMutableNotificationContent()
        content.title = "TokenTracker"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil   // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { _ in
            // Ignore delivery errors
        }
    }
}
