pub struct LimitDecision {
    pub fire: bool,
    /// Value to persist as the new "last notified" marker.
    pub new_last: f64,
}

/// Mirror of macOS checkAndFire: 5% bands above threshold, reset below.
pub fn check_limit(current: f64, last_notified: f64, threshold: f64) -> LimitDecision {
    if current < threshold {
        return LimitDecision { fire: false, new_last: 0.0 };
    }
    let band = (current * 20.0).floor() / 20.0;
    let last_band = (last_notified * 20.0).floor() / 20.0;
    if band > last_band {
        LimitDecision { fire: true, new_last: current }
    } else {
        LimitDecision { fire: false, new_last: last_notified }
    }
}

/// Daily/monthly budget: fire once per period.
/// `period_marker` is today's date (yyyy-MM-dd) or current month (yyyy-MM).
pub fn should_fire_budget(
    spend: f64,
    budget: f64,
    last_notified_marker: &str,
    period_marker: &str,
) -> bool {
    budget > 0.0 && spend >= budget && last_notified_marker != period_marker
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fires_on_first_crossing() {
        let d = check_limit(0.82, 0.0, 0.8);
        assert!(d.fire);
        assert_eq!(d.new_last, 0.82);
    }

    #[test]
    fn does_not_refire_within_same_band() {
        // 0.82 and 0.84 are both in the [0.80, 0.85) band
        let d = check_limit(0.84, 0.82, 0.8);
        assert!(!d.fire);
        assert_eq!(d.new_last, 0.82); // unchanged
    }

    #[test]
    fn fires_again_on_next_band() {
        let d = check_limit(0.86, 0.82, 0.8);
        assert!(d.fire);
    }

    #[test]
    fn resets_when_below_threshold() {
        let d = check_limit(0.5, 0.86, 0.8);
        assert!(!d.fire);
        assert_eq!(d.new_last, 0.0);
    }

    #[test]
    fn budget_fires_once_per_day() {
        assert!(should_fire_budget(5.5, 5.0, "2026-06-09", "2026-06-10"));
        assert!(!should_fire_budget(5.5, 5.0, "2026-06-10", "2026-06-10"));
        assert!(!should_fire_budget(4.0, 5.0, "2026-06-09", "2026-06-10"));
        assert!(!should_fire_budget(5.5, 0.0, "", "2026-06-10")); // budget off
    }
}
