"""Procedural 'painted' UI pieces for the Gez interface concept.

Everything is a height map lit like metal, wood or enamel, so frames,
medallions and embossed icons get real bevels, highlights and shadows.
Pieces are rendered at 2x for crisp display.

Moved here from the claude.ai Project (claude/ui-art-concept.py) in
November 2026; used in Phase 20 (see docs/ROADMAP.md).
"""
import io, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
import cairosvg

OUT = 'out/'
rng = np.random.default_rng(1453)

LIGHT = np.array([-0.55, -0.65, 0.75]); LIGHT = LIGHT / np.linalg.norm(LIGHT)
HALF = (LIGHT + np.array([0, 0, 1])); HALF = HALF / np.linalg.norm(HALF)


def noise(h, w, scales):
    out = np.zeros((h, w))
    tot = 0
    for s, amp in scales:
        n = rng.random((h // s + 3, w // s + 3))
        im = Image.fromarray((n * 255).astype('uint8')).resize(((w // s + 3) * s, (h // s + 3) * s), Image.BICUBIC)
        out += np.asarray(im, dtype=float)[:h, :w] / 255 * amp
        tot += amp
    return out / tot


def normals(hmap, strength=1.0):
    gy, gx = np.gradient(hmap)
    n = np.dstack([-gx * strength, -gy * strength, np.ones_like(hmap)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def ramp(t, stops):
    """Map 0..1 to colour through a list of (pos, (r,g,b))."""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= p0) & (t <= p1)
        f = ((t - p0) / max(p1 - p0, 1e-6))[m][:, None]
        out[m] = np.array(c0) * (1 - f) + np.array(c1) * f
    return out


GOLD = [(0, (40, 24, 8)), (0.35, (122, 82, 28)), (0.6, (196, 148, 64)), (0.82, (238, 205, 128)), (1, (255, 246, 210))]
BRONZE = [(0, (30, 18, 8)), (0.35, (96, 60, 26)), (0.6, (160, 108, 52)), (0.85, (214, 170, 104)), (1, (250, 230, 190))]
IRON = [(0, (12, 12, 14)), (0.4, (44, 42, 44)), (0.7, (92, 88, 86)), (1, (190, 184, 172))]


def shade_metal(hmap, stops=GOLD, strength=2.0, wear=0.25, spec_pow=28, spec=0.9):
    hm = hmap + noise(*hmap.shape, [(3, 1), (1, .6)]) * wear * 0.6
    n = normals(hm, strength)
    diff = np.clip((n * LIGHT).sum(2), 0, 1)
    sp = np.clip((n * HALF).sum(2), 0, 1) ** spec_pow
    # metal: colour comes from the light; cavities darker (ambient occlusion from blurred height)
    ao = np.clip(hm - ndimage.gaussian_filter(hm, 6) + 0.6, 0.2, 1.0)
    t = 0.18 + diff * 0.62 * ao + sp * spec * 0.35
    col = ramp(t, stops)
    col += sp[..., None] * 60 * spec
    return np.clip(col, 0, 255)


def shade_matte(hmap, base, strength=1.5, spec=0.15):
    n = normals(hmap, strength)
    diff = np.clip((n * LIGHT).sum(2), 0, 1)
    sp = np.clip((n * HALF).sum(2), 0, 1) ** 12
    col = np.asarray(base, dtype=float) * (0.45 + 0.75 * diff[..., None]) + sp[..., None] * 255 * spec
    return np.clip(col, 0, 255)


def save(rgb, alpha, name, half=True):
    a = np.clip(alpha, 0, 1)
    im = Image.fromarray(np.dstack([rgb, a * 255]).astype('uint8'), 'RGBA')
    if half:
        im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    (im.convert('RGB') if name.endswith('.jpg') else im).save(OUT + name, **({'quality':90} if name.endswith('.jpg') else {}))
    return im


def svg_mask(path_d, size, stroke=2.2, fill=False, pad=0.0):
    vb = 24
    off = -pad
    span = vb + 2 * pad
    attrs = f'fill="{"#fff" if fill else "none"}" stroke="#fff" stroke-width="{stroke}" stroke-linecap="round" stroke-linejoin="round"'
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="{off} {off} {span} {span}"><path d="{path_d}" {attrs}/></svg>'
    png = cairosvg.svg2png(bytestring=svg.encode())
    im = Image.open(io.BytesIO(png)).convert('RGBA')
    return np.asarray(im, dtype=float)[..., 3] / 255


# ---------------------------------------------------------------- frames
def frame_profile(d, B):
    """Height across a border of width B, d = distance from outer edge."""
    h = np.zeros_like(d)
    # outer bead
    m = d < 0.22 * B
    h[m] = np.sin(np.clip(d[m] / (0.22 * B), 0, 1) * math.pi) * 0.7
    # channel
    m = (d >= 0.22 * B) & (d < 0.3 * B)
    h[m] = 0.1
    # main roll
    m = (d >= 0.3 * B) & (d < 0.82 * B)
    x = (d[m] - 0.3 * B) / (0.52 * B)
    h[m] = 0.25 + np.sin(x * math.pi) ** 0.8 * 0.85
    # inner step
    m = (d >= 0.82 * B) & (d < B)
    h[m] = 0.35 + 0.25 * (1 - (d[m] - 0.82 * B) / (0.18 * B))
    return h


def nine_frame(name, size, B, stops=GOLD, corner=True, inner_dark=True):
    S = size
    y, x = np.mgrid[0:S, 0:S].astype(float)
    d = np.minimum.reduce([x, y, S - 1 - x, S - 1 - y])
    along = np.where(np.minimum(y, S - 1 - y) < np.minimum(x, S - 1 - x), x, y)
    h = frame_profile(d, B)
    # beading on the outer bead, gadrooning (twisted ribs) on the main roll
    bead = (d < 0.22 * B)
    h[bead] *= 0.55 + 0.45 * np.abs(np.sin(along[bead] / (0.14 * B) * math.pi))
    roll = (d >= 0.3 * B) & (d < 0.82 * B)
    h[roll] += 0.14 * np.sin((along[roll] + d[roll] * 0.9) / (0.11 * B) * math.pi)
    alpha = (d < B).astype(float)
    if corner:
        R = B * 1.25
        for cx, cy in [(B * .62, B * .62), (S - 1 - B * .62, B * .62), (B * .62, S - 1 - B * .62), (S - 1 - B * .62, S - 1 - B * .62)]:
            r = np.hypot(x - cx, y - cy)
            m = r < R
            ang = np.arctan2(y - cy, x - cx)
            petals = 0.5 + 0.5 * np.cos(ang * 8)
            rose = np.where(r < R * 0.32, 1.25 - (r / (R * 0.32)) ** 2 * 0.35,
                    np.where(r < R * 0.42, 0.75, 0.55 + 0.55 * petals * (1 - (r - R * .42) / (R * .58))))
            edge = np.clip((R - r) / 2.0, 0, 1)
            h = np.where(m, np.maximum(h * (1 - edge), rose * edge + h * (1 - edge) * 0.3), h)
            alpha = np.maximum(alpha, edge)
    h = ndimage.gaussian_filter(h, 0.8)
    rgb = shade_metal(h * B * 0.12, stops, strength=1.0)
    # soft inner shadow edge
    a = alpha * np.clip((B + 1 - d), 0, 1) if not corner else alpha
    return save(rgb, a, name)


# ---------------------------------------------------------------- medallions
def medallion(name, size, icon=None, enamel=(46, 30, 20), stops=GOLD, rim=0.16, icon_scale=0.62, gem=False):
    S = size
    y, x = np.mgrid[0:S, 0:S].astype(float)
    c = (S - 1) / 2
    r = np.hypot(x - c, y - c) / (S / 2)
    alpha = np.clip((1 - r) * S / 3, 0, 1)
    rim_in = 1 - rim
    h = np.where(r > rim_in, np.sin(np.clip((1 - r) / rim, 0, 1) * math.pi) ** 0.7, 0.0)
    # beads around the rim
    ang = np.arctan2(y - c, x - c)
    beads = (r > rim_in + rim * .25) & (r < 1 - rim * .25)
    h[beads] *= 0.75 + 0.25 * np.abs(np.cos(ang[beads] * 14))
    dish = r <= rim_in
    rgb_metal = shade_metal(h * S * 0.08, stops, strength=1.0)
    # enamel dish, slightly concave, glossy
    dh = np.where(dish, (r / rim_in) ** 2 * 0.4, 0)
    enam = shade_matte(dh * S * 0.06, enamel, strength=1.0, spec=0.35)
    # vignette inside the dish
    enam *= (1 - 0.35 * (r / rim_in) ** 3)[..., None]
    rgb = np.where(dish[..., None], enam, rgb_metal)
    if icon is not None:
        isz = int(S * icon_scale)
        m = svg_mask(icon, isz, stroke=3.0)
        mm = np.zeros((S, S)); o = (S - isz) // 2
        mm[o:o + isz, o:o + isz] = m
        ih = ndimage.gaussian_filter(mm, S * 0.012) * 1.0
        icol = shade_metal(ih * S * 0.07, stops, strength=1.0, spec=1.0)
        # drop shadow of the raised icon on the enamel
        sh = ndimage.shift(ndimage.gaussian_filter(mm, S * 0.02), (S * 0.025, S * 0.02))
        rgb = np.where(dish[..., None], rgb * (1 - 0.55 * sh[..., None]), rgb)
        rgb = rgb * (1 - mm[..., None]) + icol * mm[..., None]
    if gem:
        pass
    return save(rgb, alpha, name)


def plaque(name, w, h, icon, enamel=(40, 28, 20), stops=GOLD):
    """Square-ish bevelled plaque with an embossed icon, for buildings."""
    y, x = np.mgrid[0:h, 0:w].astype(float)
    d = np.minimum.reduce([x, y, w - 1 - x, h - 1 - y])
    B = w * 0.09
    hm = np.where(d < B, np.sin(np.clip(d / B, 0, 1) * math.pi * 0.5 + 0.0) * 0.6 + 0.4 * (d < B * .4), 0)
    rgb_m = shade_metal(hm * w * 0.05, stops, strength=1.0)
    inner = d >= B
    yy = (y - h / 2) / (h / 2); xx = (x - w / 2) / (w / 2)
    dome = 1 - (xx ** 2 + yy ** 2) * 0.5
    en = shade_matte(dome * w * 0.04, enamel, strength=1.0, spec=0.25)
    en *= (0.65 + 0.35 * np.clip(dome, 0, 1))[..., None]
    rgb = np.where(inner[..., None], en, rgb_m)
    isz = int(min(w, h) * 0.62)
    m = svg_mask(icon, isz, stroke=2.8)
    mm = np.zeros((h, w)); ox = (w - isz) // 2; oy = (h - isz) // 2
    mm[oy:oy + isz, ox:ox + isz] = m
    ih = ndimage.gaussian_filter(mm, w * 0.012)
    icol = shade_metal(ih * w * 0.07, stops, strength=1.0, spec=1.0)
    sh = ndimage.shift(ndimage.gaussian_filter(mm, w * 0.02), (w * 0.025, w * 0.02))
    rgb = np.where(inner[..., None], rgb * (1 - 0.55 * sh[..., None]), rgb)
    rgb = rgb * (1 - mm[..., None]) + icol * mm[..., None]
    corner = np.ones((h, w))
    return save(rgb, corner, name)


# ---------------------------------------------------------------- wood bar
def wood(h, w, dark=(58, 36, 22)):
    n = noise(h, w * 1, [(1, 0.2)])
    grain = noise(h, w // 6 + 1, [(4, 2), (1, 1)])
    grain = np.asarray(Image.fromarray((grain * 255).astype('uint8')).resize((w, h), Image.BICUBIC), float) / 255
    rings = np.sin((grain * 18 + np.linspace(0, 3, h)[:, None]) * math.pi) * 0.5 + 0.5
    t = rings * 0.6 + n * 0.4
    base = np.array(dark, float)
    col = base[None, None, :] * (0.7 + 0.5 * t[..., None])
    return col, rings


def top_bar(name, W, H):
    y = np.arange(H)[:, None].repeat(W, 1).astype(float)
    x = np.arange(W)[None, :].repeat(H, 0).astype(float)
    Mb = int(H * 0.2); Mt = int(H * 0.07)
    # tooled leather body
    n = noise(H, W, [(40, 2), (10, 2), (3, 1.5), (1, 1)])
    hm = ndimage.gaussian_filter(n, 1.0) * 0.6
    # tooled double lines and a running lozenge pattern
    top_line = Mt + H * 0.08; bot_line = H - Mb - H * 0.08
    for yy in [top_line, top_line + 5, bot_line - 5, bot_line]:
        hm -= 0.35 * np.exp(-((y - yy) / 1.2) ** 2)
    mid = (top_line + bot_line) / 2
    band = (y > top_line + 9) & (y < bot_line - 9)
    per = 64.0
    u = (x % per) / per - 0.5
    v = (y - mid) / ((bot_line - top_line) / 2 - 9)
    lozenge = np.abs(np.abs(u) * 2 + np.abs(v) - 0.9) < 0.05
    hm -= 0.25 * (lozenge & band)
    lit = shade_matte(hm * 8, (64, 40, 28), strength=1.0, spec=0.06)
    col = lit * (1.0 - 0.3 * (y / H))[..., None]
    gh = np.zeros((H, W))
    db = (H - 1 - y)
    mb = db < Mb
    gh[mb] = frame_profile(db[mb], Mb)
    beadz = db < 0.22 * Mb
    gh[beadz] *= 0.55 + 0.45 * np.abs(np.sin(x[beadz] / (0.3 * Mb) * math.pi))
    roll = mb & (db >= 0.3 * Mb) & (db < 0.82 * Mb)
    gh[roll] += 0.14 * np.sin((x[roll] + db[roll]) / (0.2 * Mb) * math.pi)
    mt = y < Mt
    gh[mt] = np.sin(np.clip(y[mt] / Mt, 0, 1) * math.pi) * 0.8
    gold = shade_metal(ndimage.gaussian_filter(gh, .8) * Mb * 0.12, GOLD, strength=1.0)
    m = (mb | mt)[..., None]
    rgb = np.where(m, gold, col)
    sh = np.clip(1 - (y - Mt) / (H * 0.2), 0, 1) * (y >= Mt)
    sh2 = np.clip(1 - (H - Mb - y) / (H * 0.12), 0, 1) * (y < H - Mb)
    rgb = rgb * (1 - 0.5 * np.maximum(sh, sh2)[..., None] * (~m))
    return save(rgb, np.ones((H, W)), name)


def shield_frame(name, w, h):
    """Gold bevelled shield outline; transparent window for the arms."""
    sc = 4
    def shape(inset):
        im = Image.new('L', (w * sc, h * sc), 0)
        dr = ImageDraw.Draw(im)
        i = inset * sc
        W, H = w * sc, h * sc
        pts = []
        for t in np.linspace(0, 1, 60):
            pts.append((i + (W / 2 - i) * t, H * 0.48 + (H - i * 1.4 - H * 0.48) * math.sin(t * math.pi / 2)))
        left = [(i, i)] + pts
        right = [(W - x, y) for x, y in reversed(pts)] + [(W - i, i)]
        dr.polygon(left + right, fill=255)
        return np.asarray(im.resize((w, h), Image.LANCZOS), float) / 255
    outer = shape(0); inner = shape(w * 0.09)
    ring = np.clip(outer - inner, 0, 1)
    dist = ndimage.distance_transform_edt(ring > 0.5)
    hm = np.sin(np.clip(dist / (w * 0.045), 0, 1) * math.pi * 0.5)
    y, x = np.mgrid[0:h, 0:w].astype(float)
    hm += 0.15 * np.sin(np.arctan2(y - h / 2, x - w / 2) * 22) * (dist > w * 0.03)
    rgb = shade_metal(ndimage.gaussian_filter(hm, 1) * w * 0.05, GOLD, strength=1.0)
    return save(rgb, ring, name)


def banner(name, w, h, base=(128, 26, 20)):
    """Red cloth ribbon with folded swallow-tail ends."""
    y, x = np.mgrid[0:h, 0:w].astype(float)
    tail = w * 0.07
    # shape: body plus notched ends
    cy = h / 2
    notch = tail * (1 - np.abs(y - cy) / cy)
    a = ((x > notch) & (x < w - notch)).astype(float)
    a = ndimage.gaussian_filter(a, 0.8)
    # folds: vertical-ish sine creases and a curve
    fold = 0.5 + 0.5 * np.sin(x / w * math.pi * 7 + np.sin(y / h * math.pi) * 0.6)
    sag = np.sin(x / w * math.pi) * 0.3
    hm = fold * 0.35 + (1 - ((y - cy) / cy) ** 2) * 0.6 + sag
    # ends folded back: darker
    end = (x < tail * 1.6) | (x > w - tail * 1.6)
    hm = ndimage.gaussian_filter(hm, 2)
    weave = noise(h, w, [(1, 1)]) * 0.05
    rgb = shade_matte((hm + weave) * h * 0.25, base, strength=1.0, spec=0.18)
    rgb[end] *= 0.72
    # gold stitched border lines
    for yy in [h * 0.12, h * 0.88]:
        m = np.abs(y - yy) < 1.2
        rgb[m & ~end] = rgb[m & ~end] * 0.3 + np.array([230, 190, 110]) * 0.7
    return save(rgb, a, name)


def parchment(name, W, H, burn=True):
    n = noise(H, W, [(160, 3), (40, 2), (10, 1), (2, .5)])
    stains = noise(H, W, [(90, 1)])
    base = np.array([238, 223, 188]); dark = np.array([196, 166, 116])
    t = n * 0.6 + np.clip(stains - 0.55, 0, 1) * 1.2
    rgb = base * (1 - t[..., None] * 0.55) + dark * (t[..., None] * 0.55)
    y, x = np.mgrid[0:H, 0:W].astype(float)
    d = np.minimum.reduce([x, y, W - 1 - x, H - 1 - y]) / min(W, H)
    vig = np.clip(d * 6, 0, 1) ** 0.6
    rgb *= (0.62 + 0.38 * vig)[..., None]
    fib = noise(H, W, [(1, 1)])
    rgb += (fib[..., None] - .5) * 14
    return save(np.clip(rgb, 0, 255), np.ones((H, W)), name, half=False)


def leather(name, W, H, base=(58, 34, 24)):
    n = noise(H, W, [(48, 2), (12, 2), (3, 1.5), (1, 1)])
    hm = ndimage.gaussian_filter(n, 1.0)
    rgb = shade_matte(hm * 10, base, strength=1.0, spec=0.08)
    rgb *= (0.85 + 0.3 * noise(H, W, [(120, 1)]))[..., None]
    return save(rgb, np.ones((H, W)), name, half=False)


def wax_seal(name, size, base):
    S = size
    y, x = np.mgrid[0:S, 0:S].astype(float)
    c = (S - 1) / 2
    ang = np.arctan2(y - c, x - c)
    r = np.hypot(x - c, y - c) / (S / 2)
    edge = 0.9 + 0.06 * np.sin(ang * 9) + 0.03 * np.sin(ang * 23 + 1)
    a = np.clip((edge - r) * S / 3, 0, 1)
    hm = np.where(r < edge, np.sqrt(np.clip(1 - (r / edge) ** 2, 0, 1)), 0)
    ring = (r > 0.55) & (r < 0.66)
    hm[ring] -= 0.18
    hm += (r < 0.45) * 0.05
    rgb = shade_matte(ndimage.gaussian_filter(hm, 1) * S * 0.25, base, strength=1.0, spec=0.45)
    return save(rgb, a, name)


def portrait_frame(name, w, h):
    """Arched gold frame for a portrait; transparent window."""
    y, x = np.mgrid[0:h, 0:w].astype(float)
    def inside(inset):
        r = w / 2 - inset
        cx = w / 2; cy = r + inset
        arch = (y < cy) & (np.hypot(x - cx, y - cy) <= r)
        body = (y >= cy) & (x >= inset) & (x <= w - inset) & (y <= h - inset)
        return arch | body
    outer = inside(0); inner = inside(w * 0.075)
    ring = outer & ~inner
    dist = ndimage.distance_transform_edt(ring)
    B = w * 0.075
    hm = frame_profile(dist, B)
    ang = np.arctan2(y - w / 2, x - w / 2)
    hm += 0.12 * np.sin((dist + (x + y) * 0.5) / (B * 0.18) * math.pi) * ((dist > B * .3) & (dist < B * .82))
    rgb = shade_metal(ndimage.gaussian_filter(hm, .8) * B * 0.12, GOLD, strength=1.0)
    a = ndimage.gaussian_filter(ring.astype(float), 0.6)
    return save(rgb, a, name)


# ---------------------------------------------------------------- build all pieces
if __name__ == '__main__':
    import os; os.makedirs(OUT, exist_ok=True)
    I = {
     'coin':'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18M12 6.5v11M15 9h-4.5a2 2 0 0 0 0 4h3a2 2 0 0 1 0 4H9',
     'bag':'M8 7l2-3h4l2 3M5 21l2-14h10l2 14z',
     'crown':'M3 8l4 4 5-7 5 7 4-4-2 11H5z',
     'people':'M8 11a3 3 0 1 0 0-.1M16 11a3 3 0 1 0 0-.1M3 20c0-3 2-5 5-5s5 2 5 5M11 20c0-3 2-5 5-5s5 2 5 5',
     'ledger':'M5 3h12a2 2 0 0 1 2 2v16H7a2 2 0 0 1-2-2zM9 8h6M9 12h6M9 16h4',
     'ship':'M3 16h18l-3 4H6zM12 3v13M12 4l6 9h-6M12 6l-5 7h5',
     'column':'M4 21h16M5 9h14M12 3l8 4H4zM7 9v10M12 9v10M17 9v10',
     'flag':'M5 21V4M5 4h11l-2 4 2 4H5',
     'grid':'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
     'mountain':'M3 20l6-11 4 6 3-4 5 9z',
     'dome':'M4 20h16M6 20v-7a6 6 0 0 1 12 0v7M12 7V3M10 4h4',
     'bars':'M5 20V12M10 20V8M15 20v-5M20 20V5',
     'box':'M3 8l9-5 9 5v8l-9 5-9-5zM3 8l9 5 9-5M12 13v8',
     'tower':'M4 21V9h3V6h2v3h2V6h2v3h2V6h2v3h3v12zM10 21v-4h4v4',
     'wheat':'M12 21V8M12 8c-3 0-4-2-4-5 3 0 4 2 4 5zM12 8c3 0 4-2 4-5-3 0-4 2-4 5zM12 13c-3 0-4-2-4-5M12 13c3 0 4-2 4-5M12 18c-3 0-4-2-4-5M12 18c3 0 4-2 4-5',
     'area':'M4 4h16v16H4zM4 9h16M9 4v16',
     'spool':'M7 4h10M7 20h10M8 4c0 5 8 5 8 0M8 20c0-5 8-5 8 0M9 9l6 6M15 9l-6 6',
     'shield':'M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6z',
     'hide':'M6 4c2 2 10 2 12 0l-1 6 2 6c-3 0-4 2-5 4h-4c-1-2-2-4-5-4l2-6z',
     'stall':'M3 9l2-5h14l2 5M3 9h18M5 9v11h14V9M9 20v-6h6v6',
     'anchor':'M12 7v13M8 10h8M5 14c0 4 3 6 7 6s7-2 7-6M12 3a2 2 0 1 1 0 4a2 2 0 1 1 0-4',
     'church':'M12 2v5M10 4h4M6 21V11l6-4 6 4v10M10 21v-5h4v5',
     'book':'M4 5h7a1 1 0 0 1 1 1v14a1 1 0 0 0-1-1H4zM20 5h-7a1 1 0 0 0-1 1v14a1 1 0 0 1 1-1h7z',
     'close':'M6 6l12 12M18 6L6 18',
     'pause':'M9 5v14M15 5v14',
    }
    nine_frame('frame_gold.png', 240, 26)
    nine_frame('frame_small.png', 80, 9, corner=False)
    top_bar('topbar.png', 2880, 172)
    shield_frame('shield_frame.png', 152, 184)
    shield_frame('shield_frame_s.png', 104, 126)
    banner('banner.png', 760, 92)
    parchment('parchment.jpg', 512, 512)
    leather('leather.png', 512, 512)
    portrait_frame('portrait_frame.png', 260, 320)
    for k in ['flag','grid','mountain','dome','people','bars','box','bag']:
        medallion(f'mode_{k}.png', 104, I[k])
    medallion('mode_flag_on.png', 104, I['flag'], enamel=(140,30,22))
    for k in ['coin','bag','crown']:
        medallion(f'chip_{k}.png', 88, I[k], enamel=(30,40,52))
    for k in ['ledger','ship','crown','column']:
        medallion(f'nav_{k}.png', 92, I[k], stops=BRONZE, enamel=(36,26,18))
    medallion('btn_close.png', 60, I['close'], icon_scale=.5)
    medallion('btn_pause.png', 64, I['pause'], icon_scale=.5, enamel=(140,30,22))
    for k in ['bars','tower','wheat','area']:
        medallion(f'stat_{k}.png', 68, I[k], stops=BRONZE, enamel=(84,52,28))
    for k in ['spool','shield','hide','stall','anchor','church','book','tower','ship']:
        plaque(f'bld_{k}.png', 104, 104, I[k], enamel=(44,30,20))
    for k,c in {'gold':(176,120,40),'red':(150,34,26),'blue':(40,76,112),'black':(52,36,36),'green':(70,100,50)}.items():
        wax_seal(f'seal_{k}.png', 56, c)
    # gold button (nine-slice)
    def button(name,w,h,stops):
        y,x=np.mgrid[0:h,0:w].astype(float); d=np.minimum.reduce([x,y,w-1-x,h-1-y]); B=h*0.18
        hm=np.where(d<B,np.sin(np.clip(d/B,0,1)*math.pi/2),1.0)+ (1-((y-h/2)/(h/2))**2)*0.25
        rgb=shade_metal(ndimage.gaussian_filter(hm,1)*h*0.08,stops,strength=1.0,wear=0.15)
        return save(rgb,np.ones((h,w)),name)
    button('button_gold.png',240,72,GOLD)
    print('done')
