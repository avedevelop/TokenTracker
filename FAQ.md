# FAQ — TokenTracker

---

### Why is the usage data showing zeros?

TokenTracker reads Claude Code session files from `~/.claude/projects/`. Make sure:
- You have used Claude Code CLI at least once today
- The folder `~/.claude/projects/` exists on your Mac
- If you moved your projects folder, update it in **Settings → Projects folder**

---

### How do I get my session token?

**RU:**
1. Откройте [claude.ai](https://claude.ai) в браузере
2. Нажмите `Cmd+Option+I` → вкладка **Application**
3. **Cookies** → **claude.ai** → найдите `sessionKey` → скопируйте значение

**EN:**
1. Open [claude.ai](https://claude.ai) in your browser
2. Press `Cmd+Option+I` → **Application** tab
3. **Cookies** → **claude.ai** → find `sessionKey` → copy the value

---

### How do I find my Org ID?

**RU:**
1. Откройте [claude.ai](https://claude.ai) → `Cmd+Option+I`
2. **Application** → **Cookies** → **claude.ai**
3. Найдите `lastActiveOrg` → скопируйте значение

**EN:**
1. Open [claude.ai](https://claude.ai) → `Cmd+Option+I`
2. **Application** → **Cookies** → **claude.ai**
3. Find `lastActiveOrg` → copy the value

---

### What is the 5-hour limit?

Claude Pro and Max plans have a rolling usage limit over the last 5 hours. When you reach it, new requests are temporarily blocked until the window resets. TokenTracker shows your current utilization and when the limit resets.

---

### My limits show "N/A" or stopped updating

Your session token may have expired. Browser session tokens typically last 30 days. To fix it: go to **Account** tab → **Sign out** → log in again with a fresh token.

---

### Is my data sent anywhere?

No. TokenTracker works entirely locally. The only outbound requests go to `api2.claude.ai` to fetch your own rate limit data — using your credentials, on your behalf.

---

### How do I change the projects folder?

**Settings** tab → **Projects folder** → **Choose folder…** → select your `~/.claude/projects` directory (or a custom path if you've moved it).

---

### Can I use this without a Claude.ai account?

Partially. Token/cost/session data from Claude Code files works without login. Rate limits (5-hour, weekly) require a valid session token from claude.ai.

---

### How do I add the widget?

Right-click your desktop → **Edit Widgets** → search **TokenTracker** → choose a size (small, medium, or large).

---

### The app isn't in the Dock

Open **Settings** tab — if "Menu bar icon" is the only visible toggle, the app may be set to menu bar mode. The app always appears in the Dock by default. If you closed the window, click the icon in the menu bar or reopen from `/Applications`.
