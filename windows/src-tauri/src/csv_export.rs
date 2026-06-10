use crate::models::DayRecord;

pub fn history_to_csv(records: &[DayRecord]) -> String {
    let mut out = String::from(
        "date,tokens,cost_usd,sessions,cache_hit_rate,max_five_hour_pct,max_weekly_pct\n",
    );
    for r in records {
        out.push_str(&format!(
            "{},{},{:.4},{},{:.2},{:.1},{:.1}\n",
            r.date, r.tokens, r.cost, r.sessions, r.cache_hit_rate,
            r.max_five_hour_pct, r.max_weekly_pct
        ));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::DayRecord;

    #[test]
    fn renders_header_and_rows() {
        let records = vec![DayRecord {
            date: "2026-06-09".into(),
            cost: 2.345,
            tokens: 127482,
            sessions: 8,
            cache_hit_rate: 0.83,
            max_five_hour_pct: 97.0,
            max_weekly_pct: 9.0,
        }];
        let csv = history_to_csv(&records);
        let mut lines = csv.lines();
        assert_eq!(
            lines.next().unwrap(),
            "date,tokens,cost_usd,sessions,cache_hit_rate,max_five_hour_pct,max_weekly_pct"
        );
        assert_eq!(lines.next().unwrap(), "2026-06-09,127482,2.3450,8,0.83,97.0,9.0");
    }

    #[test]
    fn empty_history_is_header_only() {
        assert_eq!(history_to_csv(&[]).lines().count(), 1);
    }
}
