pub mod accounts;
pub mod app_settings;
pub mod credentials;
pub mod csv_export;
pub mod history;
pub mod limits_api;
pub mod models;
pub mod notify_logic;
pub mod orchestrator;
pub mod pricing;
pub mod tray;
pub mod usage_reader;

use tauri::Manager;
use tauri_plugin_autostart::MacosLauncher;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
            // second launch → surface the existing window
            tray::show_window(app);
        }))
        .plugin(tauri_plugin_autostart::init(
            MacosLauncher::LaunchAgent,
            Some(vec!["--minimized"]),
        ))
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_positioner::init())
        .manage(orchestrator::AppState::init())
        .invoke_handler(tauri::generate_handler![
            orchestrator::get_usage,
            orchestrator::get_history,
            orchestrator::get_settings,
            orchestrator::set_settings,
            orchestrator::get_accounts,
            orchestrator::add_account,
            orchestrator::claude_code_autologin,
            orchestrator::set_active_account,
            orchestrator::remove_account,
            orchestrator::refresh_now,
            orchestrator::export_history_csv,
        ])
        .setup(|app| {
            tray::create_tray(app.handle())?;
            orchestrator::start_background(app.handle().clone());

            // Show window unless started minimized (autostart)
            let minimized = std::env::args().any(|a| a == "--minimized");
            if !minimized {
                if let Some(win) = app.get_webview_window("main") {
                    let _ = win.show();
                    let _ = win.set_focus();
                }
            }
            Ok(())
        })
        .on_window_event(|window, event| {
            // Close button hides to tray instead of quitting
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running TokenTracker");
}
