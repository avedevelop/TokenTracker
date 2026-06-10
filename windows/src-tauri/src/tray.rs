use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Emitter, Manager};

use crate::models::UsageData;

// 3x5 pixel font, digits 0-9; each row is 3 bits (MSB = left pixel)
const DIGITS: [[u8; 5]; 10] = [
    [0b111, 0b101, 0b101, 0b101, 0b111], // 0
    [0b010, 0b110, 0b010, 0b010, 0b111], // 1
    [0b111, 0b001, 0b111, 0b100, 0b111], // 2
    [0b111, 0b001, 0b111, 0b001, 0b111], // 3
    [0b101, 0b101, 0b111, 0b001, 0b001], // 4
    [0b111, 0b100, 0b111, 0b001, 0b111], // 5
    [0b111, 0b100, 0b111, 0b101, 0b111], // 6
    [0b111, 0b001, 0b010, 0b010, 0b010], // 7
    [0b111, 0b101, 0b111, 0b101, 0b111], // 8
    [0b111, 0b101, 0b111, 0b001, 0b111], // 9
];

pub fn color_for_percent(pct: u8) -> [u8; 4] {
    match pct {
        0..=69 => [255, 255, 255, 255],
        70..=89 => [255, 193, 7, 255],
        _ => [255, 82, 82, 255],
    }
}

/// Renders the percent number centered on a transparent 32x32 RGBA canvas.
pub fn render_percent_icon(pct: u8) -> Vec<u8> {
    const SIZE: usize = 32;
    let pct = pct.min(100);
    let color = color_for_percent(pct);
    let digits: Vec<usize> = pct
        .to_string()
        .bytes()
        .map(|b| (b - b'0') as usize)
        .collect();

    // scale 3 for 1-2 digits, scale 2 for 3 digits ("100")
    let scale: usize = if digits.len() <= 2 { 3 } else { 2 };
    let gap = scale; // gap between digits = 1 font pixel
    let glyph_w = 3 * scale;
    let glyph_h = 5 * scale;
    let total_w = digits.len() * glyph_w + (digits.len() - 1) * gap;
    let x0 = (SIZE.saturating_sub(total_w)) / 2;
    let y0 = (SIZE - glyph_h) / 2;

    let mut canvas = vec![0u8; SIZE * SIZE * 4];
    for (i, d) in digits.iter().enumerate() {
        let gx = x0 + i * (glyph_w + gap);
        for (row, bits) in DIGITS[*d].iter().enumerate() {
            for col in 0..3 {
                if bits & (0b100 >> col) == 0 {
                    continue;
                }
                for sy in 0..scale {
                    for sx in 0..scale {
                        let x = gx + col * scale + sx;
                        let y = y0 + row * scale + sy;
                        if x < SIZE && y < SIZE {
                            let idx = (y * SIZE + x) * 4;
                            canvas[idx..idx + 4].copy_from_slice(&color);
                        }
                    }
                }
            }
        }
    }
    canvas
}

const TRAY_ID: &str = "main-tray";

/// Creates the tray (called once from lib.rs setup). Labels follow the
/// same RU/EN rule as the rest of the app (ru for ru/uk/be locales).
pub fn create_tray(app: &AppHandle) -> tauri::Result<()> {
    let sys = sys_locale::get_locale().unwrap_or_default().to_lowercase();
    let is_ru = sys.starts_with("ru") || sys.starts_with("uk") || sys.starts_with("be");
    let (label_updates, label_quit) = if is_ru {
        ("Проверить обновления", "Выход")
    } else {
        ("Check for updates", "Quit")
    };
    let show = MenuItem::with_id(app, "show", "TokenTracker", true, None::<&str>)?;
    let updates = MenuItem::with_id(app, "updates", label_updates, true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", label_quit, true, None::<&str>)?;
    let menu = Menu::with_items(
        app,
        &[&show, &PredefinedMenuItem::separator(app)?, &updates, &quit],
    )?;

    TrayIconBuilder::with_id(TRAY_ID)
        .menu(&menu)
        .show_menu_on_left_click(false)
        .icon(tauri::image::Image::new_owned(render_percent_icon(0), 32, 32))
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show" => toggle_window(app),
            "updates" => {
                let _ = app.emit_to("main", "check-updates-requested", ());
                show_window(app);
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            tauri_plugin_positioner::on_tray_event(tray.app_handle(), &event);
            if let TrayIconEvent::Click { button: MouseButton::Left, .. } = event {
                toggle_window(tray.app_handle());
            }
        })
        .build(app)?;
    Ok(())
}

/// Updates icon + tooltip after each data refresh (called from orchestrator).
pub fn update_tray(app: &AppHandle, usage: &UsageData) {
    let Some(tray) = app.tray_by_id(TRAY_ID) else { return };
    let pct = usage
        .limits
        .as_ref()
        .map(|l| l.five_hour_utilization.round().clamp(0.0, 100.0) as u8)
        .unwrap_or(0);
    let _ = tray.set_icon(Some(tauri::image::Image::new_owned(
        render_percent_icon(pct),
        32,
        32,
    )));
    let _ = tray.set_tooltip(Some(format!(
        "TokenTracker — 5h: {:.0}%  week: {:.0}%  today: ${:.2}",
        usage.limits.as_ref().map_or(0.0, |l| l.five_hour_utilization),
        usage.limits.as_ref().map_or(0.0, |l| l.weekly_utilization),
        usage.cost_today
    )));
}

pub fn show_window(app: &AppHandle) {
    use tauri_plugin_positioner::{Position, WindowExt};
    if let Some(win) = app.get_webview_window("main") {
        let _ = win.move_window(Position::TrayBottomRight);
        let _ = win.show();
        let _ = win.set_focus();
    }
}

fn toggle_window(app: &AppHandle) {
    if let Some(win) = app.get_webview_window("main") {
        if win.is_visible().unwrap_or(false) {
            let _ = win.hide();
        } else {
            show_window(app);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn icon_is_32x32_rgba() {
        assert_eq!(render_percent_icon(42).len(), 32 * 32 * 4);
    }

    #[test]
    fn icon_has_visible_pixels() {
        let px = render_percent_icon(99);
        assert!(px.chunks(4).any(|c| c[3] > 0));
    }

    #[test]
    fn color_thresholds() {
        assert_eq!(color_for_percent(0), [255, 255, 255, 255]);
        assert_eq!(color_for_percent(69), [255, 255, 255, 255]);
        assert_eq!(color_for_percent(70), [255, 193, 7, 255]);
        assert_eq!(color_for_percent(90), [255, 82, 82, 255]);
        assert_eq!(color_for_percent(100), [255, 82, 82, 255]);
    }

    #[test]
    fn caps_at_100() {
        // must not panic on out-of-range input
        let _ = render_percent_icon(255);
    }
}
