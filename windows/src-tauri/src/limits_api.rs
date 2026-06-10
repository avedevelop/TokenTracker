use serde::{Deserialize, Serialize};

use crate::models::Limits;

const BASE_URL: &str = "https://claude.ai";

#[derive(Debug, Clone)]
pub enum AuthMethod {
    Cookie(String), // sessionKey value
    Bearer(String), // OAuth access token
}

#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("unauthorized")]
    Unauthorized,
    #[error("unexpected response: {0}")]
    Unexpected(String),
    #[error("network: {0}")]
    Network(String),
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub email: Option<String>,
    pub full_name: Option<String>,
}

// ---------- Pure parsing (unit-tested) ----------

pub fn parse_limits(body: &str) -> Result<Limits, ApiError> {
    let json: serde_json::Value =
        serde_json::from_str(body).map_err(|e| ApiError::Unexpected(e.to_string()))?;
    let obj = json
        .as_object()
        .ok_or_else(|| ApiError::Unexpected("not an object".into()))?;

    let util = |key: &str| -> Option<f64> { obj.get(key)?.get("utilization")?.as_f64() };
    let resets = |key: &str| -> Option<String> {
        obj.get(key)?.get("resets_at")?.as_str().map(String::from)
    };
    let extra = obj.get("extra_usage");

    Ok(Limits {
        five_hour_utilization: util("five_hour").unwrap_or(0.0),
        five_hour_resets_at: resets("five_hour"),
        weekly_utilization: util("seven_day").unwrap_or(0.0),
        weekly_resets_at: resets("seven_day"),
        sonnet_utilization: util("seven_day_sonnet"),
        opus_utilization: util("seven_day_opus"),
        extra_usage_used: extra.and_then(|e| e.get("used_credits")?.as_f64()),
        extra_usage_limit: extra.and_then(|e| e.get("monthly_limit")?.as_f64()),
        extra_usage_enabled: extra
            .and_then(|e| e.get("is_enabled")?.as_bool())
            .unwrap_or(false),
    })
}

pub fn parse_org_id(body: &str) -> Option<String> {
    let json: serde_json::Value = serde_json::from_str(body).ok()?;
    json.as_array()?.first()?.get("id")?.as_str().map(String::from)
}

pub fn parse_user_info(body: &str) -> UserInfo {
    let Ok(json) = serde_json::from_str::<serde_json::Value>(body) else {
        return UserInfo::default();
    };
    UserInfo {
        email: json.get("email").and_then(|v| v.as_str()).map(String::from),
        full_name: json
            .get("full_name")
            .or_else(|| json.get("name"))
            .and_then(|v| v.as_str())
            .map(String::from),
    }
}

// ---------- HTTP layer (thin, verified manually in Task 22) ----------

fn request(client: &reqwest::Client, url: &str, auth: &AuthMethod) -> reqwest::RequestBuilder {
    let req = client
        .get(url)
        .header("anthropic-client-platform", "web_claude_ai")
        .header("Accept", "application/json");
    match auth {
        AuthMethod::Cookie(key) => req.header("Cookie", format!("sessionKey={key}")),
        AuthMethod::Bearer(token) => req.header("Authorization", format!("Bearer {token}")),
    }
}

async fn get_body(
    client: &reqwest::Client,
    url: &str,
    auth: &AuthMethod,
) -> Result<String, ApiError> {
    let resp = request(client, url, auth)
        .send()
        .await
        .map_err(|e| ApiError::Network(e.to_string()))?;
    match resp.status().as_u16() {
        200 => resp.text().await.map_err(|e| ApiError::Network(e.to_string())),
        401 | 403 => Err(ApiError::Unauthorized),
        code => Err(ApiError::Unexpected(format!("HTTP {code}"))),
    }
}

pub async fn fetch_org_id(client: &reqwest::Client, auth: &AuthMethod) -> Result<String, ApiError> {
    let body = get_body(client, &format!("{BASE_URL}/api/organizations"), auth).await?;
    parse_org_id(&body).ok_or_else(|| ApiError::Unexpected("no org id".into()))
}

pub async fn fetch_user_info(client: &reqwest::Client, auth: &AuthMethod) -> UserInfo {
    match get_body(client, &format!("{BASE_URL}/api/account"), auth).await {
        Ok(body) => parse_user_info(&body),
        Err(_) => UserInfo::default(),
    }
}

pub async fn fetch_limits(
    client: &reqwest::Client,
    auth: &AuthMethod,
    org_id: &str,
) -> Result<Limits, ApiError> {
    if org_id.is_empty() {
        return Err(ApiError::Unexpected("missing org id".into()));
    }
    let body =
        get_body(client, &format!("{BASE_URL}/api/organizations/{org_id}/usage"), auth).await?;
    parse_limits(&body)
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = r#"{
        "five_hour": {"utilization": 42.5, "resets_at": "2026-06-10T18:00:00.000Z"},
        "seven_day": {"utilization": 9.0, "resets_at": "2026-06-14T00:00:00.000Z"},
        "seven_day_sonnet": {"utilization": 12.0},
        "seven_day_opus": {"utilization": 3.0},
        "extra_usage": {"used_credits": 575.0, "monthly_limit": 1000.0, "is_enabled": true}
    }"#;

    #[test]
    fn parses_full_payload() {
        let l = parse_limits(FIXTURE).unwrap();
        assert!((l.five_hour_utilization - 42.5).abs() < 1e-9);
        assert_eq!(l.five_hour_resets_at.as_deref(), Some("2026-06-10T18:00:00.000Z"));
        assert!((l.weekly_utilization - 9.0).abs() < 1e-9);
        assert_eq!(l.sonnet_utilization, Some(12.0));
        assert_eq!(l.opus_utilization, Some(3.0));
        assert_eq!(l.extra_usage_used, Some(575.0));
        assert_eq!(l.extra_usage_limit, Some(1000.0));
        assert!(l.extra_usage_enabled);
    }

    #[test]
    fn parses_minimal_payload_with_defaults() {
        let l = parse_limits(r#"{"five_hour": {"utilization": 10.0}}"#).unwrap();
        assert!((l.five_hour_utilization - 10.0).abs() < 1e-9);
        assert_eq!(l.weekly_utilization, 0.0);
        assert_eq!(l.sonnet_utilization, None);
        assert!(!l.extra_usage_enabled);
    }

    #[test]
    fn rejects_non_object() {
        assert!(parse_limits("[]").is_err());
    }

    #[test]
    fn parses_org_id_from_organizations_response() {
        let json = r#"[{"id": "org-123", "name": "Personal"}]"#;
        assert_eq!(parse_org_id(json), Some("org-123".to_string()));
        assert_eq!(parse_org_id("[]"), None);
    }

    #[test]
    fn parses_user_info() {
        let json = r#"{"email": "a@b.c", "full_name": "Vlad B"}"#;
        let info = parse_user_info(json);
        assert_eq!(info.email.as_deref(), Some("a@b.c"));
        assert_eq!(info.full_name.as_deref(), Some("Vlad B"));
    }
}
