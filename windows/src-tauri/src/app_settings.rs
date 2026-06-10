use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    pub theme: String,            // "dark" | "light" | "system"
    pub language: Option<String>, // None = auto by OS locale; "ru" | "en"
    pub notif_enabled: bool,
    pub notif_threshold: f64, // 0.0–1.0
    pub budget_daily: f64,    // USD, 0 = off
    pub budget_monthly: f64,  // USD, 0 = off
    pub autostart: bool,
    pub onboarding_done: bool,
    // runtime anti-spam state (mirrors macOS UserDefaults keys)
    pub last_notified_5h: f64,
    pub last_notified_weekly: f64,
    pub budget_notified_today: String, // day marker
    pub budget_notified_month: String, // yyyy-MM
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            theme: "dark".into(),
            language: None,
            notif_enabled: true,
            notif_threshold: 0.8,
            budget_daily: 0.0,
            budget_monthly: 0.0,
            autostart: false,
            onboarding_done: false,
            last_notified_5h: 0.0,
            last_notified_weekly: 0.0,
            budget_notified_today: String::new(),
            budget_notified_month: String::new(),
        }
    }
}

pub struct SettingsStore {
    file: PathBuf,
}

impl SettingsStore {
    pub fn new(dir: &Path) -> Self {
        let _ = fs::create_dir_all(dir);
        Self { file: dir.join("settings.json") }
    }

    pub fn load(&self) -> Settings {
        fs::read_to_string(&self.file)
            .ok()
            .and_then(|d| serde_json::from_str(&d).ok())
            .unwrap_or_default()
    }

    pub fn save(&self, settings: &Settings) {
        if let Ok(json) = serde_json::to_string_pretty(settings) {
            let _ = fs::write(&self.file, json);
        }
    }
}

/// App data dir: %APPDATA%\com.tokentracker on Windows.
pub fn data_dir() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("com.tokentracker")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_match_macos_app() {
        let tmp = tempfile::tempdir().unwrap();
        let s = SettingsStore::new(tmp.path()).load();
        assert_eq!(s.theme, "dark");
        assert!(s.notif_enabled);
        assert!((s.notif_threshold - 0.8).abs() < 1e-9);
        assert_eq!(s.budget_daily, 0.0);
        assert!(!s.onboarding_done);
    }

    #[test]
    fn roundtrip_persists() {
        let tmp = tempfile::tempdir().unwrap();
        let store = SettingsStore::new(tmp.path());
        let mut s = store.load();
        s.theme = "light".into();
        s.budget_daily = 5.0;
        s.last_notified_5h = 0.85;
        store.save(&s);
        let again = store.load();
        assert_eq!(again.theme, "light");
        assert_eq!(again.budget_daily, 5.0);
        assert!((again.last_notified_5h - 0.85).abs() < 1e-9);
    }
}
