use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectUsage {
    pub name: String,
    pub tokens: u64,
    pub cost: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct Limits {
    pub five_hour_utilization: f64,          // 0–100
    pub five_hour_resets_at: Option<String>, // ISO8601
    pub weekly_utilization: f64,             // 0–100
    pub weekly_resets_at: Option<String>,
    pub sonnet_utilization: Option<f64>,
    pub opus_utilization: Option<f64>,
    pub extra_usage_used: Option<f64>,
    pub extra_usage_limit: Option<f64>,
    pub extra_usage_enabled: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UsageData {
    pub tokens_today: u64,
    pub cost_today: f64,
    pub sessions_today: u32,
    pub cache_hit_rate: f64,
    pub limits: Option<Limits>,
    pub hourly_usage: Vec<u64>, // exactly 24 buckets
    pub limits_updated_at: Option<String>,
    pub tokens_updated_at: Option<String>,
    pub top_projects: Vec<ProjectUsage>,
}

impl UsageData {
    pub fn empty() -> Self {
        Self {
            tokens_today: 0,
            cost_today: 0.0,
            sessions_today: 0,
            cache_hit_rate: 0.0,
            limits: None,
            hourly_usage: vec![0; 24],
            limits_updated_at: None,
            tokens_updated_at: None,
            top_projects: vec![],
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DayRecord {
    pub date: String, // yyyy-MM-dd
    pub cost: f64,
    pub tokens: u64,
    pub sessions: u32,
    pub cache_hit_rate: f64,
    pub max_five_hour_pct: f64,
    pub max_weekly_pct: f64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_usage_has_24_hour_buckets() {
        assert_eq!(UsageData::empty().hourly_usage.len(), 24);
    }

    #[test]
    fn usage_data_serializes_camel_case() {
        let json = serde_json::to_string(&UsageData::empty()).unwrap();
        assert!(json.contains("\"tokensToday\""));
        assert!(json.contains("\"cacheHitRate\""));
    }
}
