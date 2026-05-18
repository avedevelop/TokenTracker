# FAQ — TokenTracker

---

## Почему данные не обновляются? / Why is the data not updating?

**RU:** TokenTracker читает файлы Claude Code из `~/.claude/projects/`. Убедитесь, что:
- Вы использовали Claude Code CLI сегодня
- Папка `~/.claude/projects/` существует
- Если вы переместили папку — укажите новый путь в **Настройки → Папка проектов**

**EN:** TokenTracker reads Claude Code files from `~/.claude/projects/`. Make sure:
- You have used Claude Code CLI today
- The folder `~/.claude/projects/` exists
- If you moved the folder — update it in **Settings → Projects folder**

---

## Как получить session token? / How do I get my session token?

**RU:**
1. Откройте [claude.ai](https://claude.ai) в браузере
2. Нажмите `Cmd+Option+I` → вкладка **Application**
3. **Cookies** → **claude.ai** → найдите `sessionKey` → скопируйте значение
4. Вставьте в поле на экране входа (Cmd+V)

**EN:**
1. Open [claude.ai](https://claude.ai) in your browser
2. Press `Cmd+Option+I` → **Application** tab
3. **Cookies** → **claude.ai** → find `sessionKey` → copy the value
4. Paste it into the login screen (Cmd+V)

---

## Как найти Org ID? / How do I find my Org ID?

**RU:**
1. Откройте [claude.ai](https://claude.ai) → `Cmd+Option+I`
2. **Application** → **Cookies** → **claude.ai**
3. Найдите `lastActiveOrg` → скопируйте значение

**EN:**
1. Open [claude.ai](https://claude.ai) → `Cmd+Option+I`
2. **Application** → **Cookies** → **claude.ai**
3. Find `lastActiveOrg` → copy the value

---

## Что такое 5-часовой лимит? / What is the 5-hour limit?

**RU:** Claude Pro и Max имеют скользящий лимит за последние 5 часов. При достижении лимита новые запросы временно блокируются. TokenTracker показывает текущее использование и время сброса.

**EN:** Claude Pro and Max plans have a rolling usage limit over the last 5 hours. When reached, new requests are temporarily blocked. TokenTracker shows your current utilization and reset time.

---

## Лимиты перестали обновляться / Limits stopped updating

**RU:** Вероятно, истёк session token (живёт ~30 дней). Зайдите в **Аккаунт** → **Выйти** → войдите снова со свежим токеном.

**EN:** Your session token may have expired (browser tokens last ~30 days). Go to **Account** → **Sign out** → log in again with a fresh token.

---

## Мои данные куда-то отправляются? / Is my data sent anywhere?

**RU:** Нет. Всё работает локально. Единственные сетевые запросы идут на `api2.claude.ai` — чтобы получить ваши собственные лимиты, с вашими учётными данными.

**EN:** No. Everything runs locally. The only outbound requests go to `api2.claude.ai` to fetch your own rate limits using your credentials.

---

## Как поменять папку проектов? / How do I change the projects folder?

**RU:** **Настройки** → **Папка проектов** → **Выбрать папку…**

**EN:** **Settings** → **Projects folder** → **Choose folder…**

---

## Можно без аккаунта claude.ai? / Can I use it without a claude.ai account?

**RU:** Частично. Токены, стоимость и сессии из файлов Claude Code работают без входа. Лимиты (5-часовой, недельный) требуют session token.

**EN:** Partially. Token/cost/session data from Claude Code files works without login. Rate limits (5-hour, weekly) require a session token.

---

## Как добавить несколько аккаунтов? / How do I add multiple accounts?

**RU:** Вкладка **Аккаунт** → кнопка **Добавить аккаунт** (максимум 5). Каждый аккаунт хранит токен и Org ID отдельно. Переключение мгновенно обновляет лимиты.

**EN:** **Account** tab → **Add account** button (up to 5 accounts). Each account stores its token and Org ID independently. Switching immediately refreshes limits.

---

## Виджет показывает не тот аккаунт / Widget shows the wrong account

**RU:** Зайдите в **Настройки → Виджет** и выберите нужный аккаунт. По умолчанию виджет следует активному аккаунту в приложении.

**EN:** Go to **Settings → Widget** and select the account. By default the widget follows the app's active account.

---

## Лимиты не отображаются / Limits don't show

**RU:** Проверьте что у аккаунта задан **Org ID** (вкладка Аккаунт → Добавить / Изменить). Бесплатный аккаунт — лимиты недоступны, показываются только токены и стоимость.

**EN:** Check that the account has an **Org ID** set (Account tab → Add / Edit). Free accounts don't have a usage endpoint — only token and cost data is shown.

---

## Как добавить виджет? / How do I add the widget?

**RU:** Правая кнопка на рабочем столе → **Изменить виджеты** → найдите **TokenTracker** → выберите размер.

**EN:** Right-click your desktop → **Edit Widgets** → search **TokenTracker** → choose a size.

---

## Будут ли обновления? / Will there be updates?

**RU:** Да. Проект активно развивается. Следите за [Releases](../../releases).

**EN:** Yes. The project is actively maintained. Watch [Releases](../../releases) for updates.

---

## Как был создан этот проект? / How was this project built?

**RU:** TokenTracker был полностью написан с помощью **Claude Sonnet 4.6** примерно за **12 часов** — от идеи до опен-сорс релиза.

**EN:** TokenTracker was built entirely with **Claude Sonnet 4.6** in approximately **12 hours** — from idea to open-source release.
