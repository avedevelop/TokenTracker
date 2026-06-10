import type { Ctx } from "../main";
import { countdown, formatCost, formatTokens } from "../format";

function ring(pct: number, label: string, reset: string): string {
  const r = 30, c = 2 * Math.PI * r;
  const off = c * (1 - Math.min(pct, 100) / 100);
  const color = pct >= 90 ? "var(--danger)" : pct >= 70 ? "var(--warn)" : "var(--accent)";
  return `
    <div class="ring">
      <svg width="76" height="76" viewBox="0 0 76 76">
        <circle cx="38" cy="38" r="${r}" fill="none" stroke="var(--ring-track)" stroke-width="7"/>
        <circle cx="38" cy="38" r="${r}" fill="none" stroke="${color}" stroke-width="7"
          stroke-linecap="round" stroke-dasharray="${c}" stroke-dashoffset="${off}"/>
        <text x="38" y="43" text-anchor="middle" transform="rotate(90 38 38)"
          fill="var(--text)" font-size="15" font-weight="700">${Math.round(pct)}%</text>
      </svg>
      <div class="label">${label}</div>
      <div class="reset">${reset}</div>
    </div>`;
}

export function renderDashboard(el: HTMLElement, ctx: Ctx) {
  const { t, usage, lang } = ctx;
  const l = usage.limits;

  const limitsHtml = l
    ? `<div class="rings">
         ${ring(l.fiveHourUtilization, t("limit.fiveHour"),
            `${t("limit.resets")} ${countdown(l.fiveHourResetsAt, lang)}`)}
         ${ring(l.weeklyUtilization, t("limit.weekly"),
            `${t("limit.resets")} ${countdown(l.weeklyResetsAt, lang)}`)}
       </div>`
    : `<p class="muted">${t("limit.noData")}</p>`;

  const max = Math.max(1, ...usage.hourlyUsage);
  const bars = usage.hourlyUsage
    .map((v) => `<div style="height:${Math.max(2, (v / max) * 100)}%"></div>`)
    .join("");

  const projects = usage.topProjects
    .map(
      (p) => `<div class="row"><span>${p.name}</span>
        <span class="muted">${formatTokens(p.tokens)} · ${formatCost(p.cost)}</span></div>`
    )
    .join("");

  el.innerHTML = `
    <div class="card">${limitsHtml}</div>
    <div class="card">
      <div class="stat-grid">
        <div class="stat"><div class="value">${formatCost(usage.costToday)}</div><div class="label">${t("today.cost")}</div></div>
        <div class="stat"><div class="value">${formatTokens(usage.tokensToday)}</div><div class="label">${t("today.tokens")}</div></div>
        <div class="stat"><div class="value">${usage.sessionsToday}</div><div class="label">${t("today.sessions")}</div></div>
        <div class="stat"><div class="value">${Math.round(usage.cacheHitRate * 100)}%</div><div class="label">${t("today.cache")}</div></div>
      </div>
    </div>
    <div class="card"><h3>${t("today.activity")}</h3>
      ${usage.tokensToday === 0 ? `<p class="muted">${t("today.empty")}</p>` : `<div class="bars">${bars}</div>`}
    </div>
    ${projects ? `<div class="card"><h3>${t("today.topProjects")}</h3>${projects}</div>` : ""}
    ${staleNote(ctx)}
  `;
}

function staleNote(ctx: Ctx): string {
  const ts = ctx.usage.limitsUpdatedAt;
  if (!ts || !ctx.usage.limits) return "";
  const ageMin = Math.floor((Date.now() - new Date(ts).getTime()) / 60_000);
  if (ageMin < 3) return "";
  return `<p class="muted" style="text-align:center">
    ${ctx.t("common.updatedAgo")} ${ageMin}m — ${ctx.t("common.stale")}</p>`;
}
