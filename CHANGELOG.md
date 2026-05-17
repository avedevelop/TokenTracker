# Changelog

All notable changes to TokenTracker are documented here.

---

## v1.1.0 — May 2026

### New features
- **Per-project breakdown** — dashboard shows top-5 projects by token usage and cost today
- **Check for updates** — button in About tab + automatic banner on launch if a new version is available on GitHub

### Fixed
- Notification reset logic: alert now re-fires correctly after utilization drops below threshold and rises again
- Hex parsing in LimitsPoller: odd-length strings no longer produce incorrect bytes
- UpdateChecker: removed force-unwrap on API URL

### Improved
- Widget data server now rejects non-localhost connections

---

## v1.0.2 — May 2026

### Security
- Session token no longer stored as plaintext in `~/Library/Preferences` — Keychain only

---

## v1.0.1 — May 2026

### Fixed
- Crash on window close (X button) on macOS 26 Tahoe — window now hides instead of deallocating
- Sync button spinner replaced with native `ProgressView`
- Timer, FSWatcher and local server now stop cleanly on quit

---

## v1.0.0 — May 2026

Initial public release.

### Features
- Dashboard with 5-hour and weekly Claude rate limits
- Real-time token/cost/session tracking from Claude Code files
- Hourly activity chart with hover tooltips
- 7/30/90-day history with CSV export
- WidgetKit widgets: small, medium, large
- Menu bar icon showing current 5-hour utilization %
- Notifications for limit thresholds and daily budget alerts
- Login flow with session token + org ID
- Localization: Russian, Ukrainian, Belarusian, English
- macOS Keychain storage for session credentials
- FSEvents file watcher for instant Claude Code updates
