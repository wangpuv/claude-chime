#!/usr/bin/env bash
# Claude Chime installer — https://github.com/wangpuv/claude-chime
#
#   curl -fsSL https://raw.githubusercontent.com/wangpuv/claude-chime/main/install.sh | bash
#
set -euo pipefail

REPO_RAW="${CLAUDE_CHIME_REPO_RAW:-https://raw.githubusercontent.com/wangpuv/claude-chime/main}"
DEST="$HOME/.claude-chime"
SETTINGS="$HOME/.claude/settings.json"

say() { printf '\033[1;36m▶\033[0m %s\n' "$1"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m✖\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || die "Claude Chime is macOS-only (it uses macOS notifications)."

say "Installing Claude Chime"

# --- 1. Homebrew + terminal-notifier ----------------------------------------
BREW="$(command -v brew || true)"
[ -n "$BREW" ] || die "Homebrew not found. Install it from https://brew.sh and re-run."
BREW_PREFIX="$("$BREW" --prefix)"
TN="$BREW_PREFIX/bin/terminal-notifier"
if [ ! -x "$TN" ] && ! command -v terminal-notifier >/dev/null 2>&1; then
  say "Installing terminal-notifier via Homebrew"
  "$BREW" install terminal-notifier
fi
[ -x "$TN" ] || TN="$(command -v terminal-notifier)"

# --- 2. download runtime files ----------------------------------------------
mkdir -p "$DEST"
say "Downloading runtime files into $DEST"
curl -fsSL "$REPO_RAW/chime.sh"             -o "$DEST/chime.sh"
curl -fsSL "$REPO_RAW/usage.py"             -o "$DEST/usage.py"
curl -fsSL "$REPO_RAW/assets/claude-logo.png" -o "$DEST/claude-logo.png"
chmod +x "$DEST/chime.sh"

# --- 3. give terminal-notifier the Claude icon ------------------------------
# macOS forces a notification to show the *sending app's* bundle icon, so we
# swap terminal-notifier.app's icon for the Claude logo. (Re-run after a
# `brew upgrade terminal-notifier`, which restores the stock icon.)
APP="$(find "$BREW_PREFIX/Cellar/terminal-notifier" -maxdepth 3 -name 'terminal-notifier.app' -type d 2>/dev/null | head -1)"
if [ -n "$APP" ]; then
  say "Setting the Claude icon on terminal-notifier"
  WORK="$(mktemp -d)"; ICONSET="$WORK/claude.iconset"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$DEST/claude-logo.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" "$DEST/claude-logo.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$WORK/Claude.icns"
  ICON_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" 2>/dev/null | sed 's/\.icns$//')"
  [ -n "$ICON_NAME" ] || ICON_NAME="Terminal"
  ICNS_DEST="$APP/Contents/Resources/${ICON_NAME}.icns"
  [ -f "$ICNS_DEST" ] && cp "$ICNS_DEST" "$DEST/terminal-notifier-icon.bak.icns" 2>/dev/null || true
  cp "$WORK/Claude.icns" "$ICNS_DEST"
  touch "$APP"
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP" >/dev/null 2>&1 || true
  rm -rf "$WORK"
  killall -KILL Dock >/dev/null 2>&1 || true
  killall NotificationCenter >/dev/null 2>&1 || true
fi

# --- 4. wire Claude Code hooks (idempotent) ---------------------------------
say "Wiring Claude Code hooks in $SETTINGS"
/usr/bin/python3 - "$SETTINGS" "$DEST/chime.sh" "$TN" <<'PY'
import json, os, sys

settings_path, chime, tn = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.dirname(settings_path), exist_ok=True)

try:
    with open(settings_path) as f:
        cfg = json.load(f)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError:
    sys.exit("settings.json is not valid JSON; not touching it. Wire the hooks manually (see README).")

hooks = cfg.setdefault("hooks", {})

def already(event):
    for grp in hooks.get(event, []):
        for h in grp.get("hooks", []):
            if "chime.sh" in h.get("command", ""):
                return True
    return False

def add(event, matcher, mode):
    cmd = f'CLAUDE_CHIME_TN="{tn}" "{chime}" {mode} >/dev/null 2>&1 || true'
    entry = {"hooks": [{"type": "command", "command": cmd}]}
    if matcher is not None:
        entry["matcher"] = matcher
    hooks.setdefault(event, []).append(entry)

changed = False
if not already("Stop"):
    add("Stop", None, "stop"); changed = True
if not already("Notification"):
    add("Notification", "*", "waiting"); changed = True

if changed:
    with open(settings_path, "w") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    print("  hooks added.")
else:
    print("  hooks already present; left as-is.")
PY

# --- 5. test chime -----------------------------------------------------------
say "Sending a test chime"
CLAUDE_CHIME_TN="$TN" "$DEST/chime.sh" stop || true

ok "Claude Chime is installed."
echo
echo "  • New chimes take effect in new Claude Code sessions."
echo "  • Customize via env vars in ~/.claude/settings.json (see README):"
echo "      CLAUDE_CHIME_LANG=zh|en   CLAUDE_CHIME_SOUND_STOP=Glass   CLAUDE_CHIME_NO_USAGE=1"
echo "  • Uninstall:  curl -fsSL $REPO_RAW/uninstall.sh | bash"
