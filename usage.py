#!/usr/bin/env python3
"""Print a one-line Claude Code usage gauge, or nothing if unavailable.

Reads the Claude Code OAuth token from the macOS login Keychain and queries the
same endpoint the `/usage` command uses. Fails silently (prints nothing, exits 0)
so the caller can always fall back to a plain message.

Usage: usage.py [zh|en]
"""
import json
import subprocess
import sys
import urllib.error
import urllib.request

LANG = sys.argv[1] if len(sys.argv) > 1 else "en"
ENDPOINT = "https://api.anthropic.com/api/oauth/usage"
TIMEOUT = 4


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


def clamp(n):
    return max(0, min(100, n))


def main():
    token = get_token()
    if not token:
        return
    try:
        data = fetch(token)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError):
        return
    try:
        session = clamp(round(100 - float(data["five_hour"]["utilization"])))
        week = clamp(round(100 - float(data["seven_day"]["utilization"])))
    except (KeyError, TypeError, ValueError):
        return
    if LANG == "zh":
        print(f"本次会话余量 {session}% · 本周余量 {week}%")
    else:
        print(f"Session {session}% left · Week {week}% left")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
