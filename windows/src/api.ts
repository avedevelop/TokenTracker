import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

export interface Limits {
  fiveHourUtilization: number;
  fiveHourResetsAt: string | null;
  weeklyUtilization: number;
  weeklyResetsAt: string | null;
  sonnetUtilization: number | null;
  opusUtilization: number | null;
  extraUsageUsed: number | null;
  extraUsageLimit: number | null;
  extraUsageEnabled: boolean;
}

export interface ProjectUsage { name: string; tokens: number; cost: number }

export interface UsageData {
  tokensToday: number;
  costToday: number;
  sessionsToday: number;
  cacheHitRate: number;
  limits: Limits | null;
  hourlyUsage: number[];
  limitsUpdatedAt: string | null;
  tokensUpdatedAt: string | null;
  topProjects: ProjectUsage[];
}

export interface DayRecord {
  date: string; cost: number; tokens: number; sessions: number;
  cacheHitRate: number; maxFiveHourPct: number; maxWeeklyPct: number;
}

export interface Settings {
  theme: "dark" | "light" | "system";
  language: "ru" | "en" | null;
  notifEnabled: boolean;
  notifThreshold: number;
  budgetDaily: number;
  budgetMonthly: number;
  autostart: boolean;
  onboardingDone: boolean;
  lastNotified5h: number;
  lastNotifiedWeekly: number;
  budgetNotifiedToday: string;
  budgetNotifiedMonth: string;
}

export interface AccountProfile {
  id: string; name: string; orgId: string;
  email: string | null; fullName: string | null;
  tokenValid: boolean; auth: "cookie" | "bearer";
}

export interface AccountsView {
  profiles: AccountProfile[]; activeId: string | null; maxAccounts: number;
}

export const api = {
  getUsage: () => invoke<UsageData>("get_usage"),
  getHistory: () => invoke<DayRecord[]>("get_history"),
  getSettings: () => invoke<Settings>("get_settings"),
  setSettings: (settings: Settings) => invoke<void>("set_settings", { settings }),
  getAccounts: () => invoke<AccountsView>("get_accounts"),
  addAccount: (sessionKey: string) => invoke<AccountProfile>("add_account", { sessionKey }),
  claudeCodeAutologin: () => invoke<AccountProfile | null>("claude_code_autologin"),
  setActiveAccount: (id: string) => invoke<void>("set_active_account", { id }),
  removeAccount: (id: string) => invoke<void>("remove_account", { id }),
  refreshNow: () => invoke<void>("refresh_now"),
  exportHistoryCsv: () => invoke<string | null>("export_history_csv"),
  onUsageUpdated: (cb: (u: UsageData) => void) =>
    listen<UsageData>("usage-updated", (e) => cb(e.payload)),
  onAccountsUpdated: (cb: () => void) => listen("accounts-updated", cb),
  onCheckUpdatesRequested: (cb: () => void) => listen("check-updates-requested", cb),
};
