#!/usr/bin/env bash
# Claude Chime — a friendly desktop notification with the Claude icon, a sound,
# and a live usage gauge, fired when Claude Code finishes or needs you.
#
# Usage: chime.sh <stop|waiting>
#
# Environment overrides (all optional):
#   CLAUDE_CHIME_TN          path to terminal-notifier (auto-detected otherwise)
#   CLAUDE_CHIME_LANG        zh | en | auto   (default: auto, from $LANG)
#   CLAUDE_CHIME_SOUND_STOP  macOS sound name for "done"    (default: Glass)
#   CLAUDE_CHIME_SOUND_WAIT  macOS sound name for "waiting"  (default: Submarine)
#   CLAUDE_CHIME_NO_USAGE    set to 1 to skip the usage gauge entirely
set -uo pipefail

MODE="${1:-stop}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- locate terminal-notifier ------------------------------------------------
TN="${CLAUDE_CHIME_TN:-}"
[ -z "$TN" ] && TN="$(command -v terminal-notifier 2>/dev/null || true)"
[ -z "$TN" ] && [ -x /opt/homebrew/bin/terminal-notifier ] && TN=/opt/homebrew/bin/terminal-notifier
[ -z "$TN" ] && [ -x /usr/local/bin/terminal-notifier ] && TN=/usr/local/bin/terminal-notifier
[ -z "$TN" ] && exit 0   # no notifier available; nothing to do

# --- language ----------------------------------------------------------------
LANG_PREF="${CLAUDE_CHIME_LANG:-auto}"
if [ "$LANG_PREF" = "auto" ]; then
  case "${LC_ALL:-}${LANG:-}" in
    *[Zz][Hh]*) LANG_PREF="zh" ;;
    *) LANG_PREF="en" ;;
  esac
fi

# --- usage gauge (fail-silent) -----------------------------------------------
USAGE=""
if [ "${CLAUDE_CHIME_NO_USAGE:-0}" != "1" ] && [ -f "$HERE/usage.py" ]; then
  USAGE="$(/usr/bin/python3 "$HERE/usage.py" "$LANG_PREF" 2>/dev/null || true)"
fi

# --- compose message ---------------------------------------------------------
case "$MODE" in
  waiting)
    if [ "$LANG_PREF" = "zh" ]; then
      TITLE="Claude Code · 等你确认"; DEFAULT="有操作在等你确认 / 输入"
    else
      TITLE="Claude Code · Needs you"; DEFAULT="Waiting for your confirmation / input"
    fi
    SOUND="${CLAUDE_CHIME_SOUND_WAIT:-Submarine}"
    ;;
  *)
    if [ "$LANG_PREF" = "zh" ]; then
      TITLE="Claude Code · 任务完成"; DEFAULT="任务已完成，等你查看"
    else
      TITLE="Claude Code · Done"; DEFAULT="Task finished — back to you"
    fi
    SOUND="${CLAUDE_CHIME_SOUND_STOP:-Glass}"
    ;;
esac

# --- fire --------------------------------------------------------------------
if [ -n "$USAGE" ]; then
  "$TN" -title "$TITLE" -subtitle "$DEFAULT" -message "$USAGE" -sound "$SOUND" >/dev/null 2>&1 || true
else
  "$TN" -title "$TITLE" -message "$DEFAULT" -sound "$SOUND" >/dev/null 2>&1 || true
fi
exit 0
