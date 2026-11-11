#!/usr/bin/env bash
# Make docs/watch-face.png, the image of the README.
#
# The image is a drawing from design/layouts.html (layout P7), not a photo of
# the watch. The script needs Google Chrome and an internet connection for
# the fonts.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
layout="${1:-P7}"

"$chrome" --headless=new --disable-gpu --hide-scrollbars \
  --window-size=600,600 --default-background-color=00000000 \
  --virtual-time-budget=15000 \
  --screenshot="$root/docs/watch-face.png" \
  "file://$root/design/layouts.html?only=$layout" >/dev/null 2>&1

ls -l "$root/docs/watch-face.png"
