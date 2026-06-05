# Changelog

All notable changes to TokenTracker are documented here.

---

## v1.4.8 — June 2026

### Fixed
- Fixed crash on launch caused by Sparkle.framework having a mismatched code signature. All nested frameworks and XPC services are now re-signed with a consistent ad-hoc identity after build, which macOS 26 Tahoe requires.
- Fixed WebView login window not appearing: the `WebAuthWindowController` was being deallocated immediately after creation. Added a static reference to keep it alive until login completes or the window is closed.

---

## v1.4.7 — June 2026

### Fixed
- Fixed post-login redirect back to login screen. After WebView login the app now forwards all Cloudflare cookies (including `cf_clearance`) to background URLSession polling requests, so Cloudflare stops blocking them.

---

## v1.4.6 — June 2026

### Changed
- Login now uses an embedded WebView instead of manual cookie copying. Clicking "Connect" opens claude.ai inside the app — Cloudflare challenges are solved automatically by WebKit and the session token is extracted without any manual steps.
- Manual token entry is still available as a fallback via "Enter token manually".

---

## v1.4.5 — June 2026

### Fixed
- Fixed login failure caused by Cloudflare blocking requests without a browser User-Agent. All API calls now send a Safari/macOS User-Agent so claude.ai's Cloudflare layer lets them through.

---

## v1.4.4 — June 2026

### Fixed
- Fixed stale local state after app reinstall. When profiles exist in UserDefaults but Keychain has no matching tokens (typical after reinstall), the app now purges that stale metadata automatically so login starts from a clean state instead of using an old cached Org ID.

---

## v1.4.3 — June 2026

### Fixed
- Further hardened session validation: when the usage endpoint returns 401/403, the app now independently verifies the session via `/api/organizations` before showing an error. If the session is valid, the app logs in without limit data instead of falsely reporting the token as expired.

---

## v1.4.2 — June 2026

### Fixed
- Fixed "Token is invalid or expired" error for accounts where the usage endpoint is unavailable (Free plan or Anthropic API change). The session is now verified independently; if the usage endpoint rejects the request but the session itself is valid, the app logs in without limit data instead of showing a false error.

---

## v1.4.1 — June 2026

### Fixed
- Fixed an account lockout that could happen while adding a new Claude account with a manual Org ID.
- New accounts now become active only after the session token and Org ID flow succeeds.
- Added a Cancel action to the add-account login sheet.
- Signing out of one account now keeps the app logged in when another saved account is still available.
- The app now repairs a missing or stale active account selection on launch.

---

## v1.4.0 — June 2026

### New features
- **Smart dashboard** — new status, limit intelligence, and project insight cards summarize burn rate, reset timing, daily cost, weekly trends, and heaviest projects.
- **Insights tab** — History has evolved into a richer analytics view with 7 / 30 / 90-day periods, metric switching, comparison deltas, charts, daily records, and CSV export.
- **Menu bar mini dashboard** — the status item now opens a compact popover with limits, today totals, project highlights, activity, and quick actions for Dashboard, Insights, Settings, Sync, and Quit.
- **Widget health** — Settings now shows widget data freshness, selected widget account, and macOS troubleshooting guidance when WidgetKit does not show TokenTracker until restart or log out/in.

### Improved
- Dashboard limits no longer show the extra credits row; credits remain out of the main limit stack unless the app has meaningful usage data for them.
- Period and project analytics now aggregate duplicate daily records and use calendar-aligned comparison windows for sparse history.
- Widget account selection is preserved when accounts are refreshed and cleared only when the selected account is removed.
- App and widget continue to build with local ad-hoc signing, with no Developer ID requirement.

## v1.3.9 — May 2026

### Changed
- Updated GitHub owner links in the app, Sparkle feed, release downloads, FAQ, Terms, and repository actions after the account rename.

## v1.3.8 — May 2026

### Fixed
- **Local Server crash** — resolved a critical issue where the local tracking server failed to start due to invalid socket configurations on macOS. Connection-level filtering continues to enforce local loopback access exclusively.

## v1.3.7 — May 2026

### Fixed
- **Widget stuck/frozen** — added App Transport Security exception `NSAllowsLocalNetworking` for `127.0.0.1` to the Widget Extension, allowing it to correctly connect to the local tracking server and display real-time data instead of remaining frozen.

## v1.3.6 — May 2026

### Security Fixes
- **Strict loopback binding** — restricted the widget local server (`LocalServer`) to only listen on local loopback `127.0.0.1` interface rather than all network interfaces.
- **Removed shell executions** — eliminated vulnerable shell wrappers inside the auto-update checker and keychain CLI credentials reader, replacing them with safe direct process launches using argument arrays.
- **Deleted cookie decryption logic** — removed unused/obsolete fallback Chrome cookie database decryption routine, eliminating file reads to Application Support and security-sensitive keychain accesses.

## v1.3.5 — May 2026

### Fixed
- **Limit reset timing in app** — remaining time until limit reset now updates instantly when the window appears or becomes active (previously stayed stale for up to 60 seconds).

---

## v1.3.4 — May 2026

### Improved
- **Claude Code reader performance** — optimized startup and log scans by skipping files that have not been modified since the start of today.

### Fixed
- Progress KVO observation leak in UpdateChecker — now properly retained as a class property to prevent memory leaks during update checks.

---

## v1.3.3 — May 2026

### New features
- **Light theme** — three-way theme picker in Settings → Behaviour: System / Light / Dark (previously dark-only)

### Improved
- All UI elements — buttons, inputs, progress bars, charts, toggles — fully adapted for light and system themes; no more white-on-white invisible content
- Activity and history toggles now blue (accent color) when active
- Widget account selected row shows purple highlight visible in both themes
- About-section button borders more visible in light mode

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
- **Homebrew tap** — install and update via `brew tap avedevelop/tap && brew install --cask tokentracker`
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
