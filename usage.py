#!/usr/bin/env python3
"""Print a one-line Claude Code usage gauge, or nothing if unavailable.

Reads the Claude Code OAuth token from the macOS login Keychain and queries the
same endpoint the `/usage` command uses. Fails silently (prints nothing, exits 0)
so the caller can always fall back to a plain message.

Usage: usage.py [zh|en]
"""
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

LANG = sys.argv[1] if len(sys.argv) > 1 else "en"
ENDPOINT = "https://api.anthropic.com/api/oauth/usage"
TIMEOUT = 4
# Back-to-back Stop+Notification fires can get rate-limited (429). Reuse the last
# good response within this window so the second chime still shows the gauge; the
# reset countdown is recomputed live from resets_at, so only the % may be stale.
CACHE_PATH = os.path.join(tempfile.gettempdir(), "claude-chime-usage.json")
# The endpoint rate-limits hard, and chimes are event-driven (every Stop /
# Notification), so a busy session would 429 constantly. We poll it like a
# background gauge would: if the cache is younger than FRESH_TTL, use it WITHOUT
# fetching at all — so many chimes in a row cost at most one request a minute.
# Only when the cache is older do we fetch; if that fetch fails we still fall
# back to a cached value up to STALE_TTL old (marked "~", % may be a bit stale).
FRESH_TTL = 60
STALE_TTL = 300


def get_token():
    try:
        raw = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, timeout=TIMEOUT,
        ).stdout.strip()
    except Exception:
        return None
    if not raw:
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return data.get("claudeAiOauth", {}).get("accessToken") or data.get("accessToken")


def fetch(token):
    req = urllib.request.Request(ENDPOINT)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("anthropic-beta", "oauth-2025-04-20")
    req.add_header("anthropic-version", "2023-06-01")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.load(resp)


def cache_save(data):
    try:
        with open(CACHE_PATH, "w") as f:
            json.dump(data, f)
    except OSError:
        pass


def cache_load(max_age):
    """Return the cached response if it's younger than max_age seconds, else None."""
    try:
        if time.time() - os.path.getmtime(CACHE_PATH) > max_age:
            return None
        with open(CACHE_PATH) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def clamp(n):
    return max(0, min(100, n))


# Color the balance at a glance: green plenty, yellow low, red almost out.
LOW, CRITICAL = 30, 10
BAR_SEGMENTS = 5
# Fixed-width emoji labels so the bars line up in a proportional font (text
# labels like "Session"/"Week" differ in width and break the alignment).
SESSION_ICON, WEEK_ICON = "⏱️", "📅"


def dot(pct):
    if pct < CRITICAL:
        return "🔴"
    if pct < LOW:
        return "🟡"
    return "🟢"


def bar(pct):
    """A tiny filled/empty bar, e.g. 78% -> '▰▰▰▰▱'."""
    filled = max(0, min(BAR_SEGMENTS, round(pct / 100 * BAR_SEGMENTS)))
    return "▰" * filled + "▱" * (BAR_SEGMENTS - filled)


def seconds_until(iso):
    """Seconds from now until an ISO-8601 reset timestamp, or None on failure."""
    try:
        reset = datetime.fromisoformat(iso)
    except (TypeError, ValueError):
        return None
    if reset.tzinfo is None:
        reset = reset.replace(tzinfo=timezone.utc)
    return max(0, (reset - datetime.now(timezone.utc)).total_seconds())


def fmt_hm(secs):
    """Countdown to hours+minutes, e.g. '3h25m' / '3时25分'; '<1分' under a minute."""
    m = int(secs // 60)
    h, m = divmod(m, 60)
    if h == 0 and m == 0:
        return "<1分" if LANG == "zh" else "<1m"
    return f"{h}时{m}分" if LANG == "zh" else f"{h}h{m}m"


def fmt_dh(secs):
    """Countdown to days+hours; days dropped when zero, '<1时' under an hour."""
    h = int(secs // 3600)
    d, h = divmod(h, 24)
    if d == 0 and h == 0:
        return "<1时" if LANG == "zh" else "<1h"
    if d == 0:
        return f"{h}时" if LANG == "zh" else f"{h}h"
    return f"{d}天{h}时" if LANG == "zh" else f"{d}d{h}h"


def main():
    token = get_token()
    if not token:
        return
    stale = False
    data = cache_load(FRESH_TTL)  # fresh enough? don't even hit the endpoint
    if data is None:
        try:
            data = fetch(token)
            cache_save(data)
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError):
            data = cache_load(STALE_TTL)  # rate-limited / offline: last good
            if data is None:
                return
            stale = True  # served from older cache: the % may be a few min old
    try:
        session = clamp(round(100 - float(data["five_hour"]["utilization"])))
        week = clamp(round(100 - float(data["seven_day"]["utilization"])))
    except (KeyError, TypeError, ValueError):
        return
    s_reset = seconds_until(data.get("five_hour", {}).get("resets_at"))
    w_reset = seconds_until(data.get("seven_day", {}).get("resets_at"))
    # Session and week go on their own lines so neither wraps. ⏳ marks "time
    # until reset"; a leading "~" marks a cached (slightly stale) percentage.
    mark = "~" if stale else ""
    s = f"{dot(session)} {SESSION_ICON} {bar(session)} {mark}{session}%" + (f" ⏳{fmt_hm(s_reset)}" if s_reset is not None else "")
    w = f"{dot(week)} {WEEK_ICON} {bar(week)} {mark}{week}%" + (f" ⏳{fmt_dh(w_reset)}" if w_reset is not None else "")
    print(s)
    print(w)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
