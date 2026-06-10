# TokenTracker for Windows

Native Windows tray app built with Tauri 2 + TypeScript that tracks Claude AI token usage,
costs, and rate limits in real time. All data stays local — no cloud, no telemetry.

## Development

```bash
npm install
npm run tauri dev
```

## Testing

```bash
npm test          # Vitest (TypeScript unit tests)
cargo test        # Rust unit tests (run from src-tauri/)
```

## Release

Tag `win-vX.X.X` on `main` — the GitHub Actions workflow builds the NSIS installer
and uploads it to GitHub Releases together with a `latest.json` updater manifest.
