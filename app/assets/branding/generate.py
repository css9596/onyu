"""Regenerate the placeholder app icon and splash from a single source.

Replace these later with proper designed assets — same dimensions, same paths,
re-run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

OUT = Path(__file__).parent
KOREAN_FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

BRAND_PURPLE = "#5E35B1"      # deepPurple ~700, matches MaterialTheme seed
BRAND_PURPLE_DARK = "#4527A0"  # for splash bg in dark mode
INK = "#FFFFFF"


def render_glyph_centered(canvas: Image.Image, glyph: str, font_size: int, color: str):
    """Draw a single Korean glyph perfectly centered on canvas."""
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(KOREAN_FONT, font_size)
    bbox = draw.textbbox((0, 0), glyph, font=font)
    glyph_w = bbox[2] - bbox[0]
    glyph_h = bbox[3] - bbox[1]
    x = (canvas.width - glyph_w) / 2 - bbox[0]
    y = (canvas.height - glyph_h) / 2 - bbox[1]
    draw.text((x, y), glyph, fill=color, font=font)


def make_icon():
    """1024x1024, full-bleed: solid purple + large 온 glyph."""
    img = Image.new("RGB", (1024, 1024), color=BRAND_PURPLE)
    render_glyph_centered(img, "온", font_size=620, color=INK)
    img.save(OUT / "icon.png")


def make_icon_foreground():
    """1024x1024 transparent, glyph only — for Android adaptive icon foreground.
    Glyph is sized smaller so it sits in the safe zone (66% center)."""
    img = Image.new("RGBA", (1024, 1024), color=(0, 0, 0, 0))
    render_glyph_centered(img, "온", font_size=440, color=INK)
    img.save(OUT / "icon_foreground.png")


def make_splash():
    """Splash logo: 512x512 transparent with the glyph."""
    img = Image.new("RGBA", (512, 512), color=(0, 0, 0, 0))
    render_glyph_centered(img, "온", font_size=300, color=INK)
    img.save(OUT / "splash.png")


def make_splash_android12():
    """Android 12+ splash spec: 1152x1152 PNG; only inner 1/3 is visible (~384x384).
    Glyph must fit within the inner 384x384 circle."""
    img = Image.new("RGBA", (1152, 1152), color=(0, 0, 0, 0))
    render_glyph_centered(img, "온", font_size=240, color=INK)
    img.save(OUT / "splash_android12.png")


if __name__ == "__main__":
    make_icon()
    make_icon_foreground()
    make_splash()
    make_splash_android12()
    print("Generated:", *(p.name for p in OUT.glob("*.png")))
