# Changelog

All notable changes to TokenTracker are documented here.

---

## v1.0.1 — May 2026

### Fixed
- Crash on window close (X button) on macOS 26 Tahoe — window now hides instead of deallocating, eliminating race with `_NSWindowTransformAnimation`
- Sync button spinner replaced with native `ProgressView` — previous rotation animation caused visual glitches
- App cleanup on quit: timer, FSWatcher and local server now stop cleanly via `applicationWillTerminate`

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
- Daily budget with preset and custom amounts
- Login flow with session token + org ID fallback
- Localization: Russian, Ukrainian, Belarusian, English
- macOS Keychain storage for session credentials
- FSEvents file watcher for instant Claude Code updates
