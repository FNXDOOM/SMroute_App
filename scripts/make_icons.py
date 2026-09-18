"""Generate Android launcher icons from the Smroute brand image.

- Legacy mipmap ic_launcher.png (48..192px): full-bleed artwork (its own
  rounded-square on black reads correctly on any launcher background).
- ic_launcher_round.png: same artwork cropped to a circle (round-icon
  launchers expect an already-circular bitmap).
- Adaptive foreground (108..432px): logo scaled to 66% of the 108dp canvas,
  centered — content stays inside the ~66dp safe zone for every mask shape.
- Play Store listing icon: 512px PNG (full-bleed is fine for the listing).
"""
from PIL import Image, ImageDraw, ImageOps
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "branding", "smroute_icon.png")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
SAFE_ZONE = 0.66  # content must fit within ~66dp of the 108dp canvas

src = Image.open(SRC).convert("RGBA")


def center_cover(size: int) -> Image.Image:
    """Square-cover resize (source is square, so a plain resize)."""
    return src.resize((size, size), Image.LANCZOS)


def circle_crop(img: Image.Image) -> Image.Image:
    """Crop to a full-bleed circle with transparency outside."""
    size = img.size[0]
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def adaptive_foreground(size: int) -> Image.Image:
    """Logo at 66% of the canvas, centered on transparency."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * SAFE_ZONE)
    logo = src.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    canvas.paste(logo, (offset, offset), logo)
    return canvas


written = []
for dpi, px in LEGACY.items():
    folder = os.path.join(RES, f"mipmap-{dpi}")
    os.makedirs(folder, exist_ok=True)
    square = center_cover(px)
    square.save(os.path.join(folder, "ic_launcher.png"))
    circle_crop(square).save(os.path.join(folder, "ic_launcher_round.png"))
    written += [f"mipmap-{dpi}/ic_launcher.png", f"mipmap-{dpi}/ic_launcher_round.png"]

for dpi, px in ADAPTIVE.items():
    folder = os.path.join(RES, f"mipmap-{dpi}")
    os.makedirs(folder, exist_ok=True)
    adaptive_foreground(px).save(os.path.join(folder, "ic_launcher_foreground.png"))
    written.append(f"mipmap-{dpi}/ic_launcher_foreground.png")

store = center_cover(512)
store_path = os.path.join(ROOT, "assets", "branding", "play-store-512.png")
store.save(store_path)
written.append("assets/branding/play-store-512.png")

print(f"generated {len(written)} icons:")
for w in written:
    print(f"  {w}")
