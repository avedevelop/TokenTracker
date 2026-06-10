import { api, type AccountProfile } from "../api";
import type { Ctx } from "../main";

function initials(p: AccountProfile): string {
  const src = p.fullName ?? p.email ?? p.name;
  const parts = src.split(" ").filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return src.slice(0, 2).toUpperCase();
}

export async function renderAccount(el: HTMLElement, ctx: Ctx) {
  const { t } = ctx;
  const view = await api.getAccounts();

  const rows = view.profiles
    .map((p) => {
      const active = p.id === view.activeId;
      return `<div class="row" data-id="${p.id}">
        <div style="display:flex;gap:8px;align-items:center">
          <div class="avatar">${initials(p)}</div>
          <div>
            <div>${p.fullName ?? p.email ?? p.name}</div>
            <div class="muted">${active ? t("account.active") : ""}
              ${p.tokenValid ? "" : `<span class="error">${t("account.invalid")}</span>`}</div>
          </div>
        </div>
        <button class="ghost" style="width:auto" data-remove="${p.id}">✕</button>
      </div>`;
    })
    .join("");

  const canAdd = view.profiles.length < view.maxAccounts;

  el.innerHTML = `
    ${rows ? `<div class="card">${rows}</div>` : ""}
    <div class="card">
      <h3>${t("account.add")}</h3>
      ${canAdd ? `
        <div class="field">
          <input type="password" id="session-key" placeholder="sessionKey" />
          <p class="muted" style="margin-top:4px">${t("account.howTo")}</p>
        </div>
        <button class="primary" id="add">${t("account.add")}</button>
        <button class="ghost" id="autologin" style="margin-top:8px">${t("account.autologin")}</button>
        <p id="acc-error" class="error"></p>
      ` : `<p class="muted">${t("account.max")}</p>`}
    </div>
  `;

  el.querySelectorAll<HTMLElement>(".row[data-id]").forEach((row) => {
    row.onclick = async (e) => {
      if ((e.target as HTMLElement).dataset.remove) return;
      await api.setActiveAccount(row.dataset.id!);
      ctx.rerender();
    };
  });
  el.querySelectorAll<HTMLButtonElement>("[data-remove]").forEach((b) => {
    b.onclick = async (e) => {
      e.stopPropagation();
      await api.removeAccount(b.dataset.remove!);
      ctx.rerender();
    };
  });

  const errEl = () => el.querySelector("#acc-error") as HTMLElement;
  const addBtn = el.querySelector("#add") as HTMLButtonElement | null;
  if (addBtn) {
    addBtn.onclick = async () => {
      const key = (el.querySelector("#session-key") as HTMLInputElement).value;
      try {
        await api.addAccount(key);
        ctx.rerender();
      } catch {
        errEl().textContent = t("account.error");
      }
    };
  }
  const autoBtn = el.querySelector("#autologin") as HTMLButtonElement | null;
  if (autoBtn) {
    autoBtn.onclick = async () => {
      try {
        const p = await api.claudeCodeAutologin();
        if (!p) errEl().textContent = t("account.autologinNone");
        else ctx.rerender();
      } catch {
        errEl().textContent = t("account.error");
      }
    };
  }
}
