import { api } from "../api";
import type { Ctx } from "../main";

export function renderOnboarding(el: HTMLElement, ctx: Ctx) {
  const { t } = ctx;
  el.innerHTML = `
    <div class="onboarding">
      <h1>${t("onb.title")}</h1>
      <p>${t("onb.body")}</p>
      <button class="primary" id="start">${t("onb.start")}</button>
      <button class="ghost" id="onb-autologin" style="margin-top:8px">${t("account.autologin")}</button>
      <p id="onb-note" class="muted" style="margin-top:10px">${t("account.howTo")}</p>
    </div>
  `;

  const finish = async () => {
    await ctx.saveSettings({ ...ctx.settings, onboardingDone: true, autostart: true });
    try {
      const { enable } = await import("@tauri-apps/plugin-autostart");
      await enable();
    } catch { /* non-fatal */ }
  };

  (el.querySelector("#start") as HTMLButtonElement).onclick = finish;
  (el.querySelector("#onb-autologin") as HTMLButtonElement).onclick = async () => {
    try { await api.claudeCodeAutologin(); } catch { /* still finish */ }
    await finish();
  };
}
