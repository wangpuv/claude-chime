# Claude Chime — project guide for Claude Code

macOS desktop notifications for Claude Code: Claude icon + sound + a live
session/weekly usage gauge, in English and 中文. Open source, Apache-2.0.

- Repo: https://github.com/wangpuv/claude-chime (GitHub account `wangpuv`)
- This dir is the **dev repo**. The **runtime** lives at `~/.claude-chime`
  (what the installer drops; the user's own hooks call `~/.claude-chime/chime.sh`).
  Editing files here does NOT change the running setup until reinstalled.

## Files

| File | Role |
|---|---|
| `install.sh` | One-line installer: brew-installs terminal-notifier, downloads runtime to `~/.claude-chime`, swaps the icon, wires hooks. Idempotent. |
| `uninstall.sh` | Removes hooks, restores stock icon, deletes `~/.claude-chime`. |
| `chime.sh` | Notification logic. `chime.sh <stop|waiting>`; bilingual; sounds/lang via env. |
| `usage.py` | Reads OAuth token from Keychain, queries the usage endpoint, prints the gauge line. Fail-silent. |
| `assets/claude-logo.png` | Official Claude logo (source: VS Code ext `anthropic.claude-code-*/resources/claude-logo.png`). |
| `tools/make-demo.py` | Old HTML→Chrome→Pillow mockup generator. **No longer used** — `assets/demo.png` is now a real notification screenshot (the mockup styled the gauge orange, which the real macOS notification never shows). Don't run it against `demo.png`; it would overwrite the real screenshot. |

## Non-obvious implementation facts (don't relearn the hard way)

- **Notification icon**: macOS forces a notification to show the *sending app's*
  bundle icon. `terminal-notifier -appIcon` does NOT work on recent macOS. The
  fix is to overwrite `terminal-notifier.app/Contents/Resources/Terminal.icns`
  with the Claude logo (built via `sips`+`iconutil`). `brew upgrade
  terminal-notifier` restores the stock icon → must re-run the installer.
- **Usage gauge data**: undocumented endpoint
  `https://api.anthropic.com/api/oauth/usage`, authed with the OAuth token from
  the macOS Keychain item `Claude Code-credentials` (key
  `claudeAiOauth.accessToken`). Returns `five_hour.utilization` and
  `seven_day.utilization`; remaining = `100 - utilization`. If it 401s or the
  schema changes, `usage.py` prints nothing and the chime degrades to plain text.
  Same data `/usage` shows; it's the user's own token, read-only.
- **Hooks**: wired on Claude Code's `Stop` (done, Glass sound) and `Notification`
  (waiting, Submarine sound) events. They coexist with the user's existing
  `claude-island-state.py` hooks — never clobber those.
- **Idempotency**: installer detects existing hooks by matching `chime.sh` in the
  command string before adding.

## Conventions

- Shell scripts: `set -euo pipefail` (chime.sh uses `-uo` only, must never fail a
  hook), fail-silent on anything user-facing, prefer absolute tool paths.
- Keep it dependency-light: macOS built-ins + Homebrew terminal-notifier + system
  `python3`. No pip deps at runtime (Pillow is only for `tools/make-demo.py`).
- After changing scripts, remember the **running copy** is `~/.claude-chime`;
  reinstall (`curl … | bash` or copy files over) to dogfood changes.

## Common tasks

- Update the README demo: take a real notification screenshot, save as `assets/demo.png` (the old `tools/make-demo.py` mockup is retired).
- Test a chime locally: `CLAUDE_CHIME_LANG=zh bash chime.sh stop`
- Push: `git push origin main` (gh credential helper is configured).
