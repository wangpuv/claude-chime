# Claude Chime 🔔

A friendly desktop chime for [Claude Code](https://claude.com/claude-code) on macOS.
When Claude finishes a task or needs your input, you get a native notification with:

- 🟠 **the real Claude icon** (not the generic script/terminal icon)
- 🔊 **a pleasant sound** (different for "done" vs. "waiting")
- 📊 **a live usage gauge** — how much of your **session** and **weekly** limits is left
- 🌐 **English + 中文**, auto-detected from your system language

<p align="center">
  <img src="assets/demo.gif" alt="Claude Chime notification — task done and waiting-for-you states, English and 中文" width="540">
</p>

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/wangpuv/claude-chime/main/install.sh | bash
```

That's it. New Claude Code sessions will chime. The installer:

1. installs [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) via Homebrew (if missing),
2. drops the runtime into `~/.claude-chime`,
3. gives `terminal-notifier` the Claude icon,
4. adds two hooks to `~/.claude/settings.json` (`Stop` and `Notification`).

> **Requirements:** macOS + [Homebrew](https://brew.sh). Existing hooks are preserved; the installer is idempotent and safe to re-run.

## How the usage gauge works

The gauge shows your remaining limits, mirroring Claude Code's own `/usage`:

- **Session** = `100 − five_hour.utilization`
- **Week** = `100 − seven_day.utilization`

It reads your Claude Code OAuth token from the **macOS login Keychain**
(`Claude Code-credentials`) and queries the same endpoint `/usage` uses
(`https://api.anthropic.com/api/oauth/usage`).

- On first run, macOS may ask permission for the script to read that Keychain
  item — click **Always Allow**.
- This is **read-only** and uses **your own** token and account.
- The endpoint is **undocumented**; if Anthropic changes it, the gauge simply
  disappears and you still get the plain "done / waiting" chime. Nothing breaks.
- Don't want it? Set `CLAUDE_CHIME_NO_USAGE=1` (see below).

## Customize

The hooks call `chime.sh`. Tweak behavior with environment variables — either
edit the hook commands in `~/.claude/settings.json`, or export them globally.

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_CHIME_LANG` | `auto` | `zh`, `en`, or `auto` (from `$LANG`) |
| `CLAUDE_CHIME_SOUND_STOP` | `Glass` | Sound for "task done" |
| `CLAUDE_CHIME_SOUND_WAIT` | `Submarine` | Sound for "needs you" |
| `CLAUDE_CHIME_NO_USAGE` | `0` | Set `1` to hide the usage gauge |

Sound names are the files in `/System/Library/Sounds` (Glass, Submarine, Ping,
Hero, Funk, …).

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/wangpuv/claude-chime/main/uninstall.sh | bash
```

Removes the hooks, restores the stock `terminal-notifier` icon, and deletes
`~/.claude-chime`. `terminal-notifier` itself is left installed
(`brew uninstall terminal-notifier` to remove it).

## How it fits together

```
Claude Code  ──(Stop / Notification hook)──▶  chime.sh ──▶ usage.py ──▶ /usage API
                                                  │
                                                  ▼
                                          terminal-notifier  ──▶  macOS notification
                                          (wearing the Claude icon)
```

## Contributing

Issues and PRs welcome — this is meant to be improved together. Good first ideas:
Linux/`notify-send` support, more languages, a `/usage`-style reset countdown,
configurable messages.

## License

[Apache-2.0](LICENSE)

---

*Not affiliated with Anthropic. "Claude" and the Claude logo are trademarks of
Anthropic. The bundled icon is used to identify the Claude Code tool these
notifications come from.*
