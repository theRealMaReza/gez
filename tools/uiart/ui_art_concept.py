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


# ---------------------------------------------------------------- icons
ICONS = {
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

     # Added for the Phase 20 style kit (our own drawings on a 24-unit grid).
     'scales':'M12 3v18M7 21h10M4 7h16M6 7l-3 7a3 3 0 0 0 6 0zM18 7l-3 7a3 3 0 0 0 6 0z',
     'torch':'M10 21l1-9h2l1 9zM9 12h6M12 3c2 2 3 3 3 5a3 3 0 0 1-6 0c0-1 1-2 1-3 1 1 1 2 2 2 0-2-1-3 0-4z',
     'astrolabe':'M12 5a8 8 0 1 0 0 16a8 8 0 1 0 0-16M12 9a4 4 0 1 0 0 8a4 4 0 1 0 0-8M4 13h16M12 2v3M6 19l12-12',
     'scroll':'M7 4h11a2 2 0 0 1 0 4h-1v10a2 2 0 0 1-2 2H6a2 2 0 0 1 0-4h1zM7 16V4M10 8h4M10 11h4',
     'swords':'M4 4l12 12M13 19l6-6M16 16l4 4M20 4L8 16M5 13l6 6M8 16l-4 4',
     'helmet':'M4 15a8 8 0 0 1 16 0v4H4zM12 7V3M10 3h4M4 15h16M12 15v4',
     'menu':'M5 7h14M5 12h14M5 17h14',
     'play':'M8 5l11 7-11 7z',
     'rings':'M9 8a5 5 0 1 0 0 10a5 5 0 1 0 0-10M15 6a5 5 0 1 0 0 10a5 5 0 1 0 0-10',
     'skull':'M12 3a7 7 0 0 0-7 7c0 3 2 4 2 6v2h10v-2c0-2 2-3 2-6a7 7 0 0 0-7-7zM9 10.5a1.2 1.2 0 1 0 0 .1M15 10.5a1.2 1.2 0 1 0 0 .1M10 18v3M14 18v3',
     'quill':'M20 3c-7 1-12 6-13 14l-2 4M20 3c-1 5-5 9-10 10M10 13h4',
     'hourglass':'M6 3h12M6 21h12M7 3v2c0 4 10 5 10 9v7M17 3v2c0 4-10 5-10 9v7',
     'plus':'M12 5v14M5 12h14',
     'minus':'M5 12h14',
     'fit':'M4 9V4h5M15 4h5v5M20 15v5h-5M9 20H4v-5',
     'hammer':'M14 3l7 7-3 3-7-7zM12 8l-8 8 3 3 8-8',
     'coin_down':'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18M12 7v8M8.5 11.5l3.5 3.5 3.5-3.5',
     'globe':'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18M3 12h18M12 3c3.5 3 3.5 15 0 18M12 3c-3.5 3-3.5 15 0 18',
     'bell':'M6 17v-6a6 6 0 0 1 12 0v6l2 2H4zM10 21h4',
     'star':'M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6-5.3-3-5.3 3 1.2-6-4.5-4.1 6-.7z',
     'check':'M5 12l5 5 9-10',
     'sword':'M18 3h3v3L9 18l-3-3zM5 14l5 5M7 17l-4 4',
     'eye':'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6',
     'gavel':'M13 4l5 5M11 6l5 5M12 5l-4 4 3 3 4-4M9.5 10.5L3 17l2 2 6.5-6.5M14 20h7',
    }

# ---------------------------------------------------------------- concept pieces
def build_concept():
    """The original concept pieces (out/), as shown on the concept canvas."""
    import os; os.makedirs(OUT, exist_ok=True)
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
        medallion(f'mode_{k}.png', 104, ICONS[k])
    medallion('mode_flag_on.png', 104, ICONS['flag'], enamel=(140,30,22))
    for k in ['coin','bag','crown']:
        medallion(f'chip_{k}.png', 88, ICONS[k], enamel=(30,40,52))
    for k in ['ledger','ship','crown','column']:
        medallion(f'nav_{k}.png', 92, ICONS[k], stops=BRONZE, enamel=(36,26,18))
    medallion('btn_close.png', 60, ICONS['close'], icon_scale=.5)
    medallion('btn_pause.png', 64, ICONS['pause'], icon_scale=.5, enamel=(140,30,22))
    for k in ['bars','tower','wheat','area']:
        medallion(f'stat_{k}.png', 68, ICONS[k], stops=BRONZE, enamel=(84,52,28))
    for k in ['spool','shield','hide','stall','anchor','church','book','tower','ship']:
        plaque(f'bld_{k}.png', 104, 104, ICONS[k], enamel=(44,30,20))
    for k,c in {'gold':(176,120,40),'red':(150,34,26),'blue':(40,76,112),'black':(52,36,36),'green':(70,100,50)}.items():
        wax_seal(f'seal_{k}.png', 56, c)
    # gold button (nine-slice)
    def button(name,w,h,stops):
        y,x=np.mgrid[0:h,0:w].astype(float); d=np.minimum.reduce([x,y,w-1-x,h-1-y]); B=h*0.18
        hm=np.where(d<B,np.sin(np.clip(d/B,0,1)*math.pi/2),1.0)+ (1-((y-h/2)/(h/2))**2)*0.25
        rgb=shade_metal(ndimage.gaussian_filter(hm,1)*h*0.08,stops,strength=1.0,wear=0.15)
        return save(rgb,np.ones((h,w)),name)
    button('button_gold.png',240,72,GOLD)


# ---------------------------------------------------------------- Phase 20 style kit
# Production pieces for the Godot Theme (godot/assets/ui/). Everything is
# drawn at 2x and halved (crisp edges), except tiling textures, which are
# made periodic so they repeat without seams.

def periodic_noise(h, w, beta=2.2, seed=0):
    """Seamless 0..1 noise (filtered white noise via FFT, so it tiles)."""
    g = np.random.default_rng(seed)
    white = g.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]; fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx ** 2 + fy ** 2); f[0, 0] = 1
    spec = np.fft.fft2(white) / f ** (beta / 2)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    n = (n - n.min()) / (n.max() - n.min())
    return n


PARCH = np.array([236, 220, 184]); PARCH_DARK = np.array([196, 164, 114])
INK = (58, 36, 20)


def parchment_tile(h, w, seed=11):
    """Seamless parchment (no burnt edges): the page inside every panel."""
    n = periodic_noise(h, w, 2.4, seed) * 0.7 + periodic_noise(h, w, 1.2, seed + 1) * 0.3
    stains = periodic_noise(h, w, 3.0, seed + 2)
    t = (n - 0.5) * 0.5 + 0.25 + np.clip(stains - 0.62, 0, 1) * 1.4
    rgb = PARCH * (1 - t[..., None] * 0.5) + PARCH_DARK * (t[..., None] * 0.5)
    fib = periodic_noise(h, w, 0.2, seed + 3)
    rgb += (fib[..., None] - .5) * 10
    return np.clip(rgb, 0, 255)


def leather_tile(h, w, base=(62, 37, 25), seed=21):
    n = periodic_noise(h, w, 1.6, seed) * 0.5 + periodic_noise(h, w, 0.6, seed + 1) * 0.5
    hm = n
    rgb = shade_matte(hm * 9, base, strength=1.0, spec=0.06)
    rgb *= (0.86 + 0.28 * periodic_noise(h, w, 3.0, seed + 2))[..., None]
    return np.clip(rgb, 0, 255)


def _save_rgba(rgb, alpha, path):
    im = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 1) * 255]).astype('uint8'), 'RGBA')
    im.save(path, optimize=True)
    return im


def _half(rgb, alpha):
    im = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 1) * 255]).astype('uint8'), 'RGBA')
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    a = np.asarray(im, float)
    return a[..., :3], a[..., 3] / 255


def gold_rope(d, along, B, period):
    """Height of a gold moulding of width B (2x px) at distance d from its
    outer edge; the twist repeats every `period` px along the edge."""
    h = frame_profile(d, B)
    bead = d < 0.22 * B
    h[bead] *= 0.55 + 0.45 * np.abs(np.sin(along[bead] / (period / 2) * math.pi))
    roll = (d >= 0.3 * B) & (d < 0.82 * B)
    h[roll] += 0.14 * np.sin((along[roll] + d[roll] * 0.9) / (period / 2) * math.pi * 2)
    return h


def framed_box(path, center, gold, leather_w=0, bead=0, rosettes=True, page='parchment',
               page_alpha=1.0, seed=31):
    """Nine-slice box: gold rope frame (+ optional leather band and inner
    gold bead) around a seamless page. Sizes in 1x px; returns the margin.
    The middle of each edge is a whole number of twist periods, so Godot
    can tile it (axis stretch TILE_FIT)."""
    M = gold + leather_w + bead
    S = 2 * M + center
    S2 = S * 2; G2 = gold * 2; L2 = leather_w * 2; D2 = bead * 2
    y, x = np.mgrid[0:S2, 0:S2].astype(float)
    d = np.minimum.reduce([x, y, S2 - 1 - x, S2 - 1 - y])
    along = np.where(np.minimum(y, S2 - 1 - y) < np.minimum(x, S2 - 1 - x), x, y) - 2 * M
    period = center * 2 / max(1, round(center * 2 / (G2 * 0.9)))
    h = np.zeros((S2, S2))
    gm = d < G2
    h[gm] = gold_rope(d[gm], along[gm], G2, period)
    alpha = np.zeros((S2, S2))
    alpha[d < 2 * M] = 1
    if rosettes:
        R = G2 * 1.25
        for cx, cy in [(G2 * .62, G2 * .62), (S2 - 1 - G2 * .62, G2 * .62), (G2 * .62, S2 - 1 - G2 * .62), (S2 - 1 - G2 * .62, S2 - 1 - G2 * .62)]:
            r = np.hypot(x - cx, y - cy)
            ang = np.arctan2(y - cy, x - cx)
            petals = 0.5 + 0.5 * np.cos(ang * 8)
            rose = np.where(r < R * 0.32, 1.25 - (r / (R * 0.32)) ** 2 * 0.35,
                    np.where(r < R * 0.42, 0.75, 0.55 + 0.55 * petals * (1 - (r - R * .42) / (R * .58))))
            edge = np.clip((R - r) / 2.0, 0, 1)
            h = np.where(r < R, np.maximum(h * (1 - edge), rose * edge + h * (1 - edge) * 0.3), h)
            gm = gm | (r < R)
    bm = (d >= G2 + L2) & (d < 2 * M)
    if bead:
        db = d[bm] - (G2 + L2)
        h[bm] = np.sin(np.clip(db / D2, 0, 1) * math.pi) * 0.8 * (0.7 + 0.3 * np.abs(np.sin(along[bm] / (period / 4) * math.pi)))
    metal = gm | bm
    h = ndimage.gaussian_filter(h, 0.8)
    gold_rgb = shade_metal(h * G2 * 0.12, GOLD, strength=1.0)
    rgb = np.zeros((S2, S2, 3))
    if leather_w:
        lt = leather_tile(S2, S2, seed=seed)
        lt = np.roll(lt, (2 * M, 2 * M), axis=(0, 1))
        lm = (d >= G2) & (d < G2 + L2)
        # leather sinks below the frame: shade near both mouldings
        dl = d - G2
        shade = 1 - 0.45 * np.exp(-dl / 5) - 0.35 * np.exp(-(G2 + L2 - d) / 4)
        rgb[lm] = lt[lm] * shade[lm][:, None]
    rgb[metal] = gold_rgb[metal]
    rgb2, a2 = _half(rgb, alpha)
    # page (1x, seamless), pasted into the centre and under the border
    if page == 'parchment':
        tile = parchment_tile(center, center, seed)
        pg = np.zeros((S, S, 3))
        pg[M:M + center, M:M + center] = tile
        # a soft shadow cast by the frame onto the page
        yy, xx = np.mgrid[0:S, 0:S].astype(float)
        dd = np.minimum.reduce([xx, yy, S - 1 - xx, S - 1 - yy]) - M
        # (only inside the border, so the centre tile stays seamless)
        rgb2 = np.where((dd < 0)[..., None], rgb2, pg)
        a2 = np.where(dd < 0, a2, page_alpha)
    _save_rgba(rgb2, a2, path)
    return M


def strip(path, length, thick, moulding='bottom', base=(64, 40, 28), seed=41, lozenge=True):
    """Tooled leather strip (top bar or side column) with gold mouldings,
    seamless along its length. Drawn horizontally; rotated for 'right'."""
    W2, H2 = length * 2, thick * 2
    y = np.arange(H2)[:, None].repeat(W2, 1).astype(float)
    x = np.arange(W2)[None, :].repeat(H2, 0).astype(float)
    Mb = int(H2 * 0.2); Mt = int(H2 * 0.07)
    n = periodic_noise(H2, W2, 1.4, seed) * 0.6 + periodic_noise(H2, W2, 0.5, seed + 1) * 0.4
    hm = ndimage.gaussian_filter(n, 1.0) * 0.6
    top_line = Mt + H2 * 0.1; bot_line = H2 - Mb - H2 * 0.1
    for yy in [top_line, top_line + 5, bot_line - 5, bot_line]:
        hm -= 0.35 * np.exp(-((y - yy) / 1.2) ** 2)
    if lozenge:
        mid = (top_line + bot_line) / 2
        band = (y > top_line + 9) & (y < bot_line - 9)
        per = W2 / round(W2 / 64)
        u = (x % per) / per - 0.5
        v = (y - mid) / max(1, (bot_line - top_line) / 2 - 9)
        loz = np.abs(np.abs(u) * 2 + np.abs(v) - 0.9) < 0.05
        hm -= 0.25 * (loz & band)
    col = shade_matte(hm * 8, base, strength=1.0, spec=0.06)
    col = col * (1.0 - 0.25 * (y / H2))[..., None]
    gh = np.zeros((H2, W2))
    db = (H2 - 1 - y)
    mb = db < Mb
    per = W2 / round(W2 / (Mb * 0.9))
    gh[mb] = gold_rope(db[mb], x[mb], Mb, per)
    mt = y < Mt
    gh[mt] = np.sin(np.clip(y[mt] / Mt, 0, 1) * math.pi) * 0.8
    gold = shade_metal(ndimage.gaussian_filter(gh, .8) * Mb * 0.12, GOLD, strength=1.0)
    m = (mb | mt)[..., None]
    rgb = np.where(m, gold, col)
    sh = np.clip(1 - (y - Mt) / (H2 * 0.2), 0, 1) * (y >= Mt)
    sh2 = np.clip(1 - (H2 - Mb - y) / (H2 * 0.12), 0, 1) * (y < H2 - Mb)
    rgb = rgb * (1 - 0.5 * np.maximum(sh, sh2)[..., None] * (~m))
    rgb, a = _half(rgb, np.ones((H2, W2)))
    if moulding == 'right':
        rgb = np.rot90(rgb, 1); a = np.rot90(a, 1)   # bottom edge becomes the right edge
    _save_rgba(rgb, a, path)


def gold_button(path, w, h, state='normal'):
    W2, H2 = w * 2, h * 2
    y, x = np.mgrid[0:H2, 0:W2].astype(float)
    d = np.minimum.reduce([x, y, W2 - 1 - x, H2 - 1 - y]); B = H2 * 0.2
    dome = (1 - ((y - H2 / 2) / (H2 / 2)) ** 2) * 0.25
    if state == 'pressed':
        dome = -dome
    hm = np.where(d < B, np.sin(np.clip(d / B, 0, 1) * math.pi / 2), 1.0) + dome
    stops = GOLD
    if state == 'hover':
        stops = [(p, tuple(min(255, c * 1.12 + 8) for c in col)) for p, col in GOLD]
    if state == 'pressed':
        stops = [(p, tuple(c * 0.86 for c in col)) for p, col in GOLD]
    if state == 'disabled':
        stops = [(p, tuple((sum(col) / 3) * 0.75 + col[0] * 0.1 for _ in col)) for p, col in GOLD]
    rgb = shade_metal(ndimage.gaussian_filter(hm, 1) * H2 * 0.08, stops, strength=1.0, wear=0.15)
    # rounded corners
    r = 6.0
    cx = np.clip(x, r, W2 - 1 - r); cy = np.clip(y, r, H2 - 1 - r)
    a = np.clip(r + 0.5 - np.hypot(x - cx, y - cy), 0, 1)
    rgb2, a2 = _half(rgb, a)
    _save_rgba(rgb2, a2, path)


def leather_button(path, w, h, state='normal'):
    """Dark tooled-leather tab with a thin gold edge (tabs, toggles)."""
    W2, H2 = w * 2, h * 2
    y, x = np.mgrid[0:H2, 0:W2].astype(float)
    d = np.minimum.reduce([x, y, W2 - 1 - x, H2 - 1 - y])
    base = {'normal': (70, 44, 30), 'hover': (92, 58, 38), 'pressed': (126, 30, 22), 'disabled': (70, 62, 56)}[state]
    lt = leather_tile(H2, W2, base, seed=51)
    ring = d < 4
    gh = np.where(ring, np.sin(np.clip(d / 4, 0, 1) * math.pi), 0)
    gold = shade_metal(gh * 3, GOLD, strength=1.0)
    rgb = np.where(ring[..., None], gold, lt * (1 - 0.35 * np.exp(-(d - 4) / 5))[..., None])
    r = 6.0
    cx = np.clip(x, r, W2 - 1 - r); cy = np.clip(y, r, H2 - 1 - r)
    a = np.clip(r + 0.5 - np.hypot(x - cx, y - cy), 0, 1)
    rgb2, a2 = _half(rgb, a)
    _save_rgba(rgb2, a2, path)


def title_banner(path, w, h):
    """Red cloth ribbon with swallow-tail ends (nine-slice horizontally)."""
    W2, H2 = w * 2, h * 2
    y, x = np.mgrid[0:H2, 0:W2].astype(float)
    tail = H2 * 0.55
    cy = H2 / 2
    notch = tail * 0.55 * (1 - np.abs(y - cy) / cy)
    a = ((x > notch) & (x < W2 - notch)).astype(float)
    a = ndimage.gaussian_filter(a, 0.8)
    mid = (x > tail * 1.4) & (x < W2 - tail * 1.4)
    hm = (1 - ((y - cy) / cy) ** 2) * 0.6
    hm = ndimage.gaussian_filter(hm, 2)
    weave = noise(H2, W2, [(1, 1)]) * 0.05
    rgb = shade_matte((hm + weave) * H2 * 0.25, (132, 28, 22), strength=1.0, spec=0.16)
    end = ~mid
    rgb[end] *= 0.72
    for yy in [H2 * 0.13, H2 * 0.87]:
        m = np.abs(y - yy) < 1.3
        rgb[m & mid] = rgb[m & mid] * 0.3 + np.array([230, 190, 110]) * 0.7
    rgb2, a2 = _half(rgb, a)
    _save_rgba(rgb2, a2, path)


def plain_medallion(path, size, enamel=(46, 30, 20), stops=GOLD):
    """Empty domed medallion (slider grabber, check box)."""
    global OUT
    keep = OUT; OUT = ''
    medallion(path, size * 2, None, enamel=enamel, stops=stops)
    OUT = keep


def icon_medallion(path, size, icon, enamel=(46, 30, 20), stops=GOLD, icon_scale=0.6):
    global OUT
    keep = OUT; OUT = ''
    medallion(path, size * 2, icon, enamel=enamel, stops=stops, icon_scale=icon_scale)
    OUT = keep


def check_box(path, size, checked):
    S2 = size * 2
    y, x = np.mgrid[0:S2, 0:S2].astype(float)
    d = np.minimum.reduce([x, y, S2 - 1 - x, S2 - 1 - y])
    B = S2 * 0.16
    h = np.where(d < B, np.sin(np.clip(d / B, 0, 1) * math.pi), 0)
    gold = shade_metal(h * S2 * 0.06, GOLD, strength=1.0)
    en = np.zeros((S2, S2, 3)) + np.array([238, 224, 190]) * 0.9
    en *= (1 - 0.3 * np.exp(-(d - B) / 3))[..., None]
    rgb = np.where((d < B)[..., None], gold, en)
    if checked:
        m = svg_mask(ICONS['check'], S2, stroke=3.4)
        ih = ndimage.gaussian_filter(m, 1)
        col = shade_matte(ih * 6, (128, 26, 20), strength=1.0, spec=0.3)
        rgb = rgb * (1 - m[..., None]) + col * m[..., None]
    rgb2, a2 = _half(rgb, np.ones((S2, S2)))
    _save_rgba(rgb2, a2, path)


def seal_with_letter(path, size, base, letter):
    """Wax seal with an embossed initial (trait seals)."""
    S = size * 2
    y, x = np.mgrid[0:S, 0:S].astype(float)
    c = (S - 1) / 2
    ang = np.arctan2(y - c, x - c)
    r = np.hypot(x - c, y - c) / (S / 2)
    edge = 0.92 + 0.05 * np.sin(ang * 9 + hash(letter) % 7) + 0.025 * np.sin(ang * 23 + 1)
    a = np.clip((edge - r) * S / 3, 0, 1)
    hm = np.where(r < edge, np.sqrt(np.clip(1 - (r / edge) ** 2, 0, 1)), 0)
    ring = (r > 0.62) & (r < 0.7)
    hm[ring] -= 0.16
    if letter:
        from PIL import ImageFont
        fnt = ImageFont.truetype(CINZEL, int(S * 0.5))
        try:
            fnt.set_variation_by_axes([800])
        except Exception:
            pass
        im = Image.new('L', (S, S), 0)
        ImageDraw.Draw(im).text((S / 2, S / 2 + S * 0.02), letter, font=fnt, fill=255, anchor='mm')
        lm = ndimage.gaussian_filter(np.asarray(im, float) / 255, 1.2)
        hm = hm + lm * 0.22
    rgb = shade_matte(ndimage.gaussian_filter(hm, 1) * S * 0.25, base, strength=1.0, spec=0.45)
    rgb2, a2 = _half(rgb, a)
    _save_rgba(rgb2, a2, path)


CINZEL = 'godot/assets/fonts/Cinzel.ttf'

# What each screen button and indicator shows (also read by GezStyle.gd).
MEDALLIONS = {
    # top bar indicators
    'treasury': 'coin', 'stability': 'scales', 'faith': 'dome', 'manpower': 'people',
    'sailors': 'anchor', 'inflation': 'coin_down', 'menu': 'menu', 'pause': 'pause',
    'play': 'play', 'close': 'close',
    # side column screens
    'budget': 'ledger', 'trade': 'stall', 'court': 'crown', 'government': 'column',
    'religion': 'dome', 'rebels': 'torch', 'technology': 'astrolabe', 'diplomacy': 'scroll',
    'wars': 'swords', 'armies': 'helmet', 'fleets': 'ship',
    # Phase 18 screens (Gemini can use these names)
    'chronicle': 'quill', 'ledger': 'bars', 'timelapse': 'hourglass',
    # map modes
    'map_political': 'flag', 'map_diplomatic': 'rings', 'map_states': 'grid', 'map_terrain': 'mountain',
    'map_religion': 'dome', 'map_culture': 'people', 'map_development': 'bars', 'map_goods': 'box',
    'map_markets': 'stall', 'map_plague': 'skull', 'map_unrest': 'torch', 'map_institutions': 'book',
    # zoom and misc
    'zoom_in': 'plus', 'zoom_out': 'minus', 'zoom_fit': 'fit', 'alerts': 'bell', 'build': 'hammer',
    'capital': 'star', 'globe': 'globe', 'law': 'gavel', 'army': 'sword', 'watch': 'eye',
}

TRAIT_SEALS = {   # seal colour by kind of trait
    'virtue': (176, 120, 40), 'vice': (150, 34, 26), 'skill': (40, 76, 112),
    'health': (52, 36, 36), 'temper': (70, 100, 50),
}


def build_kit(out_dir):
    """Every piece the Godot Theme uses, written to godot/assets/ui/."""
    import os
    for sub in ['', 'medallions', 'seals']:
        os.makedirs(os.path.join(out_dir, sub), exist_ok=True)
    j = lambda *p: os.path.join(out_dir, *p)
    margins = {}
    margins['window'] = framed_box(j('window.png'), 360, gold=13, leather_w=9, bead=4, rosettes=True)
    margins['card'] = framed_box(j('card.png'), 120, gold=3, rosettes=False, page_alpha=0.0, seed=33)
    margins['tooltip'] = framed_box(j('tooltip.png'), 200, gold=6, rosettes=False, seed=35)
    strip(j('topbar.png'), 256, 52, seed=41)
    strip(j('sidebar.png'), 256, 64, moulding='right', seed=43)
    title_banner(j('banner.png'), 220, 36)
    for st in ['normal', 'hover', 'pressed', 'disabled']:
        gold_button(j(f'button_{st}.png'), 96, 32, st)
        leather_button(j(f'tab_{st}.png'), 80, 28, st)
    check_box(j('check_off.png'), 20, False)
    check_box(j('check_on.png'), 20, True)
    plain_medallion(j('grabber.png'), 20)
    plain_medallion(j('grabber_hover.png'), 20, enamel=(140, 30, 22))
    for key, icon in MEDALLIONS.items():
        icon_medallion(j('medallions', f'{key}.png'), 48, ICONS[icon])
        icon_medallion(j('medallions', f'{key}_on.png'), 48, ICONS[icon], enamel=(140, 30, 22))
    for kind, colour in TRAIT_SEALS.items():
        seal_with_letter(j('seals', f'{kind}.png'), 28, colour, '')
    # one seal per trait, stamped with its initial, coloured by kind
    for line in open('data/characters/traits.txt', encoding='utf-8'):
        if not line.strip() or line.startswith('#'):
            continue
        key, name = [p.strip() for p in line.split('|')[:2]]
        seal_with_letter(j('seals', f'trait_{key}.png'), 28, TRAIT_SEALS[trait_kind(key)], name[0])
    return margins


def trait_kind(key):
    if key in ('scholar', 'strategist', 'administrator', 'diplomat', 'schemer'):
        return 'skill'
    if key in ('sickly', 'blind', 'infirm', 'wounded', 'maimed', 'ill', 'mad', 'lunatic'):
        return 'health'
    if key in ('craven', 'arbitrary', 'cruel', 'cynical', 'lazy', 'greedy', 'deceitful', 'wrathful'):
        return 'vice'
    if key in ('ambitious', 'zealous', 'content'):
        return 'temper'
    return 'virtue'


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 2 and sys.argv[1] == '--kit':
        m = build_kit(sys.argv[2])
        print('kit margins:', m)
    else:
        build_concept()
        print('done')
