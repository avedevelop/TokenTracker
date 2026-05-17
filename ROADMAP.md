# Roadmap

> Ideas and planned improvements for TokenTracker. No dates — shipped when ready.  
> Идеи и планируемые улучшения. Без дат — выйдет когда будет готово.

---

## Recently shipped / Недавно выпущено

- ✅ **Per-project breakdown / Разбивка по проектам** — top-5 projects by tokens and cost on the dashboard  
  Топ-5 проектов по токенам и стоимости на дашборде *(v1.1.0)*
- ✅ **Check for updates / Проверка обновлений** — button in About + banner on launch when a new version is available  
  Кнопка в разделе «О приложении» + баннер при запуске если вышла новая версия *(v1.1.0)*
- ✅ **Localhost-only widget server / Сервер виджета только на localhost** — widget data server now rejects non-localhost connections  
  Сервер данных виджета теперь отклоняет внешние подключения *(v1.1.0)*
- ✅ **Window close crash fix / Исправление краша при закрытии** — window hides instead of deallocating, fixes crash on macOS 26 Tahoe  
  Окно скрывается вместо деалокации, исправлен краш на macOS 26 Tahoe *(v1.0.1)*
- ✅ **Session token security / Безопасность токена сессии** — credentials stored in Keychain only, removed plaintext UserDefaults backup  
  Токен хранится только в Keychain, убрана незашифрованная копия в UserDefaults *(v1.0.2)*

---

## Next / Следующее

- **Monthly budget / Месячный бюджет** — monthly spending limit with progress bar and alerts at 80% / 100%  
  Месячный лимит расходов с прогресс-баром и уведомлениями при 80% / 100%

- **Rate limit history / История лимитов** — chart showing 5-hour utilization over past days, not just token cost  
  График использования 5-часового лимита по дням, а не только стоимость токенов

- **Multiple accounts / Несколько аккаунтов** — switch between personal and work Claude accounts without re-entering credentials  
  Переключение между личным и рабочим аккаунтом без повторного ввода токена

- **Light / system theme / Светлая тема** — option to follow macOS appearance instead of always dark  
  Опция следовать системной теме macOS вместо постоянно тёмной

---

## Longer-term / Долгосрочное

- **Anthropic API support** — track usage from direct API calls (via API key), not only Claude Code CLI  
  Трекинг запросов напрямую через Anthropic API (по API key), а не только через Claude Code CLI

- **Period comparison / Сравнение периодов** — "this week vs last week", "this month vs last month" with deltas  
  «Эта неделя vs прошлая», «этот месяц vs прошлый» с дельтами

- **Full menu bar mode / Режим строки меню** — compact mini-dashboard in the menu bar only, no main window needed  
  Компактный мини-дашборд только в строке меню без основного окна

- **iOS companion widget / Виджет для iOS** — iPhone / iPad widget showing the same data via iCloud sync  
  Виджет на iPhone / iPad с теми же данными через iCloud синхронизацию

---

## Ideas / Идеи

- **Weekly digest / Еженедельный отчёт** — short summary of heaviest usage days, peak hours, most expensive project  
  Краткая сводка: самые нагруженные дни, пиковые часы, самый дорогой проект

- **Team dashboards / Командные дашборды** — opt-in aggregated stats across a team using Claude Code  
  Агрегированная статистика команды по желанию каждого участника

- **Linear / Jira integration** — link Claude Code sessions to tickets by branch or project folder name  
  Привязка сессий Claude Code к тикетам по имени ветки или папки проекта

---

## Contributing

Have a feature idea? Open an [issue](../../issues/new?template=feature_request.md) — all feedback is welcome.  
Есть идея? Открывай [issue](../../issues/new?template=feature_request.md) — всё приветствуется.
