# TokenTracker

> Native macOS app for tracking Claude AI usage, costs, and rate limits in real time.

![macOS](https://img.shields.io/badge/macOS_26+-000000?style=flat&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift_6-F05138?style=flat&logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey?style=flat)

---

<p align="center">
  <img src="docs/screenshots/dashboard.png" width="240" alt="Dashboard" />
  &nbsp;
  <img src="docs/screenshots/history.png" width="240" alt="History" />
</p>

<p align="center">
  <img src="docs/screenshots/widget_large.png" width="240" alt="Large widget" />
  &nbsp;
  <img src="docs/screenshots/widget_medium.png" width="240" alt="Medium widget" />
  &nbsp;
  <img src="docs/screenshots/widget_small.png" width="120" alt="Small widget" />
</p>

---

## What it does

TokenTracker sits in your menu bar and tracks:

- **Rate limits** — 5-hour and weekly Claude limits, updated every 60 seconds
- **Daily usage** — tokens consumed, cost in USD, active sessions
- **History** — 7/30/90-day cost breakdown with CSV export
- **Widgets** — three WidgetKit sizes (small, medium, large) for your desktop

No cloud, no telemetry. Everything runs locally.

---

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26+ (to build from source)
- A Claude.ai account (Pro or Max recommended for rate limit data)

---

## Installation

### Build from source

```bash
git clone https://github.com/bvsmma/TokenTracker.git
cd TokenTracker/TokenTracker
open TokenTracker.xcodeproj
```

1. Select the **TokenTracker** scheme
2. Set your Development Team in Signing & Capabilities
3. Build & Run (`Cmd+R`)

### Add widgets

Right-click your desktop → **Edit Widgets** → search **TokenTracker** → choose a size.

---

## Setup

### Claude Code usage (automatic)

TokenTracker reads `~/.claude/projects/**/*.jsonl` directly — no configuration needed. Usage data appears immediately after launch.

### Rate limits (requires login)

To see your 5-hour and weekly limits, log in once:

1. Open **Account** tab → the app will prompt you if not logged in
2. Go to [claude.ai](https://claude.ai) in your browser
3. Open DevTools (`Cmd+Option+I`) → **Application** → **Cookies** → **claude.ai**
4. Copy the value of **`sessionKey`**
5. Paste it into TokenTracker

Your session key is stored encrypted in macOS Keychain.

If the Org ID lookup fails, you'll be prompted to enter it manually:  
DevTools → **Application** → **Cookies** → **claude.ai** → find **`lastActiveOrg`**.

---

## Privacy

- No analytics, no tracking, no external servers
- The only outbound requests go to `api2.claude.ai` to fetch your own rate limit data
- Session token stored in macOS Keychain (encrypted)
- Org ID stored in `UserDefaults` (local)
- All usage data read from local disk only

---

## Project structure

```
TokenTracker/
├── TokenTracker/          # Main app target
│   ├── Data/              # ClaudeCodeReader, LimitsPoller, SharedStore, etc.
│   ├── Models/            # UsageData
│   ├── Views/             # SettingsView, LoginView, OnboardingView
│   ├── AppOrchestrator.swift
│   ├── NotificationManager.swift
│   └── L10n.swift         # Russian / English localization
├── TokenTrackerWidget/    # WidgetKit extension (small, medium, large)
└── TokenTrackerTests/     # Unit tests
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT — see [LICENSE](LICENSE).
