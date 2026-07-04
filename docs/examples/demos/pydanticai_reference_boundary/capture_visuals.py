#!/usr/bin/env python3
"""Capture committed visuals for the PydanticAI reference-boundary demo."""

from __future__ import annotations

from html import escape
from pathlib import Path

from playwright.sync_api import sync_playwright


DEMO_DIR = Path(__file__).resolve().parent
SCREENSHOT_DIR = DEMO_DIR / "screenshots"
INDEX_HTML = DEMO_DIR / "index.html"
TERMINAL_CAPTURE = DEMO_DIR / "terminal_capture.txt"


def terminal_html(transcript: str) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <style>
    html, body {{
      margin: 0;
      background: #070b10;
      color: #d7e2f0;
      font: 18px/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }}
    main {{
      width: 1280px;
      min-height: 860px;
      padding: 34px;
      background:
        linear-gradient(180deg, rgba(255,255,255,.04), transparent 220px),
        #070b10;
    }}
    .chrome {{
      height: 38px;
      border: 1px solid rgba(255,255,255,.14);
      border-bottom: 0;
      border-radius: 8px 8px 0 0;
      background: #111923;
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 0 14px;
    }}
    .dot {{ width: 12px; height: 12px; border-radius: 50%; }}
    .red {{ background: #fb7185; }}
    .yellow {{ background: #fbbf24; }}
    .green {{ background: #86efac; }}
    pre {{
      margin: 0;
      min-height: 720px;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      border: 1px solid rgba(255,255,255,.14);
      border-radius: 0 0 8px 8px;
      padding: 24px;
      background: #05080d;
    }}
  </style>
</head>
<body>
  <main>
    <div class="chrome">
      <span class="dot red"></span><span class="dot yellow"></span><span class="dot green"></span>
    </div>
    <pre>{escape(transcript)}</pre>
  </main>
</body>
</html>"""


def main() -> None:
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1440, "height": 1100}, device_scale_factor=1)
        page.goto(INDEX_HTML.resolve().as_uri(), wait_until="networkidle")
        page.screenshot(path=SCREENSHOT_DIR / "index.png", full_page=True)

        terminal = browser.new_page(viewport={"width": 1348, "height": 930}, device_scale_factor=1)
        terminal.set_content(
            terminal_html(TERMINAL_CAPTURE.read_text(encoding="utf-8")),
            wait_until="networkidle",
        )
        terminal.screenshot(path=SCREENSHOT_DIR / "terminal_capture.png", full_page=True)
        browser.close()

    print(f"wrote {SCREENSHOT_DIR / 'index.png'}")
    print(f"wrote {SCREENSHOT_DIR / 'terminal_capture.png'}")


if __name__ == "__main__":
    main()
