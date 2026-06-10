use std::fs;
use std::path::{Path, PathBuf};

use crate::models::DayRecord;

pub struct HistoryStore {
    file: PathBuf,
}

impl HistoryStore {
    pub fn new(dir: &Path) -> Self {
        let _ = fs::create_dir_all(dir);
        Self { file: dir.join("history.json") }
    }

    pub fn load(&self) -> Vec<DayRecord> {
        let Ok(data) = fs::read_to_string(&self.file) else { return vec![] };
        let mut records: Vec<DayRecord> = serde_json::from_str(&data).unwrap_or_default();
        records.sort_by(|a, b| a.date.cmp(&b.date));
        records
    }

    pub fn save(&self, snapshot: DayRecord) {
        let mut records = self.load();
        records.retain(|r| r.date != snapshot.date);
        records.push(snapshot);
        records.sort_by(|a, b| a.date.cmp(&b.date));
        if records.len() > 90 {
            records = records.split_off(records.len() - 90);
        }
        if let Ok(json) = serde_json::to_string(&records) {
            let _ = fs::write(&self.file, json);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::DayRecord;

    fn rec(date: &str, cost: f64) -> DayRecord {
        DayRecord {
            date: date.into(),
            cost,
            tokens: 1,
            sessions: 1,
            cache_hit_rate: 0.0,
            max_five_hour_pct: 0.0,
            max_weekly_pct: 0.0,
        }
    }

    #[test]
    fn save_replaces_same_date_and_sorts() {
        let tmp = tempfile::tempdir().unwrap();
        let store = HistoryStore::new(tmp.path());
        store.save(rec("2026-06-09", 1.0));
        store.save(rec("2026-06-08", 2.0));
        store.save(rec("2026-06-09", 3.0)); // replaces
        let all = store.load();
        assert_eq!(all.len(), 2);
        assert_eq!(all[0].date, "2026-06-08");
        assert_eq!(all[1].cost, 3.0);
    }

    #[test]
    fn keeps_only_90_latest() {
        let tmp = tempfile::tempdir().unwrap();
        let store = HistoryStore::new(tmp.path());
        for i in 0..95 {
            store.save(rec(&format!("2026-01-{:02}x{}", (i % 28) + 1, i), i as f64));
        }
        assert_eq!(store.load().len(), 90);
    }

    #[test]
    fn load_missing_file_returns_empty() {
        let tmp = tempfile::tempdir().unwrap();
        assert!(HistoryStore::new(tmp.path()).load().is_empty());
    }
}
