#!/usr/bin/env python3
"""Make the bitmap fonts for the watch face.

The watch has no number font that is large enough for the minutes. This
script draws the glyphs with headless Chrome and writes a BMFont text file
and a PNG file for each font in resources/fonts. Each font has its own size,
typeface and padding. By default the glyphs are the digits 0 to 9 in cells of
equal width. A font can have a list of texts instead: each text is one glyph
with its own width, for example a whole Arabic word. The browser joins the
letters of the word. The glyph ids start at 48.

Roboto is from Google Fonts, under the Apache License 2.0.
Noto Kufi Arabic is from Google Fonts, under the SIL Open Font License 1.1.

Usage: python3 tools/make_fonts.py
"""
import base64
import html
import json
import pathlib
import re
import subprocess
import sys
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGE = ROOT / "tools" / "font" / "make-font.html"
OUT = ROOT / "resources" / "fonts"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Font name in the resources. For each font: the size in pixels, the Google
# Fonts family and weight, the face name for the .fnt file, and the padding
# that is added to the width of a glyph. The optional "glyphs" is a list of
# texts, one for each glyph. The page loads the same typefaces.
FONTS = {
    "minutes": {"size": 94, "family": "Roboto", "weight": 900, "face": "Roboto Black", "pad": 2},
    "hour": {"size": 70, "family": "Roboto", "weight": 900, "face": "Roboto Black", "pad": 2},
    "prayer": {
        "size": 15, "family": "Noto Kufi Arabic", "weight": 700, "face": "Noto Kufi Arabic Bold", "pad": 2,
        "glyphs": ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"],
    },
}


def render(fonts):
    spec = [{k: f[k] for k in ("size", "family", "weight", "pad", "glyphs") if k in f} for f in fonts]
    url = PAGE.as_uri() + "?fonts=" + urllib.parse.quote(json.dumps(spec))
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


def write_font(name, font, drawn):
    if not drawn["loaded"]:
        sys.exit(f"{font['family']} {font['weight']} did not load. Check the internet connection.")
    png = base64.b64decode(drawn["png"].split(",", 1)[1])
    (OUT / f"{name}.png").write_bytes(png)
    cells, height, base = drawn["glyphs"], drawn["height"], drawn["base"]
    total = cells[-1]["x"] + cells[-1]["width"]
    lines = [
        f'info face="{font["face"]}" size={drawn["size"]} bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=0,0 outline=0",
        f"common lineHeight={height} base={base} scaleW={total} scaleH={height} pages=1 packed=0 "
        "alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4",
        f'page id=0 file="{name}.png"',
        f"chars count={len(cells)}",
    ]
    for index, cell in enumerate(cells):
        lines.append(
            f"char id={48 + index} x={cell['x']} y=0 width={cell['width']} height={height} "
            f"xoffset=0 yoffset=0 xadvance={cell['width']} page=0 chnl=15"
        )
    (OUT / f"{name}.fnt").write_text("\n".join(lines) + "\n")
    widths = ",".join(str(cell["width"]) for cell in cells)
    print(f"{name}: size {drawn['size']}, height {height}, widths {widths}, {len(png)} bytes")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rendered = render(list(FONTS.values()))
    for (name, font), drawn in zip(FONTS.items(), rendered):
        write_font(name, font, drawn)


if __name__ == "__main__":
    main()
