#!/usr/bin/env python3
"""Make the digit fonts for the watch face.

The watch has no number font that is large enough for the minutes. This
script draws the digits 0 to 9 in Roboto Black with headless Chrome and
writes a BMFont text file and a PNG file for each font in resources/fonts.

Roboto is from Google Fonts, under the Apache License 2.0.

Usage: python3 tools/make_fonts.py
"""
import base64
import html
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGE = ROOT / "tools" / "font" / "make-font.html"
OUT = ROOT / "resources" / "fonts"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Font name in the resources, and the font size in pixels.
FONTS = {"minutes": 120, "hour": 42}


def render(sizes):
    url = PAGE.as_uri() + "?sizes=" + ",".join(str(s) for s in sizes)
    dom = subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--virtual-time-budget=15000", "--dump-dom", url],
        check=True, capture_output=True, text=True, timeout=120,
    ).stdout
    match = re.search(r'<pre id="out">(.*?)</pre>', dom, re.S)
    if not match:
        sys.exit("The page gave no result.")
    result = json.loads(html.unescape(match.group(1)))
    if isinstance(result, dict):
        sys.exit("The page failed: " + result.get("error", "unknown error"))
    return result


def write_font(name, glyphs):
    if not glyphs["loaded"]:
        sys.exit("Roboto did not load. Check the internet connection.")
    png = base64.b64decode(glyphs["png"].split(",", 1)[1])
    (OUT / f"{name}.png").write_bytes(png)
    cell, height, base = glyphs["cell"], glyphs["height"], glyphs["base"]
    lines = [
        f'info face="Roboto Black" size={glyphs["size"]} bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0 outline=0",
        f"common lineHeight={height} base={base} scaleW={cell * 10} scaleH={height} pages=1 packed=0 "
        "alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4",
        f'page id=0 file="{name}.png"',
        "chars count=10",
    ]
    for index in range(10):
        lines.append(
            f"char id={48 + index} x={index * cell} y=0 width={cell} height={height} "
            f"xoffset=0 yoffset=0 xadvance={cell} page=0 chnl=15"
        )
    (OUT / f"{name}.fnt").write_text("\n".join(lines) + "\n")
    print(f"{name}: size {glyphs['size']}, cell {cell} x {height}, {len(png)} bytes")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rendered = {g["size"]: g for g in render(sorted(set(FONTS.values())))}
    for name, size in FONTS.items():
        write_font(name, rendered[size])


if __name__ == "__main__":
    main()
