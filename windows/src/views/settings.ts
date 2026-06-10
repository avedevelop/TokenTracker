import { disable, enable } from "@tauri-apps/plugin-autostart";
import { relaunch } from "@tauri-apps/plugin-process";
import { check } from "@tauri-apps/plugin-updater";
import type { Ctx } from "../main";

export function renderSettings(el: HTMLElement, ctx: Ctx) {
  const { t, settings } = ctx;

  el.innerHTML = `
    <div class="card">
      <div class="field"><label>${t("settings.theme")}</label>
        <select id="theme">
          <option value="dark">${t("settings.theme.dark")}</option>
          <option value="light">${t("settings.theme.light")}</option>
          <option value="system">${t("settings.theme.system")}</option>
        </select>
      </div>
      <div class="field"><label>${t("settings.language")}</label>
        <select id="language">
          <option value="">${t("settings.language.auto")}</option>
          <option value="ru">Русский</option>
          <option value="en">English</option>
        </select>
      </div>
    </div>
    <div class="card">
      <h3>${t("settings.notifications")}</h3>
      <div class="row"><span>${t("settings.notifications")}</span>
        <input type="checkbox" id="notif" ${settings.notifEnabled ? "checked" : ""}></div>
      <div class="field"><label>${t("settings.threshold")}:
          <span id="thr-val">${Math.round(settings.notifThreshold * 100)}%</span></label>
        <input type="range" id="threshold" min="50" max="95" step="5"
          value="${Math.round(settings.notifThreshold * 100)}">
      </div>
      <div class="field"><label>${t("settings.budgetDaily")}</label>
        <input type="number" id="budget-daily" min="0" step="0.5" value="${settings.budgetDaily}"></div>
      <div class="field"><label>${t("settings.budgetMonthly")}</label>
        <input type="number" id="budget-monthly" min="0" step="1" value="${settings.budgetMonthly}"></div>
    </div>
    <div class="card">
      <div class="row"><span>${t("settings.autostart")}</span>
        <input type="checkbox" id="autostart" ${settings.autostart ? "checked" : ""}></div>
    </div>
    <button class="ghost" id="check-updates">${t("settings.updates")}</button>
    <p id="update-status" class="muted" style="text-align:center;margin-top:6px"></p>
  `;

  (el.querySelector("#theme") as HTMLSelectElement).value = settings.theme;
  (el.querySelector("#language") as HTMLSelectElement).value = settings.language ?? "";

  const save = () => {
    const s = { ...ctx.settings };
    s.theme = (el.querySelector("#theme") as HTMLSelectElement).value as typeof s.theme;
    const langSel = (el.querySelector("#language") as HTMLSelectElement).value;
    s.language = langSel === "" ? null : (langSel as "ru" | "en");
    s.notifEnabled = (el.querySelector("#notif") as HTMLInputElement).checked;
    s.notifThreshold = Number((el.querySelector("#threshold") as HTMLInputElement).value) / 100;
    s.budgetDaily = Number((el.querySelector("#budget-daily") as HTMLInputElement).value) || 0;
    s.budgetMonthly = Number((el.querySelector("#budget-monthly") as HTMLInputElement).value) || 0;
    s.autostart = (el.querySelector("#autostart") as HTMLInputElement).checked;
    return ctx.saveSettings(s);
  };

  el.querySelectorAll("select, input").forEach((node) => {
    (node as HTMLElement).onchange = async () => {
      const wantAutostart = (el.querySelector("#autostart") as HTMLInputElement).checked;
      if (wantAutostart !== ctx.settings.autostart) {
        try { wantAutostart ? await enable() : await disable(); } catch { /* show old value */ }
      }
      await save();
    };
  });
  (el.querySelector("#threshold") as HTMLInputElement).oninput = (e) => {
    (el.querySelector("#thr-val") as HTMLElement).textContent =
      `${(e.target as HTMLInputElement).value}%`;
  };

  (el.querySelector("#check-updates") as HTMLButtonElement).onclick = () =>
    runUpdateCheck(el, ctx);
}

export async function runUpdateCheck(el: HTMLElement, ctx: Ctx) {
  const status = el.querySelector("#update-status") as HTMLElement | null;
  const set = (msg: string) => { if (status) status.textContent = msg; };
  try {
    const update = await check();
    if (!update) { set(ctx.t("settings.upToDate")); return; }
    set(`${ctx.t("settings.updateFound")} ${update.version}`);
    set(ctx.t("settings.updating"));
    await update.downloadAndInstall();
    await relaunch();
  } catch {
    set(ctx.t("settings.upToDate"));
  }
}

