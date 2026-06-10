use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;

use chrono::Local;
use tauri::{AppHandle, Emitter, Manager, State};
use tauri_plugin_notification::NotificationExt;
use uuid::Uuid;

use crate::accounts::{AccountProfile, AccountsManager, AuthKind};
use crate::app_settings::{data_dir, Settings, SettingsStore};
use crate::credentials::{read_claude_code_oauth_token, OsVault};
use crate::csv_export::history_to_csv;
use crate::history::HistoryStore;
use crate::limits_api::{self, ApiError, AuthMethod};
use crate::models::{DayRecord, Limits, UsageData};
use crate::notify_logic;
use crate::usage_reader;

pub struct AppState {
    pub usage: Mutex<UsageData>,
    pub limits_by_account: Mutex<HashMap<Uuid, Limits>>,
    pub accounts: Mutex<AccountsManager>,
    pub settings: Mutex<Settings>,
    pub settings_store: SettingsStore,
    pub history: HistoryStore,
    pub client: reqwest::Client,
}

impl AppState {
    pub fn init() -> Self {
        let dir = data_dir();
        let settings_store = SettingsStore::new(&dir);
        Self {
            usage: Mutex::new(UsageData::empty()),
            limits_by_account: Mutex::new(HashMap::new()),
            accounts: Mutex::new(AccountsManager::new(&dir, Box::new(OsVault))),
            settings: Mutex::new(settings_store.load()),
            settings_store,
            history: HistoryStore::new(&dir),
            client: reqwest::Client::new(),
        }
    }

    fn save_settings(&self) {
        let s = self.settings.lock().unwrap().clone();
        self.settings_store.save(&s);
    }
}

fn lang(state: &AppState) -> String {
    if let Some(l) = state.settings.lock().unwrap().language.clone() {
        return l;
    }
    let sys = sys_locale::get_locale().unwrap_or_default().to_lowercase();
    if sys.starts_with("ru") || sys.starts_with("uk") || sys.starts_with("be") {
        "ru".into()
    } else {
        "en".into()
    }
}

fn ru(lang: &str) -> bool { lang == "ru" }

// ---------- Token usage refresh (JSONL) ----------

pub fn refresh_usage(app: &AppHandle) {
    let state: State<AppState> = app.state();
    let fresh = usage_reader::read_today_usage(&usage_reader::default_projects_dir());
    {
        let mut usage = state.usage.lock().unwrap();
        // keep limits fields, replace token fields
        usage.tokens_today = fresh.tokens_today;
        usage.cost_today = fresh.cost_today;
        usage.sessions_today = fresh.sessions_today;
        usage.cache_hit_rate = fresh.cache_hit_rate;
        usage.hourly_usage = fresh.hourly_usage;
        usage.top_projects = fresh.top_projects;
        usage.tokens_updated_at = fresh.tokens_updated_at;
    }
    check_budget_notifications(app);
    snapshot_history(&state);
    emit_usage(app);
}

fn emit_usage(app: &AppHandle) {
    let state: State<AppState> = app.state();
    let usage = state.usage.lock().unwrap().clone();
    let _ = app.emit("usage-updated", &usage);
    crate::tray::update_tray(app, &usage);
}

fn snapshot_history(state: &State<AppState>) {
    let usage = state.usage.lock().unwrap().clone();
    let today = Local::now().format("%Y-%m-%d").to_string();
    state.history.save(DayRecord {
        date: today,
        cost: usage.cost_today,
        tokens: usage.tokens_today,
        sessions: usage.sessions_today,
        cache_hit_rate: usage.cache_hit_rate,
        max_five_hour_pct: usage.limits.as_ref().map_or(0.0, |l| l.five_hour_utilization),
        max_weekly_pct: usage.limits.as_ref().map_or(0.0, |l| l.weekly_utilization),
    });
}

// ---------- Limits polling ----------

fn auth_for(profile: &AccountProfile, token: String) -> AuthMethod {
    match profile.auth {
        AuthKind::Cookie => AuthMethod::Cookie(token),
        AuthKind::Bearer => AuthMethod::Bearer(token),
    }
}

pub async fn poll_limits_once(app: AppHandle) {
    let state: State<AppState> = app.state();
    let jobs: Vec<(AccountProfile, String)> = {
        let accounts = state.accounts.lock().unwrap();
        accounts
            .profiles()
            .iter()
            .filter_map(|p| accounts.token_for(p.id).map(|t| (p.clone(), t)))
            .collect()
    };

    let client = state.client.clone();
    let mut handles = vec![];
    for (profile, token) in jobs {
        let client = client.clone();
        handles.push(tokio::spawn(async move {
            let auth = auth_for(&profile, token);
            // Self-heal a missing org id (mirror of macOS fetchAndCacheOrgId)
            let org_id = if profile.org_id.is_empty() {
                limits_api::fetch_org_id(&client, &auth).await.unwrap_or_default()
            } else {
                profile.org_id.clone()
            };
            let result = limits_api::fetch_limits(&client, &auth, &org_id).await;
            (profile.id, org_id, result)
        }));
    }

    for handle in handles {
        let Ok((id, org_id, result)) = handle.await else { continue };
        match result {
            Ok(limits) => {
                let mut accounts = state.accounts.lock().unwrap();
                accounts.mark_token_status(id, true);
                if !org_id.is_empty() {
                    accounts.update_org_id(id, org_id);
                }
                drop(accounts);
                state.limits_by_account.lock().unwrap().insert(id, limits);
            }
            Err(ApiError::Unauthorized) => {
                state.accounts.lock().unwrap().mark_token_status(id, false);
            }
            Err(_) => { /* network blip — keep last known limits */ }
        }
    }

    apply_active_limits(&app);
    check_limit_notifications(&app);
    snapshot_history(&app.state());
    emit_usage(&app);
    let _ = app.emit("accounts-updated", ());
}

fn apply_active_limits(app: &AppHandle) {
    let state: State<AppState> = app.state();
    let active = state.accounts.lock().unwrap().active_id();
    let limits = active.and_then(|id| state.limits_by_account.lock().unwrap().get(&id).cloned());
    let mut usage = state.usage.lock().unwrap();
    if let Some(l) = limits {
        usage.limits = Some(l);
        usage.limits_updated_at = Some(Local::now().to_rfc3339());
    }
}

// ---------- Notifications ----------

fn notify(app: &AppHandle, title: &str, body: &str) {
    let _ = app.notification().builder().title(title).body(body).show();
}

fn check_limit_notifications(app: &AppHandle) {
    let state: State<AppState> = app.state();
    let (enabled, threshold, last5, lastw) = {
        let s = state.settings.lock().unwrap();
        (s.notif_enabled, s.notif_threshold, s.last_notified_5h, s.last_notified_weekly)
    };
    if !enabled {
        return;
    }
    let Some(limits) = state.usage.lock().unwrap().limits.clone() else { return };
    let l = lang(&state);

    let d5 = notify_logic::check_limit(limits.five_hour_utilization / 100.0, last5, threshold);
    if d5.fire {
        let pct = limits.five_hour_utilization as i64;
        notify(app, "TokenTracker", &if ru(&l) {
            format!("5-часовой лимит: {pct}%")
        } else {
            format!("5-hour limit: {pct}%")
        });
    }
    let dw = notify_logic::check_limit(limits.weekly_utilization / 100.0, lastw, threshold);
    if dw.fire {
        let pct = limits.weekly_utilization as i64;
        notify(app, "TokenTracker", &if ru(&l) {
            format!("Недельный лимит: {pct}%")
        } else {
            format!("Weekly limit: {pct}%")
        });
    }
    {
        let mut s = state.settings.lock().unwrap();
        s.last_notified_5h = d5.new_last;
        s.last_notified_weekly = dw.new_last;
    }
    state.save_settings();
}

fn check_budget_notifications(app: &AppHandle) {
    let state: State<AppState> = app.state();
    let cost = state.usage.lock().unwrap().cost_today;
    let l = lang(&state);
    let today = Local::now().format("%Y-%m-%d").to_string();
    let month = Local::now().format("%Y-%m").to_string();
    let (daily, monthly, marker_day, marker_month) = {
        let s = state.settings.lock().unwrap();
        (s.budget_daily, s.budget_monthly, s.budget_notified_today.clone(), s.budget_notified_month.clone())
    };

    if notify_logic::should_fire_budget(cost, daily, &marker_day, &today) {
        notify(
            app,
            &if ru(&l) { "Бюджет исчерпан".into() } else { "Daily budget reached".to_string() },
            &format!("${cost:.2} / ${daily:.2}"),
        );
        state.settings.lock().unwrap().budget_notified_today = today;
        state.save_settings();
    }

    // Monthly spend = sum of history for the current month + today's live cost is already snapshotted
    let monthly_spend: f64 = state
        .history
        .load()
        .iter()
        .filter(|r| r.date.starts_with(&month))
        .map(|r| r.cost)
        .sum();
    if notify_logic::should_fire_budget(monthly_spend, monthly, &marker_month, &month) {
        notify(
            app,
            &if ru(&l) { "Месячный бюджет исчерпан".into() } else { "Monthly budget reached".to_string() },
            &format!("${monthly_spend:.2} / ${monthly:.2}"),
        );
        state.settings.lock().unwrap().budget_notified_month = month;
        state.save_settings();
    }
}

// ---------- Background loops (started from lib.rs setup) ----------

pub fn start_background(app: AppHandle) {
    // Initial reads
    refresh_usage(&app);

    // 60s limits poll loop
    let poll_app = app.clone();
    tauri::async_runtime::spawn(async move {
        loop {
            poll_limits_once(poll_app.clone()).await;
            tokio::time::sleep(Duration::from_secs(60)).await;
        }
    });

    // File watcher with 2s debounce on ~/.claude/projects
    let watch_app = app.clone();
    std::thread::spawn(move || {
        let dir = usage_reader::default_projects_dir();
        let (tx, rx) = std::sync::mpsc::channel();
        let mut debouncer = match notify_debouncer_mini::new_debouncer(Duration::from_secs(2), tx) {
            Ok(d) => d,
            Err(_) => return,
        };
        if debouncer
            .watcher()
            .watch(&dir, notify_debouncer_mini::notify::RecursiveMode::Recursive)
            .is_err()
        {
            return; // dir missing — UI shows empty state; watcher simply not active
        }
        for event in rx {
            if event.is_ok() {
                refresh_usage(&watch_app);
            }
        }
    });
}

// ---------- Tauri commands ----------

#[derive(serde::Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct AccountsView {
    pub profiles: Vec<AccountProfile>,
    pub active_id: Option<Uuid>,
    pub max_accounts: usize,
}

#[tauri::command]
pub fn get_usage(state: State<AppState>) -> UsageData {
    state.usage.lock().unwrap().clone()
}

#[tauri::command]
pub fn get_history(state: State<AppState>) -> Vec<DayRecord> {
    state.history.load()
}

#[tauri::command]
pub fn get_settings(state: State<AppState>) -> Settings {
    state.settings.lock().unwrap().clone()
}

#[tauri::command]
pub fn set_settings(app: AppHandle, state: State<AppState>, settings: Settings) {
    *state.settings.lock().unwrap() = settings;
    state.save_settings();
    let _ = app.emit("settings-updated", ());
}

#[tauri::command]
pub fn get_accounts(state: State<AppState>) -> AccountsView {
    let accounts = state.accounts.lock().unwrap();
    AccountsView {
        profiles: accounts.profiles().to_vec(),
        active_id: accounts.active_id(),
        max_accounts: crate::accounts::MAX_ACCOUNTS,
    }
}

#[tauri::command]
pub async fn add_account(app: AppHandle, session_key: String) -> Result<AccountProfile, String> {
    let key = session_key.trim().to_string();
    if key.is_empty() {
        return Err("empty key".into());
    }
    let state: State<AppState> = app.state();
    let client = state.client.clone();
    let auth = AuthMethod::Cookie(key.clone());
    let org_id = limits_api::fetch_org_id(&client, &auth)
        .await
        .map_err(|e| e.to_string())?;
    let info = limits_api::fetch_user_info(&client, &auth).await;

    let profile = {
        let mut accounts = state.accounts.lock().unwrap();
        let p = accounts.add("Claude.ai".into(), org_id, key, AuthKind::Cookie)?;
        accounts.update_info(p.id, info.email, info.full_name, true);
        accounts.set_active(p.id);
        accounts.profiles().iter().find(|x| x.id == p.id).unwrap().clone()
    };
    poll_limits_once(app.clone()).await;
    Ok(profile)
}

#[tauri::command]
pub async fn claude_code_autologin(app: AppHandle) -> Result<Option<AccountProfile>, String> {
    let home = dirs::home_dir().ok_or("no home dir")?;
    let Some(token) = read_claude_code_oauth_token(&home) else { return Ok(None) };
    let state: State<AppState> = app.state();
    let client = state.client.clone();
    let auth = AuthMethod::Bearer(token.clone());
    let org_id = limits_api::fetch_org_id(&client, &auth)
        .await
        .map_err(|e| e.to_string())?;
    let info = limits_api::fetch_user_info(&client, &auth).await;
    let profile = {
        let mut accounts = state.accounts.lock().unwrap();
        let p = accounts.add("Claude Code".into(), org_id, token, AuthKind::Bearer)?;
        accounts.update_info(p.id, info.email, info.full_name, true);
        accounts.set_active(p.id);
        accounts.profiles().iter().find(|x| x.id == p.id).unwrap().clone()
    };
    poll_limits_once(app.clone()).await;
    Ok(Some(profile))
}

#[tauri::command]
pub fn set_active_account(app: AppHandle, state: State<AppState>, id: Uuid) {
    state.accounts.lock().unwrap().set_active(id);
    apply_active_limits(&app);
    emit_usage(&app);
    let _ = app.emit("accounts-updated", ());
}

#[tauri::command]
pub fn remove_account(app: AppHandle, state: State<AppState>, id: Uuid) {
    state.accounts.lock().unwrap().remove(id);
    state.limits_by_account.lock().unwrap().remove(&id);
    apply_active_limits(&app);
    emit_usage(&app);
    let _ = app.emit("accounts-updated", ());
}

#[tauri::command]
pub async fn refresh_now(app: AppHandle) {
    refresh_usage(&app);
    poll_limits_once(app).await;
}

#[tauri::command]
pub async fn export_history_csv(app: AppHandle) -> Result<Option<String>, String> {
    use tauri_plugin_dialog::DialogExt;
    let state: State<AppState> = app.state();
    let csv = history_to_csv(&state.history.load());
    let path = app
        .dialog()
        .file()
        .set_file_name("tokentracker-history.csv")
        .add_filter("CSV", &["csv"])
        .blocking_save_file();
    let Some(path) = path else { return Ok(None) };
    let path = path.into_path().map_err(|e| e.to_string())?;
    std::fs::write(&path, csv).map_err(|e| e.to_string())?;
    Ok(Some(path.display().to_string()))
}
