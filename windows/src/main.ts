import { api, type Settings, type UsageData } from "./api";
import { makeT, resolveLang, type Lang } from "./l10n";
import { renderDashboard } from "./views/dashboard";
import { renderHistory } from "./views/history";
import { renderAccount } from "./views/account";
import { renderSettings, runUpdateCheck } from "./views/settings";
import { renderOnboarding } from "./views/onboarding";

export interface Ctx {
  t: ReturnType<typeof makeT>;
  lang: Lang;
  settings: Settings;
  usage: UsageData;
  rerender: () => void;
  saveSettings: (s: Settings) => Promise<void>;
}

type Tab = "dashboard" | "history" | "account" | "settings";
let tab: Tab = "dashboard";
let ctx: Ctx;
let renderSeq = 0;

function applyTheme(s: Settings) {
  const sys = matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  document.documentElement.dataset.theme = s.theme === "system" ? sys : s.theme;
}

function renderTabbar() {
  const bar = document.getElementById("tabbar")!;
  const tabs: Tab[] = ["dashboard", "history", "account", "settings"];
  bar.innerHTML = "";
  for (const name of tabs) {
    const b = document.createElement("button");
    b.textContent = ctx.t(`tab.${name}` as never);
    b.className = name === tab ? "active" : "";
    b.onclick = () => { tab = name; render(); };
    bar.appendChild(b);
  }
}

function render() {
  const seq = ++renderSeq;
  const view = document.getElementById("view")!;
  if (!ctx.settings.onboardingDone) {
    document.getElementById("tabbar")!.innerHTML = "";
    renderOnboarding(view, ctx);
    return;
  }
  renderTabbar();
  view.innerHTML = "";
  if (tab === "dashboard") renderDashboard(view, ctx);
  else if (tab === "history") void renderHistory(view, ctx, () => seq === renderSeq);
  else if (tab === "account") void renderAccount(view, ctx, () => seq === renderSeq);
  else renderSettings(view, ctx);
}

async function boot() {
  const settings = await api.getSettings();
  const usage = await api.getUsage();
  const lang = resolveLang(settings.language, navigator.language);
  ctx = {
    t: makeT(lang),
    lang,
    settings,
    usage,
    rerender: render,
    saveSettings: async (s) => {
      ctx.settings = s;
      await api.setSettings(s);
      ctx.lang = resolveLang(s.language, navigator.language);
      ctx.t = makeT(ctx.lang);
      applyTheme(s);
      render();
    },
  };
  applyTheme(settings);

  await api.onUsageUpdated((u) => {
    ctx.usage = u;
    if (tab === "dashboard") render();
  });
  await api.onAccountsUpdated(() => { if (tab === "account") render(); });
  await api.onCheckUpdatesRequested(() => {
    tab = "settings";
    render();
    void runUpdateCheck(document.getElementById("view")!, ctx);
  });

  render();
}

boot();
