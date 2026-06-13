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
#   CLAUDE_CHIME_ACTIVATE    bundle id to focus when the notification is clicked
#                            (default: auto-detect the launching terminal app)
set -uo pipefail

MODE="${1:-stop}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- version -----------------------------------------------------------------
case "$MODE" in
  --version|-v|version)
    echo "claude-chime $(cat "$HERE/VERSION" 2>/dev/null || echo unknown)"
    exit 0
    ;;
esac

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

# --- click action: focus the terminal that launched Claude Code --------------
# macOS always shows a default action button ("Show"); bind it to bringing the
# launching terminal to the front instead of activating terminal-notifier (which
# has no window, so the click looks like a no-op). __CFBundleIdentifier is set by
# macOS to the bundle id of the app that launched this process tree.
# Best-effort only: this activates the terminal *app*, not a specific window/tab
# — landing on the exact session window needs window-level scripting the terminal
# may not expose (Apple Terminal, Kaku, … don't), so with multiple windows open
# the click may surface the wrong one.
ACTIVATE="${CLAUDE_CHIME_ACTIVATE:-${__CFBundleIdentifier:-}}"
if [ -z "$ACTIVATE" ]; then
  case "${TERM_PROGRAM:-}" in
    iTerm.app)      ACTIVATE="com.googlecode.iterm2" ;;
    Apple_Terminal) ACTIVATE="com.apple.Terminal" ;;
    vscode)         ACTIVATE="com.microsoft.VSCode" ;;
    WezTerm)        ACTIVATE="com.github.wez.wezterm" ;;
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
    # 👀 leads the content so you can tell "needs you" from ✅ "done" at a glance.
    if [ "$LANG_PREF" = "zh" ]; then
      TITLE="Claude Code · 等你确认"; DEFAULT="👀 有操作在等你确认 / 输入"
    else
      TITLE="Claude Code · Needs you"; DEFAULT="👀 Waiting for your confirmation / input"
    fi
    SOUND="${CLAUDE_CHIME_SOUND_WAIT:-Submarine}"
    ;;
  *)
    # ✅ (green check) leads the content so "done" reads at a glance.
    if [ "$LANG_PREF" = "zh" ]; then
      TITLE="Claude Code · 任务完成"; DEFAULT="✅ 任务已完成，等你查看"
    else
      TITLE="Claude Code · Done"; DEFAULT="✅ Task finished — back to you"
    fi
    SOUND="${CLAUDE_CHIME_SOUND_STOP:-Glass}"
    ;;
esac

# --- fire --------------------------------------------------------------------
# Keep the content the star of the show: it goes in the bold subtitle (top,
# prominent), with the usage gauge (session + week, one per line) in the lighter
# message body. A shared -group means each new chime replaces the previous one
# in Notification Center instead of stacking up — only the latest state matters.
ARGS=(-title "$TITLE" -sound "$SOUND" -group "claude-chime")
if [ -n "$USAGE" ]; then
  ARGS+=(-subtitle "$DEFAULT" -message "$USAGE")
else
  ARGS+=(-message "$DEFAULT")
fi
[ -n "$ACTIVATE" ] && ARGS+=(-activate "$ACTIVATE")

"$TN" "${ARGS[@]}" >/dev/null 2>&1 || true
exit 0
