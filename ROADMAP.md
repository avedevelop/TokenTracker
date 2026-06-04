# Roadmap

> Ideas and planned improvements for TokenTracker. No dates — shipped when ready.  
> Идеи и планируемые улучшения. Без дат — выйдет когда будет готово.

---

## Recently shipped / Недавно выпущено

- ✅ **Sparkle auto-updates / Авто-обновления** — native update dialog with EdDSA verification; no Apple Developer account required *(v1.3.0)*
- ✅ **Smart dashboard / Умный дашборд** — status, limit intelligence, and project insight cards. Карточки статуса, лимитов и проектных инсайтов *(v1.4.0)*
- ✅ **Insights / Инсайты** — 7 / 30 / 90-day analytics, comparison deltas, charts, daily records, and CSV export. Аналитика за 7 / 30 / 90 дней, сравнения, графики, дневные записи и CSV *(v1.4.0)*
- ✅ **Menu bar mini dashboard / Мини-дашборд в строке меню** — compact status popover with quick actions. Компактный поповер со статусом и быстрыми действиями *(v1.4.0)*
- ✅ **Widget health / Состояние виджета** — widget freshness, selected account, and macOS troubleshooting in Settings. Свежесть данных, выбранный аккаунт и подсказки macOS в настройках *(v1.4.0)*
- ✅ **Homebrew tap / Homebrew** — `brew tap avedevelop/tap && brew install --cask tokentracker` *(v1.3.0)*
- ✅ **Multiple accounts / Несколько аккаунтов** — up to 5 accounts with independent tokens and Org IDs; quick switching clears and reloads limits  
  До 5 аккаунтов с независимыми токенами и Org ID; переключение сразу обновляет лимиты *(v1.2.0)*
- ✅ **Widget account selection / Выбор аккаунта для виджета** — choose which account the widget displays in Settings → Widget  
  Настройки → Виджет позволяют выбрать какой аккаунт отображает виджет *(v1.2.0)*
- ✅ **Free account support / Поддержка бесплатного аккаунта** — login succeeds even when the usage endpoint is unavailable  
  Вход работает даже если эндпоинт лимитов недоступен *(v1.2.0)*
- ✅ **Monthly budget / Месячный бюджет** — monthly spending limit with progress bar and alerts  
  Месячный лимит расходов с прогресс-баром и уведомлениями *(v1.2.0)*
- ✅ **Per-project breakdown / Разбивка по проектам** — top-5 projects by tokens and cost on the dashboard  
  Топ-5 проектов по токенам и стоимости на дашборде *(v1.1.0)*
- ✅ **Check for updates / Проверка обновлений** — button in About + banner on launch  
  Кнопка в «О приложении» + баннер при запуске *(v1.1.0)*
- ✅ **Session token security / Безопасность токена** — Keychain only, no plaintext backup  
  Только Keychain, без незашифрованной копии *(v1.0.2)*

---

## Next / Следующее

- **Polish pass / Полировка** — update screenshots, tighten empty states, and smooth compact layouts after real-world testing. Обновить скриншоты, улучшить пустые состояния и компактные экраны после тестирования

- **Test host cleanup / Чистка тестового раннера** — make unit tests run without launching the full app host. Сделать так, чтобы unit-тесты запускались без полноценного app host

---

## Longer-term / Долгосрочное

- **Menu bar-only mode / Режим только строки меню** — optional Dockless mode for people who live from the popover. Опциональный режим без Dock для тех, кому хватает поповера

- **Smarter notifications / Умные уведомления** — fewer noisy alerts, better reset timing, budget context, and per-account hints. Меньше шума, точнее время сброса, контекст бюджета и подсказки по аккаунтам

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
