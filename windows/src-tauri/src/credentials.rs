use std::collections::HashMap;
use std::path::Path;

use uuid::Uuid;

const KEYRING_SERVICE: &str = "com.tokentracker.session";
const KEYRING_USER: &str = "allTokens";

pub trait SecretVault: Send + Sync {
    fn get(&self) -> Option<String>;
    fn set(&self, value: &str) -> Result<(), String>;
}

/// Production vault: Windows Credential Manager (macOS Keychain when run on the Mac).
pub struct OsVault;

impl SecretVault for OsVault {
    fn get(&self) -> Option<String> {
        keyring_core::Entry::new(KEYRING_SERVICE, KEYRING_USER)
            .ok()?
            .get_password()
            .ok()
    }

    fn set(&self, value: &str) -> Result<(), String> {
        keyring_core::Entry::new(KEYRING_SERVICE, KEYRING_USER)
            .map_err(|e| e.to_string())?
            .set_password(value)
            .map_err(|e| e.to_string())
    }
}

/// Test vault.
#[derive(Default)]
pub struct MemoryVault(std::sync::Mutex<Option<String>>);

impl SecretVault for MemoryVault {
    fn get(&self) -> Option<String> {
        self.0.lock().unwrap().clone()
    }
    fn set(&self, value: &str) -> Result<(), String> {
        *self.0.lock().unwrap() = Some(value.to_string());
        Ok(())
    }
}

pub fn read_tokens(vault: &dyn SecretVault) -> HashMap<Uuid, String> {
    let Some(json) = vault.get() else { return HashMap::new() };
    let Ok(dict) = serde_json::from_str::<HashMap<String, String>>(&json) else {
        return HashMap::new();
    };
    dict.into_iter()
        .filter_map(|(k, v)| Uuid::parse_str(&k).ok().map(|id| (id, v)))
        .collect()
}

pub fn write_tokens(
    vault: &dyn SecretVault,
    tokens: &HashMap<Uuid, String>,
) -> Result<(), String> {
    let dict: HashMap<String, String> =
        tokens.iter().map(|(k, v)| (k.to_string(), v.clone())).collect();
    let json = serde_json::to_string(&dict).map_err(|e| e.to_string())?;
    vault.set(&json)
}

/// Claude Code on Windows stores OAuth creds in ~/.claude/.credentials.json.
pub fn read_claude_code_oauth_token(home: &Path) -> Option<String> {
    let path = home.join(".claude").join(".credentials.json");
    let content = std::fs::read_to_string(path).ok()?;
    let json: serde_json::Value = serde_json::from_str(&content).ok()?;
    json.get("claudeAiOauth")?
        .get("accessToken")?
        .as_str()
        .map(String::from)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use uuid::Uuid;

    #[test]
    fn vault_roundtrip_and_remove() {
        let vault = MemoryVault::default();
        let id = Uuid::new_v4();
        let mut tokens = read_tokens(&vault);
        assert!(tokens.is_empty());
        tokens.insert(id, "sk-test".into());
        write_tokens(&vault, &tokens).unwrap();
        let again = read_tokens(&vault);
        assert_eq!(again.get(&id).unwrap(), "sk-test");
        let mut again = again;
        again.remove(&id);
        write_tokens(&vault, &again).unwrap();
        assert!(read_tokens(&vault).is_empty());
    }

    #[test]
    fn reads_claude_code_credentials_file() {
        let tmp = tempfile::tempdir().unwrap();
        let claude_dir = tmp.path().join(".claude");
        fs::create_dir_all(&claude_dir).unwrap();
        fs::write(
            claude_dir.join(".credentials.json"),
            r#"{"claudeAiOauth":{"accessToken":"oauth-abc","refreshToken":"r"}}"#,
        )
        .unwrap();
        assert_eq!(
            read_claude_code_oauth_token(tmp.path()),
            Some("oauth-abc".to_string())
        );
    }

    #[test]
    fn missing_or_bad_credentials_file_returns_none() {
        let tmp = tempfile::tempdir().unwrap();
        assert_eq!(read_claude_code_oauth_token(tmp.path()), None);
        let claude_dir = tmp.path().join(".claude");
        fs::create_dir_all(&claude_dir).unwrap();
        fs::write(claude_dir.join(".credentials.json"), "not json").unwrap();
        assert_eq!(read_claude_code_oauth_token(tmp.path()), None);
    }
}
