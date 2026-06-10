import { api, type DayRecord } from "../api";
import { formatCost, formatTokens } from "../format";
import type { Ctx } from "../main";

let range: 7 | 30 | 90 = 7;

export async function renderHistory(el: HTMLElement, ctx: Ctx, isCurrent: () => boolean = () => true) {
  const { t } = ctx;
  const all = await api.getHistory();
  if (!isCurrent()) return;
  const records = all.slice(-range);

  const max = Math.max(0.01, ...records.map((r) => r.cost));
  const bars = records
    .map(
      (r) => `<div title="${r.date}: ${formatCost(r.cost)}"
        style="height:${Math.max(2, (r.cost / max) * 100)}%"></div>`
    )
    .join("");

  const rows = [...records].reverse().slice(0, 30)
    .map(
      (r: DayRecord) => `<div class="row"><span>${r.date}</span>
        <span class="muted">${formatTokens(r.tokens)} · ${formatCost(r.cost)}</span></div>`
    )
    .join("");

  el.innerHTML = `
    <div class="card">
      <div class="segment">
        ${[7, 30, 90].map((d) =>
          `<button data-range="${d}" class="${range === d ? "active" : ""}">
             ${t(`history.days${d}` as never)}</button>`).join("")}
      </div>
    </div>
    <div class="card">
      ${records.length === 0
        ? `<p class="muted">${t("history.empty")}</p>`
        : `<div class="bars">${bars}</div>`}
    </div>
    ${rows ? `<div class="card">${rows}</div>` : ""}
    <button class="ghost" id="export">${t("history.export")}</button>
    <p id="export-status" class="success"></p>
  `;

  el.querySelectorAll<HTMLButtonElement>("[data-range]").forEach((b) => {
    b.onclick = () => { range = Number(b.dataset.range) as 7 | 30 | 90; ctx.rerender(); };
  });
  (el.querySelector("#export") as HTMLButtonElement).onclick = async () => {
    const path = await api.exportHistoryCsv();
    if (path) {
      (el.querySelector("#export-status") as HTMLElement).textContent =
        `${t("history.exported")} ${path}`;
    }
  };
}
