#!/usr/bin/env bash
# Render the SVG sources to PNGs at the sizes flutter_launcher_icons /
# flutter_native_splash expect. Re-run after editing any *.svg here, then
# `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.

set -euo pipefail
cd "$(dirname "$0")"

if ! command -v rsvg-convert >/dev/null; then
  echo "ERROR: rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

echo "==> avatar.png (chat use)"
rsvg-convert character.svg -w 256 -h 256 -o avatar.png

echo "==> icon.png (1024x1024, full bleed app icon)"
rsvg-convert icon.svg -w 1024 -h 1024 -o icon.png

echo "==> icon_foreground.png (1024x1024, adaptive icon foreground)"
rsvg-convert icon_foreground.svg -w 1024 -h 1024 -o icon_foreground.png

echo "==> splash.png (512x512, splash logo)"
rsvg-convert splash.svg -w 512 -h 512 -o splash.png

echo "==> splash_android12.png (1152x1152, Android 12+ splash)"
rsvg-convert splash.svg -w 1152 -h 1152 -o splash_android12.png

echo
echo "Generated:"
ls -la *.png
