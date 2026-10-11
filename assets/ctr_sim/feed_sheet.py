#!/usr/bin/env python3
"""CTR sim, step 1: put thumbnail candidates into a mock dark Roblox-style feed grid, labelled A, B, C...

Usage: python3 feed_sheet.py out.png cand1.png cand2.png old_thumb.png competitor.png ...
       (shuffle=on by default so position doesn't bias the judges; the letter->file mapping is printed
        and written next to the sheet as <out>.mapping.txt)
Then step 2: show the sheet to 5 different player personas (see personas.md) and a judge, and ask which tile each
would tap first and why. Treat the result as a sanity check; real play-through rate comes from Creator Dashboard.
Needs: Pillow.
"""
import random, sys
from PIL import Image, ImageDraw, ImageFont

def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out, files = sys.argv[1], sys.argv[2:]
    random.shuffle(files)
    cols = 4 if len(files) > 4 else len(files)
    rows = (len(files) + cols - 1) // cols
    tw, th, pad, lab = 400, 225, 24, 34          # 16:9 tiles like Home
    W = cols * tw + (cols + 1) * pad
    H = rows * (th + lab) + (rows + 1) * pad
    sheet = Image.new("RGB", (W, H), (25, 27, 29))   # Roblox dark UI
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    mapping = []
    for i, f in enumerate(files):
        r, c = divmod(i, cols)
        x = pad + c * (tw + pad); y = pad + r * (th + lab + pad)
        im = Image.open(f).convert("RGB")
        im = im.resize((tw, th)) if abs(im.width / im.height - 16 / 9) < 0.05 else im.crop(_crop169(im)).resize((tw, th))
        mask = Image.new("L", (tw, th), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, tw, th), 14, fill=255)
        sheet.paste(im, (x, y), mask)
        letter = chr(65 + i)
        d.text((x + tw // 2, y + th + 6), letter, fill=(230, 230, 230), font=font, anchor="mt")
        mapping.append(f"{letter}={f}")
    sheet.save(out)
    open(out + ".mapping.txt", "w").write("\n".join(mapping) + "\n")
    print("\n".join(mapping)); print("wrote", out)

def _crop169(im):
    w, h = im.size
    if w / h > 16 / 9:
        nw = int(h * 16 / 9); return ((w - nw) // 2, 0, (w - nw) // 2 + nw, h)
    nh = int(w * 9 / 16); return (0, (h - nh) // 2, w, (h - nh) // 2 + nh)

if __name__ == "__main__":
    main()
