# Changelog

All notable changes to Claude Chime are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project aims to use
[Semantic Versioning](https://semver.org/).

To upgrade, re-run the install one-liner (it is idempotent and pulls the latest
runtime). See the README's **Updating** section.

## [1.2.2] — 2026-06-13

### Changed
- Poll the usage endpoint gently to avoid self-inflicted rate-limit (429)
  blanks. A cached response younger than `FRESH_TTL` (60s) is now reused
  **without re-fetching**, so a burst of chimes costs at most one request a
  minute. Only an older cache triggers a fetch; a rate-limited fetch still
  falls back to a value up to `STALE_TTL` (300s) old, marked `~`.

## [1.2.1] — 2026-06-13

### Fixed
- Gauge bars now line up. Text labels (`Session` / `Week`) differ in width in
  the notification's proportional font, which pushed the bars out of alignment;
  they're replaced with fixed-width emoji labels — ⏱️ session, 📅 week — that
  align in both languages.

## [1.2.0] — 2026-06-13

### Added
- **Action icon** on the message: ✅ for "done", 👀 for "needs you", so the two
  chime types are distinguishable at a glance.
- **Color-coded balance**: each gauge line leads with a 🟢🟡🔴 dot
  (>30% / 10–30% / <10% remaining) and a small `▰▰▰▰▱` bar.
- Imminent resets read `<1分` / `<1m` (session) and `<1时` / `<1h` (week)
  instead of a row of zeros.
- A leading `~` marks a percentage served from cache (a rate-limited fetch).

### Changed
- The gauge now shows **session and week on their own lines** so neither wraps.
- Chimes share a notification **group**, so a new one replaces the previous in
  Notification Center instead of stacking up.

## [1.1.0] — 2026-06-11

### Added
- ⏳ **Reset countdown** in the usage gauge: time until each limit resets —
  session to hours + minutes, week to days + hours (a zero day is dropped).
- Short-lived usage cache (`$TMPDIR`, ~5 min) so back-to-back
  Notification + Stop chimes still show the gauge when the endpoint rate-limits
  (429). The countdown is recomputed live from the cached `resets_at`.
- `chime.sh --version` prints the installed version.

### Changed
- Compacted the gauge (`会话/Session`, `本周/Week`) and moved it to the lighter
  message body so the actual content stays prominent in the bold subtitle.

## [1.0.0] — initial release

### Added
- Native macOS notification on Claude Code `Stop` (done) and `Notification`
  (waiting), each with its own sound.
- The real Claude icon on the notification (by swapping `terminal-notifier`'s
  app icon, since macOS forces the sending app's bundle icon).
- Live session/weekly usage gauge from the same data `/usage` shows.
- English + 中文, auto-detected from the system language.
- Click the notification to focus the terminal that launched Claude Code.
- One-line `curl | bash` installer/uninstaller; idempotent and hook-safe.

[1.2.2]: https://github.com/wangpuv/claude-chime/releases/tag/v1.2.2
[1.2.1]: https://github.com/wangpuv/claude-chime/releases/tag/v1.2.1
[1.2.0]: https://github.com/wangpuv/claude-chime/releases/tag/v1.2.0
[1.1.0]: https://github.com/wangpuv/claude-chime/releases/tag/v1.1.0
