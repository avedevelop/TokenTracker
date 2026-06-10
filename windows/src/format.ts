import type { Lang } from "./l10n";

export function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function formatTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return String(n);
}

export function formatCost(usd: number): string {
  return `$${usd.toFixed(2)}`;
}

export function countdown(resetsAtIso: string | null, lang: Lang): string {
  if (!resetsAtIso) return "—";
  const ms = new Date(resetsAtIso).getTime() - Date.now();
  const [h, m] = lang === "ru" ? ["ч", "м"] : ["h", "m"];
  if (ms <= 0) return `0${m}`;
  const totalMin = Math.ceil(ms / 60_000);
  const hours = Math.floor(totalMin / 60);
  const mins = totalMin % 60;
  return hours > 0 ? `${hours}${h} ${mins}${m}` : `${mins}${m}`;
}
