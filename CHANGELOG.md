# Changelog

All notable changes to TokenTracker are documented here.

---

## v1.3.2 — May 2026

### Improved
- Update button now shows **"Установка…"** state while the new app is being copied and relaunched (previously showed nothing after download)
- After a successful auto-update, the first launch shows a green **"Обновление установлено v1.3.1 → v1.3.2"** banner in Settings → About

---

## v1.3.1 — May 2026

### Fixed
- Update installation: "Download" button now mounts the DMG silently, copies the new app directly over the existing installation, removes quarantine, then quits and relaunches automatically — no manual dragging required

---

## v1.3.0 — May 2026

### New features
- **Sparkle auto-updates** — native update dialog via `SPUStandardUpdaterController`; app checks for updates on launch and prompts with release notes. Updates verified with EdDSA signature (no Apple Developer account required).
- **Check for Updates** menu item added to the app menu (Cmd+U)
- **Homebrew tap** — install and update via `brew tap bvsmma/tap && brew install --cask tokentracker`
- **Auto-download in update banner** — "Download" button in the About section fetches the DMG directly to `~/Downloads` with a progress bar and opens it automatically

---

## v1.2.1 — May 2026

### Fixed
- Widget stopped syncing after v1.2.0 — caused by switching to `AppIntentConfiguration` (broken on macOS Sequoia/26); reverted to `StaticConfiguration` which restores live updates. Widget account selection via Settings → Widget is unaffected.

---

## v1.2.0 — May 2026

### New features
- **Multiple accounts** — add up to 5 Claude.ai accounts and switch between them; each account has its own Keychain token and Org ID stored separately
- **Widget account selection** — choose which account the widget displays in Settings → Widget (works around macOS Sequoia WidgetKit configuration bug)
- **Free account support** — accounts without a Pro subscription can be added; limits section shows a clear message when Org ID is missing or usage endpoint is unavailable
- **Per-account limits polling** — all inactive accounts are polled every minute so the widget always has fresh data for any account
- **Single-instance enforcement** — launching a second copy of the app brings the existing window to front instead of opening a duplicate

### Improved
- Account cards redesigned: unified card layout with avatar, status, Org ID row, and action buttons — no more disconnected sub-boxes
- Switch account button changed to icon (⇄) to avoid text wrapping; tooltip on hover
- Switching accounts immediately clears stale limits and fetches fresh data for the new account
- Org ID is now stored per-account profile (not global UserDefaults), preventing cross-account contamination
- "Add Account" modal opens directly to the token paste step, skipping the intro
- Limits section shows contextual messages: "Loading…" when logged in but data pending, "Set Org ID" when org ID is missing
- Budget section renamed from "Daily budget" to "Budget" (covers both daily and monthly limits)
- Adding a second account no longer overwrites the existing active profile

### Fixed
- Org ID from one account could leak into another account's profile via Desktop cookie fallback — fixed by using API-first lookup with no Desktop fallback
- Free account login showed "Network error" instead of succeeding — `unexpectedResponse` from the usage endpoint is now treated as a successful login without limits
- Switching accounts did not update UserDefaults orgId, causing LimitsPoller to use the wrong org — fixed

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
