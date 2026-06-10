export type Lang = "ru" | "en";

const STRINGS = {
  "tab.dashboard": ["Дашборд", "Dashboard"],
  "tab.history": ["История", "History"],
  "tab.account": ["Аккаунт", "Account"],
  "tab.settings": ["Настройки", "Settings"],
  "limit.fiveHour": ["5-часовой лимит", "5-hour limit"],
  "limit.weekly": ["Недельный лимит", "Weekly limit"],
  "limit.resets": ["сброс через", "resets in"],
  "limit.noData": ["Подключите аккаунт, чтобы видеть лимиты", "Connect an account to see limits"],
  "today.cost": ["Стоимость сегодня", "Cost today"],
  "today.tokens": ["Токены", "Tokens"],
  "today.sessions": ["Сессии", "Sessions"],
  "today.cache": ["Кэш-хиты", "Cache hits"],
  "today.activity": ["Активность по часам", "Hourly activity"],
  "today.topProjects": ["Топ проектов", "Top projects"],
  "today.empty": [
    "Нет данных за сегодня. Запустите Claude Code — цифры появятся автоматически.",
    "No data today. Run Claude Code — numbers will appear automatically.",
  ],
  "history.export": ["Экспорт CSV", "Export CSV"],
  "history.exported": ["Сохранено:", "Saved:"],
  "history.days7": ["7 дней", "7 days"],
  "history.days30": ["30 дней", "30 days"],
  "history.days90": ["90 дней", "90 days"],
  "history.empty": ["История пока пуста", "No history yet"],
  "account.add": ["Добавить аккаунт", "Add account"],
  "account.sessionKey": ["Вставьте sessionKey с claude.ai", "Paste sessionKey from claude.ai"],
  "account.autologin": ["Войти через Claude Code", "Sign in via Claude Code"],
  "account.autologinNone": ["Claude Code не найден на этом ПК", "Claude Code not found on this PC"],
  "account.remove": ["Удалить", "Remove"],
  "account.active": ["Активный", "Active"],
  "account.invalid": ["Токен недействителен — обновите sessionKey", "Token invalid — update sessionKey"],
  "account.howTo": [
    "claude.ai → F12 → Application → Cookies → sessionKey",
    "claude.ai → F12 → Application → Cookies → sessionKey",
  ],
  "account.error": ["Не удалось войти. Проверьте ключ.", "Sign-in failed. Check the key."],
  "account.max": ["Достигнут максимум — 5 аккаунтов", "Maximum of 5 accounts reached"],
  "settings.theme": ["Тема", "Theme"],
  "settings.theme.dark": ["Тёмная", "Dark"],
  "settings.theme.light": ["Светлая", "Light"],
  "settings.theme.system": ["Системная", "System"],
  "settings.language": ["Язык", "Language"],
  "settings.language.auto": ["Авто", "Auto"],
  "settings.notifications": ["Уведомления", "Notifications"],
  "settings.threshold": ["Порог лимита", "Limit threshold"],
  "settings.budgetDaily": ["Дневной бюджет, $", "Daily budget, $"],
  "settings.budgetMonthly": ["Месячный бюджет, $", "Monthly budget, $"],
  "settings.autostart": ["Запускать при входе в Windows", "Launch at Windows sign-in"],
  "settings.updates": ["Проверить обновления", "Check for updates"],
  "settings.upToDate": ["У вас последняя версия", "You're up to date"],
  "settings.updating": ["Скачиваю обновление…", "Downloading update…"],
  "settings.updateFound": ["Доступна версия", "Update available:"],
  "onb.title": ["Добро пожаловать в TokenTracker", "Welcome to TokenTracker"],
  "onb.body": [
    "Приложение читает локальные данные Claude Code и показывает ваши лимиты, стоимость и историю. Без облака и телеметрии. Приложение будет запускаться при входе в систему — это можно выключить в настройках.",
    "The app reads local Claude Code data and shows your limits, costs, and history. No cloud, no telemetry. The app will launch at sign-in — you can turn this off in Settings.",
  ],
  "onb.start": ["Начать", "Get started"],
  "common.updatedAgo": ["обновлено", "updated"],
  "common.stale": ["данные могли устареть", "data may be stale"],
} as const;

export type L10nKey = keyof typeof STRINGS;

export function resolveLang(setting: string | null, sysLocale: string): Lang {
  if (setting === "ru" || setting === "en") return setting;
  const s = sysLocale.toLowerCase();
  return s.startsWith("ru") || s.startsWith("uk") || s.startsWith("be") ? "ru" : "en";
}

export function makeT(lang: Lang) {
  return (key: L10nKey): string => {
    const pair = STRINGS[key] as readonly [string, string] | undefined;
    if (!pair) return key;
    return lang === "ru" ? pair[0] : pair[1];
  };
}
