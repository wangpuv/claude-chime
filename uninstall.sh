#!/usr/bin/env bash
# Claude Chime uninstaller — removes hooks, restores the terminal-notifier icon,
# and deletes ~/.claude-chime. Leaves terminal-notifier itself installed.
#
#   curl -fsSL https://raw.githubusercontent.com/wangpuv/claude-chime/main/uninstall.sh | bash
#
set -euo pipefail

DEST="$HOME/.claude-chime"
SETTINGS="$HOME/.claude/settings.json"

say() { printf '\033[1;36m▶\033[0m %s\n' "$1"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$1"; }

# --- 1. remove hooks ---------------------------------------------------------
if [ -f "$SETTINGS" ]; then
  say "Removing Claude Chime hooks from settings.json"
  /usr/bin/python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
hooks = cfg.get("hooks", {})
for event, groups in list(hooks.items()):
    kept = [g for g in groups
            if not any("chime.sh" in h.get("command", "") for h in g.get("hooks", []))]
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]
with open(path, "w") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
PY
fi

# --- 2. restore terminal-notifier icon --------------------------------------
BREW="$(command -v brew || true)"
if [ -n "$BREW" ] && [ -f "$DEST/terminal-notifier-icon.bak.icns" ]; then
  APP="$(find "$("$BREW" --prefix)/Cellar/terminal-notifier" -maxdepth 3 -name 'terminal-notifier.app' -type d 2>/dev/null | head -1)"
  if [ -n "$APP" ]; then
    say "Restoring the stock terminal-notifier icon"
    ICON_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" 2>/dev/null | sed 's/\.icns$//')"
    [ -n "$ICON_NAME" ] || ICON_NAME="Terminal"
    cp "$DEST/terminal-notifier-icon.bak.icns" "$APP/Contents/Resources/${ICON_NAME}.icns" || true
    touch "$APP"
    killall -KILL Dock >/dev/null 2>&1 || true
    killall NotificationCenter >/dev/null 2>&1 || true
  fi
fi

# --- 3. remove runtime dir ---------------------------------------------------
say "Removing $DEST"
rm -rf "$DEST"

ok "Claude Chime uninstalled. (terminal-notifier was left installed; remove with: brew uninstall terminal-notifier)"
