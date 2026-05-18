# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**TokenTracker** — native macOS app (Swift/SwiftUI) that tracks Claude AI token usage, costs, and rate limits in real time. No cloud dependency; everything runs locally.

- GitHub: `github.com/bvsmma/TokenTracker`
- Current version: **1.2.1**
- Requires macOS 26 (Tahoe)+, no Apple Developer account (ad-hoc signed)
- Distribution: Homebrew tap (`bvsmma/homebrew-tap`) + GitHub Releases DMG + Sparkle auto-updates

## Build & run commands

All commands run from `TokenTracker/` (the Xcode project root):

```bash
# Debug build
xcodebuild -scheme TokenTracker -configuration Debug build

# Release build
xcodebuild -scheme TokenTracker -configuration Release build

# Run tests
xcodebuild -scheme TokenTracker test

# Run a single test class
xcodebuild -scheme TokenTracker test -only-testing:TokenTrackerTests/ClaudeCodeReaderTests

# Deploy debug build to ~/Applications (standard workflow — avoids App Translocation)
kill -9 $(pgrep -x TokenTracker) 2>/dev/null
pkill -f TokenTrackerWidgetExtension 2>/dev/null
rm -rf ~/Applications/TokenTracker.app
cp -R ~/Library/Developer/Xcode/DerivedData/TokenTracker-*/Build/Products/Debug/TokenTracker.app ~/Applications/
xattr -dr com.apple.quarantine ~/Applications/TokenTracker.app
lsregister=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
$lsregister -u ~/Library/Developer/Xcode/DerivedData/TokenTracker-*/Build/Products/Debug/TokenTracker.app 2>/dev/null
$lsregister -f ~/Applications/TokenTracker.app
open ~/Applications/TokenTracker.app
```

> **Why deploy to ~/Applications?** macOS Gatekeeper translocates unsigned apps run directly from DerivedData to a random temp path, which breaks widget registration and LaunchServices. Always copy to `~/Applications` and strip quarantine.

## Architecture

### Data flow

```
~/.claude/projects/**/*.jsonl  ──► ClaudeCodeReader (parses JSONL, computes tokens/cost/sessions)
                                        │
                                        ▼
FSWatcher (FSEvents)  ─────────► AppOrchestrator (@MainActor ObservableObject)
                                        │               │
                               SharedStore.updateTokens │  SharedStore.updateLimits
                               (usage.json + per-account│  (usage-{uuid}.json)
                                accounts.json manifest) │
                                        │               │
                                        ▼               ▼
                                 LimitsPoller ──► claude.ai API
                                 (polls every 60s; all accounts in parallel)
                                        │
                                        ▼
                              LocalServer (port 51234)  ──► WidgetKit extension
                              GET /usage → active or widgetAccountId account
                              GET /usage?account=UUID → specific account
                              GET /accounts → AccountsManifest JSON
```

### Key files

| File | Role |
|---|---|
| `AppOrchestrator.swift` | Central `@MainActor` coordinator. Owns FSWatcher, polling timer, LocalServer, login state. Entry point: `start()`. |
| `Models/UsageData.swift` | Single shared model used by app AND widget extension. Codable. |
| `Data/AccountStore.swift` | Multi-account management. Stores all tokens in ONE Keychain item (`allTokens` key as JSON dict) to avoid multiple Keychain prompts. Syncs `accounts.json` manifest to SharedStore on every profile change. Max 5 accounts. |
| `Data/SharedStore.swift` | File-based persistence at `~/Library/Application Support/com.tokentracker/`. Writes `usage.json` (active account), `usage-{UUID}.json` (per-account), `accounts.json` (manifest with `activeId` + `widgetAccountId`). |
| `Data/LimitsPoller.swift` | Fetches rate limits from `claude.ai/api/organizations/{orgId}/usage`. Supports session cookie auth and OAuth Bearer. Reads `AccountStore.shared.activeOrgId` (not UserDefaults) to avoid cross-account contamination. |
| `Data/LocalServer.swift` | TCP server on localhost:51234. Serves JSON to widget. Only accepts 127.0.0.1/::1. |
| `Data/ClaudeCodeReader.swift` | Parses `~/.claude/projects/**/*.jsonl`, extracts `assistant` entries with `usage` fields. Pricing: Sonnet 4.6 rates hardcoded. Folder names decoded from dash-separated paths. |
| `Data/HistoryStore.swift` | Persists up to 90 days of `DayRecord` snapshots at `history.json`. |
| `Data/UpdateChecker.swift` | GitHub Releases API check + auto-downloads DMG to `~/Downloads` and opens it. Sparkle (`SPUStandardUpdaterController`) also runs in parallel for native update UI. |
| `Views/SettingsView.swift` | Single large view file with tab-based layout (Dashboard, History, Account, Settings). All UI lives here except Login and Onboarding. |
| `TokenTrackerApp.swift` | `AppDelegate` sets up NSWindow (340px fixed width), status bar item, `SPUStandardUpdaterController` (Sparkle), and single-instance enforcement. |

### Widget extension (`TokenTrackerWidget/`)

- Uses `StaticConfiguration` with `TimelineProvider` — **NOT** `AppIntentConfiguration` (broken on macOS Sequoia/26, Apple bug FB15592256)
- Fetches all data via HTTP from `localhost:51234` (requires main app to be running)
- Widget account selection is done in the main app: **Settings → Widget** writes `widgetAccountId` to `accounts.json` manifest; LocalServer reads it on every `/usage` request
- `UsageData.swift` and `SharedStore.swift` are shared between both targets via the project's `Models` and `Data` groups

### Auth & credentials

- **Session tokens**: stored in Keychain service `com.tokentracker.session`, account `allTokens`, as a JSON dict `{UUID: token}` — one Keychain prompt for all accounts
- **Org ID**: stored per `AccountProfile` in UserDefaults (profiles array). LimitsPoller reads from `AccountStore.shared.activeOrgId`. UserDefaults key `com.tokentracker.orgId` is kept in sync as fallback.
- **Claude Code OAuth**: read via `security find-generic-password -s 'Claude Code-credentials'` — auto-login if present
- **Org ID lookup**: API-first (`/api/organizations` with session cookie), no Desktop cookie fallback (would contaminate cross-account)

### Localization

`L10n.swift` — custom inline localization, no `.strings` files. Russian for `ru`/`uk`/`be` locales, English otherwise. Usage: `L10n.s("Русский текст", "English text")` for inline, or `L10n.staticProperty` for shared strings.

## Release workflow

```bash
# 1. Bump version in project.pbxproj
sed -i '' 's/MARKETING_VERSION = X.X.X;/MARKETING_VERSION = Y.Y.Y;/g' TokenTracker.xcodeproj/project.pbxproj

# 2. Release build
xcodebuild -scheme TokenTracker -configuration Release build

# 3. Create DMG
STAGING=/tmp/tt-dmg && rm -rf $STAGING && mkdir $STAGING
cp -R ~/Library/Developer/Xcode/DerivedData/TokenTracker-*/Build/Products/Release/TokenTracker.app $STAGING/
ln -s /Applications $STAGING/Applications
hdiutil create -volname "TokenTracker Y.Y.Y" -srcfolder $STAGING -ov -format UDRW -fs HFS+ /tmp/tt-rw.dmg
# ... mount, set layout, unmount, convert to UDZO ...
hdiutil convert /tmp/tt-rw.dmg -format UDZO -imagekey zlib-level=9 -o /tmp/TokenTracker-Y.Y.Y.dmg

# 4. Sign for Sparkle (EdDSA key in Keychain)
/tmp/SparkleFramework/bin/sign_update /tmp/TokenTracker-Y.Y.Y.dmg
# → outputs sparkle:edSignature and length; add new <item> to appcast.xml

# 5. Commit, tag, push
git add -A && git commit -m "..." && git tag vY.Y.Y && git push origin main vY.Y.Y

# 6. GitHub release with DMG
gh release create vY.Y.Y /tmp/TokenTracker-Y.Y.Y.dmg --title "vY.Y.Y — ..." --notes "..."

# 7. Update Homebrew tap (separate repo: github.com/bvsmma/homebrew-tap)
# Edit Casks/tokentracker.rb: bump version + sha256 (shasum -a 256 /tmp/TokenTracker-Y.Y.Y.dmg)
# Commit and push to homebrew-tap repo
```

## Important constraints

- **Fixed window width: 340px.** UI is designed for exactly this width. Don't use flexible layouts that exceed it.
- **Dark-only UI.** The app always uses dark color scheme. No system theme support (caused white-on-white bug, removed).
- **No App Sandbox, no Hardened Runtime signing.** App is ad-hoc signed. Don't add entitlements that require a Developer account.
- **Widget uses HTTP, not shared container.** Widget reads from `localhost:51234`. If the main app isn't running, the widget shows `.preview` data. This is by design.
- **Sparkle public key** in `project.pbxproj` (`INFOPLIST_KEY_SUPublicEDKey`): `6XX7hOUdXUl0Q36AZRGrE2NTwCByev1eBN0W80TwVJI=`. Private key is in the developer's macOS Keychain (not in repo).
- **Claude Code pricing** is hardcoded in `ClaudeCodeReader.swift` (Sonnet 4.6 rates). Update when pricing changes.
- **AppIntentConfiguration for widgets is broken on macOS Sequoia/26** (Apple FB15592256). Do not attempt to use it; widget configuration is done via Settings → Widget in the main app instead.
