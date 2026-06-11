#!/usr/bin/env python3
"""Render the README demo (assets/demo.gif + assets/demo.png).

Recreates a macOS notification banner in HTML/CSS, screenshots it with headless
Chrome, and stitches the frames into a looping GIF with Pillow.

Usage: python3 tools/make-demo.py
Requires: Google Chrome, Pillow (pip install pillow).
"""
import base64
import pathlib
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets" / "claude-logo.png"
OUT_GIF = ROOT / "assets" / "demo.gif"
OUT_PNG = ROOT / "assets" / "demo.png"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

W, H, SCALE = 720, 250, 2

FRAMES = [
    {  # English · task done
        "title": "Claude Code · Done",
        "body": "Task finished — back to you",
        "gauge": "Session 62% left · Week 62% left",
        "time": "now",
    },
    {  # 中文 · 等待确认
        "title": "Claude Code · 等你确认",
        "body": "有操作在等你确认 / 输入",
        "gauge": "本次会话余量 62% · 本周余量 62%",
        "time": "现在",
    },
]

HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
  body {{
    display:flex; align-items:center; justify-content:center;
    background:
      radial-gradient(120% 140% at 18% 0%, #f3f6fb 0%, #e6ebf3 55%, #dde3ec 100%);
    font-family:-apple-system,"SF Pro Text","Helvetica Neue",Helvetica,Arial,sans-serif;
  }}
  .card {{
    position:relative; width:392px; display:flex; gap:13px; align-items:flex-start;
    padding:14px 16px; border-radius:20px;
    background:rgba(255,255,255,0.97);
    box-shadow:0 18px 50px rgba(40,52,74,.22), 0 1px 0 rgba(255,255,255,.9) inset;
  }}
  .icon {{ width:40px; height:40px; flex:none; }}
  .text {{ flex:1; min-width:0; padding-top:1px; }}
  .title {{ font-size:14.5px; font-weight:600; color:#0f1115; letter-spacing:.1px; }}
  .body  {{ font-size:13px; color:#3c4150; margin-top:2px; }}
  .gauge {{ font-size:13px; font-weight:600; color:#c1623a; margin-top:5px;
            letter-spacing:.1px; }}
  .time  {{ position:absolute; top:14px; right:16px; font-size:11.5px; color:#9aa1ad; }}
</style></head><body>
  <div class="card">
    <img class="icon" src="data:image/png;base64,{logo}">
    <div class="text">
      <div class="title">{title}</div>
      <div class="body">{body}</div>
      <div class="gauge">{gauge}</div>
    </div>
    <div class="time">{time}</div>
  </div>
</body></html>"""


def render(frame, png_path):
    logo_b64 = base64.b64encode(LOGO.read_bytes()).decode()
    html = HTML.format(W=W, H=H, logo=logo_b64, **frame)
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
        f.write(html)
        html_path = f.name
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
         f"--force-device-scale-factor={SCALE}", f"--window-size={W},{H}",
         "--default-background-color=00000000",
         f"--screenshot={png_path}", f"file://{html_path}"],
        check=True, capture_output=True,
    )


def main():
    frames = []
    for i, frame in enumerate(FRAMES):
        png = ROOT / "assets" / f"_frame{i}.png"
        render(frame, png)
        frames.append(Image.open(png).convert("RGB"))

    frames[0].save(OUT_PNG)
    frames[0].save(
        OUT_GIF, save_all=True, append_images=frames[1:],
        duration=[2200, 2200], loop=0, optimize=True,
    )
    for i in range(len(FRAMES)):
        (ROOT / "assets" / f"_frame{i}.png").unlink(missing_ok=True)
    print(f"wrote {OUT_GIF.relative_to(ROOT)} and {OUT_PNG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
