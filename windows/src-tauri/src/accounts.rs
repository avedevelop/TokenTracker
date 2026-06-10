use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::credentials::{read_tokens, write_tokens, SecretVault};

pub const MAX_ACCOUNTS: usize = 5;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AuthKind {
    Cookie,
    Bearer,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AccountProfile {
    pub id: Uuid,
    pub name: String,
    pub org_id: String,
    pub email: Option<String>,
    pub full_name: Option<String>,
    pub token_valid: bool,
    pub auth: AuthKind,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Manifest {
    active_id: Option<Uuid>,
    profiles: Vec<AccountProfile>,
}

pub struct AccountsManager {
    file: PathBuf,
    manifest: Manifest,
    vault: Box<dyn SecretVault>,
    tokens: HashMap<Uuid, String>,
}

impl AccountsManager {
    pub fn new(dir: &Path, vault: Box<dyn SecretVault>) -> Self {
        let _ = fs::create_dir_all(dir);
        let file = dir.join("accounts.json");
        let manifest = fs::read_to_string(&file)
            .ok()
            .and_then(|d| serde_json::from_str(&d).ok())
            .unwrap_or_default();
        let tokens = read_tokens(vault.as_ref());
        Self { file, manifest, vault, tokens }
    }

    pub fn profiles(&self) -> &[AccountProfile] {
        &self.manifest.profiles
    }

    pub fn active_id(&self) -> Option<Uuid> {
        self.manifest.active_id
    }

    pub fn active_profile(&self) -> Option<&AccountProfile> {
        let id = self.manifest.active_id?;
        self.manifest.profiles.iter().find(|p| p.id == id)
    }

    pub fn token_for(&self, id: Uuid) -> Option<String> {
        self.tokens.get(&id).cloned()
    }

    pub fn add(
        &mut self,
        name: String,
        org_id: String,
        token: String,
        auth: AuthKind,
    ) -> Result<AccountProfile, String> {
        if self.manifest.profiles.len() >= MAX_ACCOUNTS {
            return Err(format!("max {MAX_ACCOUNTS} accounts"));
        }
        let profile = AccountProfile {
            id: Uuid::new_v4(),
            name,
            org_id,
            email: None,
            full_name: None,
            token_valid: true,
            auth,
        };
        self.tokens.insert(profile.id, token);
        write_tokens(self.vault.as_ref(), &self.tokens)?;
        self.manifest.profiles.push(profile.clone());
        if self.manifest.active_id.is_none() {
            self.manifest.active_id = Some(profile.id);
        }
        self.persist();
        Ok(profile)
    }

    pub fn remove(&mut self, id: Uuid) {
        self.tokens.remove(&id);
        let _ = write_tokens(self.vault.as_ref(), &self.tokens);
        self.manifest.profiles.retain(|p| p.id != id);
        if self.manifest.active_id == Some(id) {
            self.manifest.active_id = self.manifest.profiles.first().map(|p| p.id);
        }
        self.persist();
    }

    pub fn set_active(&mut self, id: Uuid) {
        if self.manifest.profiles.iter().any(|p| p.id == id) {
            self.manifest.active_id = Some(id);
            self.persist();
        }
    }

    pub fn update_info(
        &mut self,
        id: Uuid,
        email: Option<String>,
        full_name: Option<String>,
        token_valid: bool,
    ) {
        if let Some(p) = self.manifest.profiles.iter_mut().find(|p| p.id == id) {
            if let (Some(e), true) = (&email, p.name == "Claude.ai") {
                p.name = e.clone();
            }
            p.email = email;
            p.full_name = full_name;
            p.token_valid = token_valid;
            self.persist();
        }
    }

    pub fn update_org_id(&mut self, id: Uuid, org_id: String) {
        if let Some(p) = self.manifest.profiles.iter_mut().find(|p| p.id == id) {
            p.org_id = org_id;
            self.persist();
        }
    }

    pub fn mark_token_status(&mut self, id: Uuid, valid: bool) {
        if let Some(p) = self.manifest.profiles.iter_mut().find(|p| p.id == id) {
            p.token_valid = valid;
            self.persist();
        }
    }

    fn persist(&self) {
        if let Ok(json) = serde_json::to_string_pretty(&self.manifest) {
            let _ = fs::write(&self.file, json);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::credentials::MemoryVault;

    fn store(tmp: &std::path::Path) -> AccountsManager {
        AccountsManager::new(tmp, Box::new(MemoryVault::default()))
    }

    #[test]
    fn add_sets_first_as_active_and_persists() {
        let tmp = tempfile::tempdir().unwrap();
        let mut m = store(tmp.path());
        let p = m.add("Claude.ai".into(), "org-1".into(), "tok-1".into(), AuthKind::Cookie).unwrap();
        assert_eq!(m.active_id(), Some(p.id));
        assert_eq!(m.token_for(p.id).as_deref(), Some("tok-1"));

        // reload from disk with a fresh vault containing the same data
        let m2 = AccountsManager::new(tmp.path(), Box::new(MemoryVault::default()));
        assert_eq!(m2.profiles().len(), 1);
        assert_eq!(m2.profiles()[0].org_id, "org-1");
    }

    #[test]
    fn enforces_max_5() {
        let tmp = tempfile::tempdir().unwrap();
        let mut m = store(tmp.path());
        for i in 0..5 {
            m.add(format!("a{i}"), "o".into(), "t".into(), AuthKind::Cookie).unwrap();
        }
        assert!(m.add("a6".into(), "o".into(), "t".into(), AuthKind::Cookie).is_err());
    }

    #[test]
    fn remove_switches_active() {
        let tmp = tempfile::tempdir().unwrap();
        let mut m = store(tmp.path());
        let p1 = m.add("a".into(), "o1".into(), "t1".into(), AuthKind::Cookie).unwrap();
        let p2 = m.add("b".into(), "o2".into(), "t2".into(), AuthKind::Cookie).unwrap();
        m.set_active(p2.id);
        m.remove(p2.id);
        assert_eq!(m.active_id(), Some(p1.id));
        assert!(m.token_for(p2.id).is_none());
    }

    #[test]
    fn update_info_fills_name_from_email() {
        let tmp = tempfile::tempdir().unwrap();
        let mut m = store(tmp.path());
        let p = m.add("Claude.ai".into(), "o".into(), "t".into(), AuthKind::Cookie).unwrap();
        m.update_info(p.id, Some("a@b.c".into()), None, true);
        assert_eq!(m.profiles()[0].name, "a@b.c");
        assert_eq!(m.profiles()[0].email.as_deref(), Some("a@b.c"));
    }
}
