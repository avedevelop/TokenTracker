# FAQ — TokenTracker

---

## Почему данные не обновляются? / Why is data not updating?

**RU:** TokenTracker читает файлы Claude Code из `~/.claude/projects`. Убедитесь, что вы используете Claude Code в CLI и папка существует.

**EN:** TokenTracker reads Claude Code files from `~/.claude/projects`. Make sure you use Claude Code in the CLI and the folder exists.

---

## Как получить session token? / How do I get a session token?

**RU:**
1. Откройте [claude.ai](https://claude.ai) в браузере
2. Нажмите `Cmd+Option+I` → вкладка **Application**
3. **Cookies** → **claude.ai** → найдите `sessionKey` → скопируйте значение

**EN:**
1. Open [claude.ai](https://claude.ai) in your browser
2. Press `Cmd+Option+I` → **Application** tab
3. **Cookies** → **claude.ai** → find `sessionKey` → copy the value

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

**RU:** Claude Pro и Max имеют скользящий лимит использования за последние 5 часов. При достижении лимита новые запросы временно блокируются до сброса.

**EN:** Claude Pro and Max have a rolling usage limit over the last 5 hours. When reached, new requests are temporarily blocked until it resets.

---

## Данные отправляются на сервер? / Is my data sent to a server?

**RU:** Нет. TokenTracker работает полностью локально. Данные читаются с локального диска, лимиты запрашиваются напрямую у Claude API с вашим токеном.

**EN:** No. TokenTracker works entirely locally. Data is read from your local disk; limits are fetched directly from the Claude API using your token.

---

## Как поменять папку с проектами? / How do I change the projects folder?

**RU:** Настройки → вкладка **Настройки** → **Папка проектов** → **Выбрать папку…**

**EN:** Settings → **Settings** tab → **Projects folder** → **Choose folder…**
