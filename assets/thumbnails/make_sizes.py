#!/usr/bin/env python3
"""Export an icon / thumbnail master to the sizes Roblox wants, with a safe-area check.

Usage:
  python3 make_sizes.py icon master_icon.png out_dir/      -> icon_1024.png, icon_512.png (square centre crop)
  python3 make_sizes.py thumb master_thumb.png out_dir/    -> thumb_1920x1080.png + thumb_640x360.jpg preview
                                                              + thumb_safe_area.png (bottom band shaded = player-count overlay)
Rules this enforces/visualises (docs/marketing-launch.md): 16:9 thumbs, 1:1 icon, nothing important in the bottom ~12%
of a thumbnail, badge/icon art readable when shown as a small circle (icon also gets icon_circle_preview.png).
Needs: Pillow.
"""
import os, sys
from PIL import Image, ImageDraw

def crop_to(im, ratio):
    w, h = im.size
    if w / h > ratio:
        nw = int(h * ratio); return im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    nh = int(w / ratio); return im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))

def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("icon", "thumb"):
        sys.exit(__doc__)
    kind, src, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    im = Image.open(src).convert("RGB")
    if kind == "icon":
        sq = crop_to(im, 1.0)
        for s in (1024, 512):
            sq.resize((s, s), Image.LANCZOS).save(os.path.join(out, f"icon_{s}.png"))
        small = sq.resize((150, 150), Image.LANCZOS)
        mask = Image.new("L", (150, 150), 0); ImageDraw.Draw(mask).ellipse((0, 0, 149, 149), fill=255)
        prev = Image.new("RGB", (150, 150), (25, 27, 29)); prev.paste(small, (0, 0), mask)
        prev.save(os.path.join(out, "icon_circle_preview.png"))
    else:
        t = crop_to(im, 16 / 9).resize((1920, 1080), Image.LANCZOS)
        t.save(os.path.join(out, "thumb_1920x1080.png"))
        t.resize((640, 360), Image.LANCZOS).save(os.path.join(out, "thumb_640x360.jpg"), quality=85)
        safe = t.copy(); ov = Image.new("RGBA", safe.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).rectangle((0, int(1080 * 0.88), 1920, 1080), fill=(255, 0, 0, 90))
        Image.alpha_composite(safe.convert("RGBA"), ov).convert("RGB").resize((960, 540)).save(
            os.path.join(out, "thumb_safe_area.png"))
    print("wrote", out)

if __name__ == "__main__":
    main()
