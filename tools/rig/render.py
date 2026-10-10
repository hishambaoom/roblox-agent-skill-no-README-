# RIG renderer (tools/rig/render.py): ONE styled approximation of a tools/rig/dump.example.luau JSON, merged from
# v17mig/HL + SC2 + IV renderers but generic: every dumped GuiObject is drawn from its baked look
# (BackgroundColor3 x UIGradient, UICorner, Border UIStroke, CanvasGroup>STUDS tile textures, "3d" lip,
# outlined text with alignment/wrap, Rotation, ClipsDescendants/CanvasGroup/ScrollingFrame clipping),
# in Roblox Sibling draw order (DisplayOrder, then ZIndex per level).
# Asset images (icons) and 3D viewports cannot be fetched offline -> translucent placeholders. NOT Studio.
# usage: python3 tools/rig/render.py <dump.json> <out.png> [crop x,y,w,h]      (Windows: py -3 tools\rig\render.py ...)
# Font: $RIG_FONT if set, else the first bold sans found (Linux DejaVu, Windows Arial/Segoe, macOS Arial),
# else Pillow's built-in default font (sizes are then approximate).
import json, sys, math, os
from PIL import Image, ImageDraw, ImageFont, ImageChops

_WINFONTS = os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts')
FONT_CANDIDATES = [p for p in (
    os.environ.get('RIG_FONT'),
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
    os.path.join(_WINFONTS, 'arialbd.ttf'),
    os.path.join(_WINFONTS, 'segoeuib.ttf'),
    os.path.join(_WINFONTS, 'calibrib.ttf'),
    '/Library/Fonts/Arial Bold.ttf',
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    'DejaVuSans-Bold.ttf', 'arialbd.ttf',  # bare names: Pillow searches the system font folders
) if p]
FB = None
for _p in FONT_CANDIDATES:
    try:
        ImageFont.truetype(_p, 10); FB = _p; break
    except OSError:
        continue
_fonts = {}
def font(s):
    s = max(5, int(round(s)))
    if s not in _fonts:
        if FB:
            _fonts[s] = ImageFont.truetype(FB, s)
        else:
            try: _fonts[s] = ImageFont.load_default(size=s)   # Pillow >= 10.1: scalable built-in font
            except TypeError: _fonts[s] = ImageFont.load_default()  # older Pillow: fixed bitmap font
    return _fonts[s]

def _text(d, xy, line, f, anchor, fill, sw=0, sfill=None):
    """d.text with a fallback for bitmap fonts that cannot do anchors/strokes (old Pillow default font)"""
    try:
        d.text(xy, line, font=f, anchor=anchor, fill=fill, stroke_width=sw, stroke_fill=sfill)
    except (ValueError, TypeError, NotImplementedError):
        w = d.textlength(line, font=f) if hasattr(d, 'textlength') else 6 * len(line)
        x, y = xy; h = 11
        x = x - w / 2 if anchor[0] == 'm' else x - w if anchor[0] == 'r' else x
        y = y - h / 2 if anchor[1] == 'm' else y
        d.text((x, y), line, font=f, fill=fill)

def c255(c): return tuple(max(0, min(255, int(round(v * 255)))) for v in c[:3])

def sample(kps, t):
    """UIGradient keypoint sample: kps = [[time, ...values]]"""
    if t <= kps[0][0]: return kps[0][1:]
    for a, b in zip(kps, kps[1:]):
        if t <= b[0]:
            k = (t - a[0]) / max(1e-6, b[0] - a[0])
            return [a[i] + (b[i] - a[i]) * k for i in range(1, len(a))]
    return kps[-1][1:]

def grad_layer(w, h, base, alpha, grad):
    """RGBA w x h: base colour (0..1) multiplied by the gradient, alpha 0..1 times gradient transparency"""
    n = 256
    strip = Image.new('RGBA', (n, 1))
    px = strip.load()
    for i in range(n):
        t = i / (n - 1)
        col = [base[k] * v for k, v in enumerate(sample(grad['c'], t))] if grad else base
        a = alpha * (1 - sample(grad['t'], t)[0]) if grad else alpha
        px[i, 0] = c255(col) + (max(0, min(255, int(a * 255))),)
    rot = (grad or {}).get('rot', 0) % 360
    if rot in (0, 180):
        g = strip.resize((w, h), Image.BILINEAR)
        return g.transpose(Image.FLIP_LEFT_RIGHT) if rot == 180 else g
    if rot in (90, 270):
        g = strip.transpose(Image.ROTATE_270).resize((w, h), Image.BILINEAR)  # keypoint 0 at the top for 90
        return g.transpose(Image.FLIP_TOP_BOTTOM) if rot == 270 else g
    d = int(math.hypot(w, h)) + 2
    g = strip.resize((d, d), Image.BILINEAR).rotate(-rot, resample=Image.BILINEAR)
    return g.crop(((d - w) // 2, (d - h) // 2, (d - w) // 2 + w, (d - h) // 2 + h))

def rmask(w, h, r):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=max(0, int(r or 0)), fill=255)
    return m

def clean(t):
    t = t.replace('\ue002', 'R$')
    out = []
    for ch in t:
        o = ord(ch)
        if o == 0xFE0F or 0x1F000 <= o <= 0x1FAFF or 0x2600 <= o <= 0x27BF or 0x2300 <= o <= 0x23FF or 0x2B00 <= o <= 0x2BFF: continue
        out.append(ch)
    return ''.join(out).strip()

def wrap_lines(dr, text, f, maxw):
    lines = []
    for para in text.split('\n'):
        cur = ''
        for word in para.split(' '):
            cand = (cur + ' ' + word) if cur else word
            if cur and dr.textlength(cand, font=f) > maxw: lines.append(cur); cur = word
            else: cur = cand
        lines.append(cur)
    return lines

def draw_text(layer, it, ox, oy, gradmul):
    raw = it['text']; t = clean(raw)
    th = it.get('th') or 12
    if it.get('iconOnly') or not t:  # emoji / icon-only label: placeholder glyph
        if raw.strip():
            d = ImageDraw.Draw(layer); s = min(it['w'], it['h'], th) * 0.8
            cx, cy = it['x'] - ox + it['w'] / 2, it['y'] - oy + it['h'] / 2
            d.ellipse([cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2], fill=(255, 255, 255, 110), outline=(0, 0, 0, 160), width=1)
        return
    th = min(th, it['h'] * 1.05) if it['h'] > 2 else th
    f = font(th); d = ImageDraw.Draw(layer)
    l, r, tp, b = it.get('pad') or (0, 0, 0, 0)
    x0, y0 = it['x'] - ox + l, it['y'] - oy + tp
    bw, bh = max(1, it['w'] - l - r), max(1, it['h'] - tp - b)
    lines = wrap_lines(d, t, f, bw) if it.get('wrap') else [t]
    lh = th * 1.0
    xa, ya = it.get('xa') or 'Center', it.get('ya') or 'Center'
    total = lh * len(lines)
    ystart = y0 + (0 if ya == 'Top' else bh - total if ya == 'Bottom' else (bh - total) / 2)
    col = [v * m for v, m in zip(it.get('tc') or (1, 1, 1), gradmul)]
    a = int(255 * (1 - (it.get('tT') or 0)))
    st = it.get('tstroke'); sw = 0; scol = (0, 0, 0, 0)
    if st:
        sw = max(1, int(round(st['th']))); scol = c255(st['c']) + (int(a * (1 - st['tr'])),)
    for i, line in enumerate(lines):
        cy = ystart + lh * (i + 0.5)
        if xa == 'Left': x, anc = x0, 'lm'
        elif xa == 'Right': x, anc = x0 + bw, 'rm'
        else: x, anc = x0 + bw / 2, 'mm'
        _text(d, (x, cy), line, f, anc, c255(col) + (a,), sw, scol)

def studs(layer, x, y, w, h, ts, alpha):
    """tile texture (STUDS) stand-in: one raised rounded stud per tile"""
    d = ImageDraw.Draw(layer)
    sx, sy = max(4.0, ts[0]), max(4.0, ts[1])
    a = int(255 * alpha)
    yy = y
    while yy < y + h:
        xx = x
        while xx < x + w:
            s = min(sx, sy) * 0.62; cx, cy = xx + sx / 2, yy + sy / 2
            d.rounded_rectangle([cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2], radius=s * 0.3, outline=(255, 255, 255, a), width=max(1, int(s * 0.12)))
            d.line([cx - s * 0.4, cy + s * 0.58, cx + s * 0.4, cy + s * 0.58], fill=(0, 0, 0, a // 2), width=max(1, int(s * 0.1)))
            xx += sx
        yy += sy

def render_item(im, it):
    W, H = im.size
    x, y, w, h = it['x'], it['y'], it['w'], it['h']
    if w < 1 or h < 1: return
    bgT = it.get('bgT', 1); grad = it.get('grad')
    has_bg = bgT < 0.99
    img_vis = it.get('img') and (it.get('imgT', 1) < 0.99)
    strokes = [s for s in (it.get('strokes') or []) if s['tr'] < 0.99]
    if not (has_bg or img_vis or strokes or it.get('text') or it.get('vp')): return
    # visible clip rect (ClipsDescendants / CanvasGroup ancestors, ScrollingFrame, screen)
    cl = it.get('clip') or [-1e9, -1e9, 1e9, 1e9]
    sc = it.get('scroll') or [-1e9, -1e9, 1e9, 1e9]
    cx0, cy0 = max(0, cl[0], sc[0]), max(0, cl[1], sc[1])
    cx1, cy1 = min(W, cl[2], sc[2]), min(H, cl[3], sc[3])
    if cx1 <= cx0 or cy1 <= cy0: return
    m = int(max([s['th'] for s in strokes] + [(it.get('tstroke') or {}).get('th', 0), 0])) + 4
    ox, oy = int(math.floor(x)) - m, int(math.floor(y)) - m
    lw, lh = int(math.ceil(w)) + 2 * m + 1, int(math.ceil(h)) + 2 * m + 1
    if lw * lh > 4000 * 4000: return
    layer = Image.new('RGBA', (lw, lh), (0, 0, 0, 0))
    iw, ih = max(1, int(round(w))), max(1, int(round(h)))
    r = it.get('corner') or 0
    lx, ly = int(round(x)) - ox, int(round(y)) - oy
    gradmul = sample(grad['c'], 0.5) if grad else (1, 1, 1)
    if has_bg:
        g = grad_layer(iw, ih, it.get('bg') or (1, 1, 1), 1 - bgT, grad)
        layer.paste(g, (lx, ly), rmask(iw, ih, r))
    if img_vis:
        ia = 1 - it['imgT']
        if it.get('tile'):
            tl = Image.new('RGBA', (iw, ih), (0, 0, 0, 0)); studs(tl, 0, 0, iw, ih, it.get('tileSize') or (iw, ih), ia * 0.9)
            layer.alpha_composite(Image.composite(tl, Image.new('RGBA', tl.size, (0, 0, 0, 0)), rmask(iw, ih, r)), (lx, ly))
        elif not has_bg:  # an icon / decal: placeholder
            d = ImageDraw.Draw(layer)
            d.rounded_rectangle([lx, ly, lx + iw - 1, ly + ih - 1], radius=max(2, min(iw, ih) * 0.2), fill=(255, 255, 255, int(70 * ia)), outline=(255, 255, 255, int(140 * ia)), width=1)
            d.line([lx + iw * 0.25, ly + ih * 0.75, lx + iw * 0.75, ly + ih * 0.25], fill=(255, 255, 255, int(120 * ia)), width=1)
    if it.get('vp'):
        d = ImageDraw.Draw(layer)
        d.ellipse([lx + iw * 0.2, ly + ih * 0.12, lx + iw * 0.8, ly + ih * 0.95], fill=(230, 120, 50, 200), outline=(90, 30, 10, 255), width=2)
    for s in strokes:  # Border strokes sit outside the box
        t = max(1, int(round(s['th']))); a = int(255 * (1 - s['tr']))
        ImageDraw.Draw(layer).rounded_rectangle([lx - t / 2, ly - t / 2, lx + iw - 1 + t / 2, ly + ih - 1 + t / 2], radius=r + t / 2 if r else 0, outline=c255(s['c']) + (a,), width=t)
    if it.get('text'):
        draw_text(layer, it, ox, oy, gradmul)
    if it.get('rot'):
        cxl, cyl = lx + iw / 2, ly + ih / 2
        layer = layer.rotate(-it['rot'], resample=Image.BICUBIC, center=(cxl, cyl))
    # clip (rounded when the innermost clipper has a UICorner)
    mask = Image.new('L', layer.size, 0); md = ImageDraw.Draw(mask)
    box = [cx0 - ox, cy0 - oy, cx1 - ox - 1, cy1 - oy - 1]
    if len(cl) > 4 and cl[4]:
        md.rounded_rectangle([cl[0] - ox, cl[1] - oy, cl[2] - ox - 1, cl[3] - oy - 1], radius=int(cl[4]), fill=255)
        inner = Image.new('L', layer.size, 0); ImageDraw.Draw(inner).rectangle(box, fill=255)
        mask = ImageChops.multiply(mask, inner)
    else:
        md.rectangle(box, fill=255)
    a = layer.getchannel('A')
    layer.putalpha(ImageChops.multiply(a, mask))
    # paste (crop to the canvas)
    sx0, sy0 = max(0, -ox), max(0, -oy)
    sx1, sy1 = min(lw, W - ox), min(lh, H - oy)
    if sx1 <= sx0 or sy1 <= sy0: return
    im.alpha_composite(layer.crop((sx0, sy0, sx1, sy1)), (ox + sx0, oy + sy0))

def main(js, out, crop=None):
    with open(js, encoding='utf-8') as fh: d = json.load(fh)
    W, H = d['W'], d['H']
    im = Image.new('RGBA', (W, H), (70, 22, 18, 255))
    ImageDraw.Draw(im).rectangle([0, 0, W, d.get('inset', 0) - 1], fill=(30, 30, 34, 255))  # Roblox top bar inset
    items = sorted(d['items'], key=lambda it: it.get('k') or [0])
    for it in items:
        render_item(im, it)
    tag = f"rig approx {W}x{H} {d.get('screen','')}{' touch' if d.get('touch') else ''} (rbxsim geometry, baked look; icons/3D = placeholders, NOT Studio)"
    _text(ImageDraw.Draw(im), (4, H - 13), tag, font(10), 'la', (255, 255, 0, 255))
    if crop:
        x, y, w, h = crop; im = im.crop((x, y, x + w, y + h))
    im.convert('RGB').save(out)
    print('wrote', out, im.size, len(items), 'items')

if __name__ == '__main__':
    if len(sys.argv) < 3: sys.exit('usage: render.py <dump.json> <out.png> [crop x,y,w,h]')
    main(sys.argv[1], sys.argv[2], tuple(map(int, sys.argv[3].split(','))) if len(sys.argv) > 3 else None)
