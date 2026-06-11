# Changelog

All notable changes to Claude Chime are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project aims to use
[Semantic Versioning](https://semver.org/).

To upgrade, re-run the install one-liner (it is idempotent and pulls the latest
runtime). See the README's **Updating** section.

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

[1.1.0]: https://github.com/wangpuv/claude-chime/releases/tag/v1.1.0
