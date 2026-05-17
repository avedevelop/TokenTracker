# TokenTracker

Native macOS widget to monitor Claude token usage, costs, and rate limits in real time.

![macOS](https://img.shields.io/badge/macOS-Tahoe_26+-000000?style=flat&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat&logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat)

## Features

- **Real-time updates** — token usage refreshes instantly as you work in Claude Code (FSEvents)
- **Live limits** — 5-hour limit, weekly limit, Sonnet & Opus (Max) updated every minute
- **Three widget sizes** — small, medium, large — all support macOS Notification Center
- **Liquid Glass design** — native macOS Tahoe 26 `.glassEffect()` material
- **No API key needed** — reads Claude Code usage directly from local files

## Requirements

- macOS Tahoe 26 (macOS 26) or later
- Claude Code CLI and/or Claude.ai account

## Installation

Download the latest release from [Releases](../../releases) and drag TokenTracker.app to your Applications folder.

To add the widget: right-click your desktop → Edit Widgets → search "TokenTracker".

## How It Works

**Claude Code usage** is read directly from `~/.claude/projects/**/*.jsonl` — no authentication required. The app watches for file changes via FSEvents and updates the widget instantly.

**Rate limits** (5-hour, weekly, Sonnet, Opus) are fetched from Claude.ai every minute using your session. You log in once via an in-app browser — credentials are stored securely in macOS Keychain.

## Privacy

All data stays on your Mac. No telemetry, no external servers. The only network requests are to `claude.ai` to fetch your rate limits.

## Development

```bash
git clone https://github.com/bvsmma/TokenTracker.git
cd TokenTracker
open TokenTracker.xcodeproj
```

Requires Xcode 26+.

## License

MIT — see [LICENSE](LICENSE).
