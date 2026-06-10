use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

use chrono::{DateTime, Local, Timelike};
use serde::Deserialize;

use crate::models::{ProjectUsage, UsageData};
use crate::pricing;

#[derive(Deserialize)]
struct RawEntry {
    #[serde(rename = "type")]
    entry_type: String,
    timestamp: Option<String>,
    #[serde(rename = "sessionId")]
    session_id: Option<String>,
    message: Option<RawMessage>,
}

#[derive(Deserialize)]
struct RawMessage {
    usage: Option<RawUsage>,
}

#[derive(Deserialize, Default)]
struct RawUsage {
    #[serde(default)]
    input_tokens: u64,
    #[serde(default)]
    output_tokens: u64,
    #[serde(default)]
    cache_creation_input_tokens: u64,
    #[serde(default)]
    cache_read_input_tokens: u64,
}

/// Default Claude Code projects dir: ~/.claude/projects
pub fn default_projects_dir() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".claude")
        .join("projects")
}

pub fn read_today_usage(projects_dir: &Path) -> UsageData {
    let day_start = Local::now()
        .date_naive()
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_local_timezone(Local)
        .unwrap();

    let mut total_input: u64 = 0;
    let mut total_output: u64 = 0;
    let mut total_cc: u64 = 0;
    let mut total_cr: u64 = 0;
    let mut sessions: HashSet<String> = HashSet::new();
    let mut hourly: Vec<u64> = vec![0; 24];
    let mut project_tokens: HashMap<String, u64> = HashMap::new();
    let mut project_cost: HashMap<String, f64> = HashMap::new();

    let project_dirs = match fs::read_dir(projects_dir) {
        Ok(rd) => rd.flatten().filter(|e| e.path().is_dir()).collect::<Vec<_>>(),
        Err(_) => vec![],
    };

    for dir_entry in project_dirs {
        let project_name =
            friendly_project_name(&dir_entry.file_name().to_string_lossy());
        for file in jsonl_files(&dir_entry.path()) {
            // Skip files not touched today (mirror of the mtime check on macOS)
            if let Ok(meta) = fs::metadata(&file) {
                if let Ok(modified) = meta.modified() {
                    let modified: DateTime<Local> = modified.into();
                    if modified < day_start {
                        continue;
                    }
                }
            }
            let Ok(content) = fs::read_to_string(&file) else { continue };
            for line in content.lines().filter(|l| !l.is_empty()) {
                let Ok(entry) = serde_json::from_str::<RawEntry>(line) else { continue };
                if entry.entry_type != "assistant" {
                    continue;
                }
                let Some(usage) = entry.message.and_then(|m| m.usage) else { continue };
                let Some(ts) = entry.timestamp else { continue };
                let Ok(date) = DateTime::parse_from_rfc3339(&ts) else { continue };
                let date_local = date.with_timezone(&Local);
                if date_local < day_start {
                    continue;
                }

                let tokens = usage.input_tokens + usage.output_tokens;
                let cost = pricing::entry_cost(
                    usage.input_tokens,
                    usage.output_tokens,
                    usage.cache_creation_input_tokens,
                    usage.cache_read_input_tokens,
                );

                hourly[date_local.hour() as usize] += tokens;
                if let Some(sid) = entry.session_id {
                    sessions.insert(sid);
                }
                total_input += usage.input_tokens;
                total_output += usage.output_tokens;
                total_cc += usage.cache_creation_input_tokens;
                total_cr += usage.cache_read_input_tokens;
                *project_tokens.entry(project_name.clone()).or_insert(0) += tokens;
                *project_cost.entry(project_name.clone()).or_insert(0.0) += cost;
            }
        }
    }

    let cost_today = pricing::entry_cost(total_input, total_output, total_cc, total_cr);
    let denom = total_input + total_output + total_cr;
    let cache_hit = if denom > 0 { total_cr as f64 / denom as f64 } else { 0.0 };

    let mut top: Vec<ProjectUsage> = project_tokens
        .into_iter()
        .filter(|(_, t)| *t > 0)
        .map(|(name, tokens)| ProjectUsage {
            cost: *project_cost.get(&name).unwrap_or(&0.0),
            name,
            tokens,
        })
        .collect();
    top.sort_by(|a, b| b.tokens.cmp(&a.tokens));
    top.truncate(5);

    let mut result = UsageData::empty();
    result.tokens_today = total_input + total_output;
    result.cost_today = cost_today;
    result.sessions_today = sessions.len() as u32;
    result.cache_hit_rate = cache_hit;
    result.hourly_usage = hourly;
    result.top_projects = top;
    result.tokens_updated_at = Some(Local::now().to_rfc3339());
    result
}

pub fn friendly_project_name(folder_name: &str) -> String {
    folder_name
        .split('-')
        .filter(|p| !p.is_empty())
        .last()
        .unwrap_or(folder_name)
        .to_string()
}

fn jsonl_files(dir: &Path) -> Vec<PathBuf> {
    let mut out = vec![];
    let mut stack = vec![dir.to_path_buf()];
    while let Some(d) = stack.pop() {
        let Ok(rd) = fs::read_dir(&d) else { continue };
        for e in rd.flatten() {
            let p = e.path();
            if p.is_dir() {
                stack.push(p);
            } else if p.extension().is_some_and(|x| x == "jsonl") {
                out.push(p);
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, Local};
    use std::fs;

    fn entry(ts: &str, session: &str, input: u64, output: u64, cc: u64, cr: u64) -> String {
        format!(
            r#"{{"type":"assistant","timestamp":"{ts}","sessionId":"{session}","message":{{"usage":{{"input_tokens":{input},"output_tokens":{output},"cache_creation_input_tokens":{cc},"cache_read_input_tokens":{cr}}}}}}}"#
        )
    }

    #[test]
    fn reads_today_only_and_aggregates() {
        let tmp = tempfile::tempdir().unwrap();
        let proj = tmp.path().join("-Users-vlad-dev-my-project");
        fs::create_dir_all(&proj).unwrap();

        let now = Local::now();
        // Clamp: if local time is just after midnight, use `now` to avoid falling on yesterday
        let today_offset = if now.hour() == 0 { Duration::seconds(0) } else { Duration::hours(1) };
        let today_ts = (now - today_offset).to_rfc3339();
        let yesterday_ts = (now - Duration::hours(30)).to_rfc3339();

        let lines = [
            entry(&today_ts, "s1", 100, 50, 1000, 4000),
            entry(&yesterday_ts, "s2", 999, 999, 0, 0), // must be skipped
            entry(&today_ts, "s1", 200, 100, 0, 0),
            r#"{"type":"user","timestamp":"ignored"}"#.to_string(),
            "not json at all".to_string(),
        ]
        .join("\n");
        fs::write(proj.join("session.jsonl"), lines).unwrap();

        let usage = read_today_usage(tmp.path());

        assert_eq!(usage.tokens_today, 100 + 50 + 200 + 100);
        assert_eq!(usage.sessions_today, 1);
        let expected_cost = crate::pricing::entry_cost(300, 150, 1000, 4000);
        assert!((usage.cost_today - expected_cost).abs() < 1e-9);
        // cache hit = 4000 / (300 + 150 + 4000)
        assert!((usage.cache_hit_rate - 4000.0 / 4450.0).abs() < 1e-9);
        assert_eq!(usage.top_projects.len(), 1);
        assert_eq!(usage.top_projects[0].name, "project");
        let hour = (now - today_offset).format("%H").to_string().parse::<usize>().unwrap();
        assert_eq!(usage.hourly_usage[hour], 450);
    }

    #[test]
    fn missing_dir_returns_empty() {
        let usage = read_today_usage(std::path::Path::new("/nonexistent/nowhere"));
        assert_eq!(usage.tokens_today, 0);
        assert_eq!(usage.hourly_usage.len(), 24);
    }

    #[test]
    fn friendly_name_takes_last_dash_part() {
        assert_eq!(friendly_project_name("-Users-vlad-dev-my-project"), "project");
        assert_eq!(friendly_project_name("plain"), "plain");
    }
}
