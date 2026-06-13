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
| `assets/demo.png` | Real notification screenshot shown in the README. |

## Non-obvious implementation facts (don't relearn the hard way)

- **Notification icon**: macOS forces a notification to show the *sending app's*
  bundle icon. `terminal-notifier -appIcon` does NOT work on recent macOS. The
  fix is to overwrite `terminal-notifier.app/Contents/Resources/Terminal.icns`
  with the Claude logo (built via `sips`+`iconutil`). `brew upgrade
  terminal-notifier` restores the stock icon → must re-run the installer.
- **Usage gauge data**: undocumented endpoint
  `https://api.anthropic.com/api/oauth/usage`, authed with the OAuth token from
  the macOS Keychain item `Claude Code-credentials` (key
  `claudeAiOauth.accessToken`). Returns `{utilization, resets_at}` for both
  `five_hour` and `seven_day`; remaining = `100 - utilization`, and the gauge
  shows a `⏳` countdown to `resets_at` (session h+m, week d+h). If it 401s or the
  schema changes, `usage.py` prints nothing and the chime degrades to plain text.
  Same data `/usage` shows; it's the user's own token, read-only.
- **Usage cache (429 guard)**: the endpoint rate-limits *hard* (a burst of
  requests trips a multi-minute cooldown), and chimes are event-driven (every
  `Stop`/`Notification`), so `usage.py` polls it like a background gauge would.
  Two-tier cache at `$TMPDIR/claude-chime-usage.json`: if it's younger than
  `FRESH_TTL` (60s) it's reused **without any fetch** (so a burst of chimes is
  one request, not N); only an older cache triggers a fetch, and a failed fetch
  falls back to a cache up to `STALE_TTL` (300s) old, marked with a leading `~`.
  The `⏳` countdown is recomputed live from `resets_at`, so only the % is stale.
  Note: a 429 here is usually self-inflicted (heavy testing) — it clears on its
  own after a few idle minutes; the token/code are fine. (CodexBar is OpenAI's,
  a separate service/token — not a competitor for this Claude endpoint.)
- **Hooks**: wired on Claude Code's `Stop` (done, Glass sound) and `Notification`
  (waiting, Submarine sound) events. They coexist with the user's existing
  `claude-island-state.py` hooks — never clobber those.
- **Idempotency**: installer detects existing hooks by matching `chime.sh` in the
  command string before adding.

## Conventions

- Shell scripts: `set -euo pipefail` (chime.sh uses `-uo` only, must never fail a
  hook), fail-silent on anything user-facing, prefer absolute tool paths.
- Keep it dependency-light: macOS built-ins + Homebrew terminal-notifier + system
  `python3`. No pip deps.
- After changing scripts, remember the **running copy** is `~/.claude-chime`;
  reinstall (`curl … | bash` or copy files over) to dogfood changes.

## Common tasks

- Update the README demo: take a real notification screenshot, save as `assets/demo.png`.
- Test a chime locally: `CLAUDE_CHIME_LANG=zh bash chime.sh stop`
- Push: `git push origin main` (gh credential helper is configured).
- **Cut a release** (versioning is `VERSION` + tags + `CHANGELOG.md`; `VERSION`
  is the single source of truth, read by `chime.sh --version`, and the installer
  downloads it into the runtime). Steps:
  1. Bump `VERSION` (semver) and add a dated section to `CHANGELOG.md`.
  2. Commit, then `git tag -a vX.Y.Z -m '…'` and `git push origin main --tags`.
  3. `gh release create vX.Y.Z --title … --notes …` (notes from the changelog).
  - Users upgrade by **re-running the install one-liner** — it's idempotent and
    re-pulls the latest runtime; there is no auto-update check (yet).
