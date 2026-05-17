# Contributing to TokenTracker

Thanks for your interest. Here's everything you need to get started.

---

## Building locally

**Requirements:** Xcode 26+, macOS 26+

```bash
git clone https://github.com/bvsmma/TokenTracker.git
cd TokenTracker/TokenTracker
open TokenTracker.xcodeproj
```

In Xcode:
1. Select the **TokenTracker** scheme
2. Go to **Signing & Capabilities** → set your Apple ID / Development Team
3. Hit `Cmd+R`

The widget extension (`TokenTrackerWidgetExtension`) builds alongside the main app automatically.

---

## Project layout

| Path | Purpose |
|------|---------|
| `TokenTracker/Data/` | Data layer — file reading, API polling, storage |
| `TokenTracker/Models/` | `UsageData` shared model |
| `TokenTracker/Views/` | SwiftUI views |
| `TokenTracker/L10n.swift` | Localization (Russian / English) |
| `TokenTrackerWidget/` | WidgetKit extension |
| `TokenTrackerTests/` | Unit tests |

---

## Code style

- Swift 6 concurrency (`async/await`, `@MainActor`)
- No third-party dependencies
- Localize every user-visible string via `L10n.s("РУ", "EN")`
- Keep views and data logic separate

---

## Submitting changes

1. Fork the repo
2. Create a branch: `git checkout -b fix/your-description`
3. Make your changes, test on device
4. Open a Pull Request with a clear description of what and why

---

## Reporting bugs

Open an [Issue](../../issues) with:
- macOS version
- What you expected vs. what happened
- Steps to reproduce

---

## Localization

The app supports Russian (+ Ukrainian, Belarusian) and English. All strings go through `L10n.s("РУ текст", "EN text")`. If you're adding a new language, extend the `L10n.isRussian` logic and open a PR.
