# TokenTracker 1.4.0 Design: Smart Command Center

## Summary

TokenTracker 1.4.0 should be a strong desktop-focused release that turns the app from a passive usage display into a practical command center for Claude Code usage. The release should help users answer three questions quickly:

- Can I keep working right now?
- What changed since yesterday or last week?
- Which projects are driving cost, tokens, and limit pressure?

This release does not include iOS/iCloud sync, Anthropic API tracking, Apple Developer signing, or notarization-dependent functionality. The app must remain shippable as the current project is shipped: macOS-only, local-first, open source, Sparkle/Homebrew-compatible, and usable without an Apple Developer account.

## Goals

- Add useful, unique features around usage intelligence rather than only more charts.
- Improve dashboard hierarchy so important status is visible immediately.
- Make historical usage and project trends easier to understand.
- Add a compact macOS utility experience through the menu bar.
- Improve widget-related UX with clear status and troubleshooting, without changing WidgetKit architecture.
- Keep the release scope large enough to feel like `1.4.0`, but bounded enough to ship.

## Non-Goals

- No iOS companion app.
- No iCloud sync.
- No Anthropic API key support.
- No Apple Developer signing or notarization requirement.
- No switch back to `AppIntentConfiguration` for widgets.
- No system-level widget cache reset automation.
- No cloud service, telemetry, or remote analytics.

## User Experience

### Smart Dashboard

The dashboard gets a new top status area that summarizes usage health in plain language. It should show:

- Overall status: `Safe`, `Watch`, or `Critical`.
- The primary reason for that status.
- Current 5-hour and weekly utilization.
- Time until the next meaningful reset.
- A short recommendation, such as "Good window to work", "Usage is climbing fast", or "Wait for reset if possible".

The status should be calculated locally from existing limit data and recent history. It must avoid pretending to be perfectly predictive. Copy should be practical and cautious.

### Limit Intelligence

The limits card should move beyond raw percentages:

- Show 5-hour and weekly utilization.
- Show reset countdowns.
- Show recent trend direction.
- Estimate whether the current burn rate is normal, high, or unusually high.
- Show historical 5-hour utilization over recent days.

Credits or extra usage rows should not appear on the main dashboard unless they are intentionally supported as a first-class feature later. For 1.4.0, they should stay out of the primary limits UI.

### Project Insights

The project section should become more useful than a top-5 list:

- Show top projects by cost and tokens.
- Show deltas compared with the previous comparable period.
- Flag a project when usage spikes compared with its recent baseline.
- Support period selection: today, 7 days, and 30 days.

The first implementation can use simple deterministic rules for spike detection, such as "current period is at least 50% higher than the previous comparable period and exceeds a small minimum threshold".

### History And Insights

The existing history area should become an Insights screen with:

- Usage chart by day.
- Cost chart by day.
- Token chart by day.
- Project breakdown table or list.
- Period comparison summary.

The goal is not to create a complex analytics suite. The screen should be scannable and answer what changed.

### Menu Bar Mini Dashboard

TokenTracker should feel more like a native macOS utility. Add a compact menu bar experience:

- Current status: Safe, Watch, or Critical.
- 5-hour utilization.
- Weekly utilization.
- Cost today.
- Last sync time.
- Quick actions: sync now, open dashboard, open history/insights, switch active account.

This must not depend on Apple Developer signing. It should use standard AppKit/SwiftUI menu bar capabilities already available to locally signed or unsigned apps.

### Widget Health

Instead of attempting to programmatically fix WidgetKit registration/cache issues, Settings should expose a small widget status section:

- Selected widget account.
- Last widget data update.
- Local server status.
- Whether the app has recent data available for widgets.
- Short troubleshooting copy: if the app does not appear in the widget picker after install/update, restart macOS or log out and back in.

This keeps the fix honest: WidgetKit discovery can be cached by macOS, and the app should explain that instead of claiming it can always repair the system state.

### Settings Cleanup

Settings should be grouped around user intent:

- Account
- Widget
- Budget
- Alerts
- Appearance/Behavior
- About

The goal is to reduce scrolling and make the app feel calmer. This can be done incrementally while preserving existing settings.

## Data Model

The release can build on the current local data model:

- `UsageData` remains the main snapshot model.
- `HistoryStore` becomes the source for period comparison and trend calculations.
- `SharedStore` continues to feed widgets through the local server.
- Existing project usage data should be reused for project insights.

New derived models should be small and testable:

- `UsageStatus`: safe/watch/critical plus reason and recommendation.
- `PeriodComparison`: current value, previous value, delta, percent change.
- `ProjectInsight`: project name, cost, tokens, delta, spike flag.
- `LimitTrend`: utilization, reset time, recent direction, burn-rate category.

These should be derived from stored usage/history rather than persisted as separate long-lived state unless persistence is needed for performance.

## Status Rules

Initial status rules should be simple and transparent:

- `Critical`: 5-hour utilization is near exhaustion, weekly utilization is near exhaustion, or projected exhaustion happens before reset.
- `Watch`: utilization is elevated, burn rate is high, or cost/tokens are significantly above recent baseline.
- `Safe`: limits and trends are within normal range.

Exact thresholds should be constants in one place so they can be tuned later. The UI should not expose every threshold.

## Error Handling

- If limits are unavailable, show a clear "limits unavailable" state and keep showing today/history data where possible.
- If history is sparse, show comparisons only when there is enough data.
- If project names are missing, group under a stable fallback such as "Unknown project".
- If the local widget server is not running, show that in Widget Health without alarming language.
- If sync fails, keep the last known data visible and show last successful sync.

## Testing

Add focused unit coverage for:

- Status classification.
- Period comparison math.
- Spike detection.
- Empty/sparse history behavior.
- Widget health derived state where it can be tested without WidgetKit.

Run Xcode build verification for the app and widget extension. UI-level behavior can be verified manually for dashboard, menu bar, widget settings, and light/dark themes.

## Release Notes Draft

TokenTracker 1.4.0 introduces Smart Command Center, a major desktop-focused upgrade for understanding and controlling Claude Code usage:

- Smart dashboard status with Safe, Watch, and Critical states.
- Limit intelligence with trends, reset context, and burn-rate hints.
- Project insights with period comparison and spike detection.
- New Insights screen for daily usage, cost, tokens, and projects.
- Menu bar mini-dashboard with quick actions.
- Widget health section with clearer status and troubleshooting.
- Cleaner dashboard and settings organization.

## Initial Decisions

- Status thresholds should start as conservative constants and be tuned after manual testing.
- Menu bar mode should be enabled by default, with a setting to hide it.
- The current History tab should be renamed to Insights and expanded rather than adding another top-level tab.
- Dashboard redesign should focus on hierarchy and usefulness, not a full visual rewrite of every component.

## Recommended MVP

The minimum strong 1.4.0 should include:

- Smart Dashboard status.
- Limit Intelligence.
- Project Insights.
- Enhanced History/Insights screen.
- Menu Bar Mini Dashboard.
- Widget Health section.
- Settings cleanup for Widget/Budget/Alerts/About.

Anything beyond this, such as deeper long-term trends or advanced anomaly detection, should wait for 1.4.x.
