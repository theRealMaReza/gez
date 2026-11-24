#!/usr/bin/env python3
"""Paint the terrain picture the map shader draws on top of.

Inputs
  data/terrain/elevation.png                (from fetch_elevation.py, via CI)
  Packages/GezCore/Sources/GezCore/Resources/provinces1453.idmap
  Packages/GezCore/Sources/GezCore/Resources/scenario1453.json
  Packages/GezCore/Sources/GezCore/Resources/seas1453.idmap (unknown land)
Output
  App/Resources/Terrain/terrain.jpg          (same size as the province map)
  App/Resources/Terrain/edges.png            (border distance field, Phase 20.7;
                                              see edge_field.py)
  docs/terrain_preview.jpg                   (small preview)

How it paints:
  1. A smooth "climate" colour from each province's terrain type (farmland,
     forest, desert...), blurred so it never shows province shapes.
  2. Wasteland is desert in the south, taiga in the north, alpine above 3.5 km.
  3. High ground turns to rock, then snow (snow line drops further north).
  4. Hill shading from the elevation, lit from the north-west.
  5. Sea colour from water depth; lakes a fixed blue.
  6. Rivers painted on, anti-aliased.

Run after mapgen.py whenever the map or terrain types change:
  python3 tools/terrain/bake_terrain.py
Only the border field (no elevation needed):
  python3 tools/terrain/bake_terrain.py --edges-only
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import edge_field  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OFFSET = 12000

PALETTE = {
    "farmland": (128, 142, 80),
    "plains": (150, 150, 94),
    "steppe": (172, 162, 108),
    "desert": (212, 186, 136),
    "forest": (68, 98, 60),
    "marsh": (98, 118, 84),
    "hills": (140, 132, 94),
    "mountains": (130, 122, 104),
}
TAIGA = (62, 86, 64)
TUNDRA = (142, 142, 122)
ROCK = (122, 114, 106)
SNOW = (238, 240, 244)
SHALLOW = (92, 152, 160)
DEEP = (28, 54, 84)
LAKE = (72, 122, 142)
RIVER = (70, 114, 140)
PARCHMENT = (226, 212, 176)   # unknown land (Phase 20.7): blank chart paper
UNKNOWN_MARK = 0xFFFF         # sea-map value on unknown land (see mapgen.py)


def load_idmap(path):
    b = open(path, "rb").read()
    w, h, n = np.frombuffer(b[4:16], "<u4")
    runs = np.frombuffer(b[16:], "<u2").reshape(-1, 2)
    return np.repeat(runs[:, 0], runs[:, 1]).reshape(h, w).astype(np.int32)


def value_noise(shape, cell, rng):
    gh, gw = shape[0] // cell + 3, shape[1] // cell + 3
    g = rng.random((gh, gw))
    return ndimage.zoom(g, cell, order=3)[: shape[0], : shape[1]]


def paint(elev, ids, lat, prov_terrain, wobble, n1, n2, k):
    """Paint one strip of rows (with margins) and return it as float RGB."""
    H, W = ids.shape
    water = ids == 0
    waste = ids == 1
    land = ~water

    # 1. Climate colour per province terrain type, blurred.
    lut = np.array([PALETTE[t] for t in PALETTE], dtype=np.float32)
    climate = np.zeros((H, W, 3), dtype=np.float32)
    prov = ids >= 2
    climate[prov] = lut[prov_terrain[ids[prov] - 2]]
    # 2. Wasteland by latitude, blended gradually (desert -> taiga -> tundra).
    lat_w = (lat + wobble)[waste]
    taiga_w = np.clip((lat_w - 47) / 8, 0, 1)[:, None]
    tundra_w = np.clip((lat_w - 63) / 6, 0, 1)[:, None]
    w_color = np.array(PALETTE["desert"], np.float32) * (1 - taiga_w) + np.array(TAIGA, np.float32) * taiga_w
    climate[waste] = w_color * (1 - tundra_w) + np.array(TUNDRA, np.float32) * tundra_w
    del w_color, lat_w, taiga_w, tundra_w
    climate[water] = 0
    # Blur over land only (normalised), so coasts don't pull in sea colour.
    weight = ndimage.gaussian_filter(land.astype(np.float32), 9 * k)
    for c in range(3):
        climate[..., c] = ndimage.gaussian_filter(climate[..., c], 9 * k) / np.maximum(weight, 1e-3)
    del weight
    climate *= (1 + 0.10 * n1 + 0.06 * n2)[..., None]

    # 3. Rock and snow on high ground.
    h = np.maximum(elev, 0)
    rock = np.clip((h - 1800) / 1400, 0, 1)
    snowline = np.clip(4300 - np.maximum(lat - 30, 0) * 70, 1500, 4600)
    # Snow on peaks that stand above their surroundings (so high plateaus
    # like Tibet stay brown, with white ranges on them).
    local = ndimage.gaussian_filter(h, 25 * k)
    peak = np.clip((h - local + 150) / 500, 0, 1)
    del local
    snow = np.clip((h - snowline) / 700, 0, 1) * np.maximum(peak, np.clip((h - snowline - 1800) / 800, 0, 1))
    del peak, snowline
    snow = ndimage.gaussian_filter(snow, 0.8) * np.clip(0.75 + n2 * 1.5, 0, 1)
    alpine = np.clip((h - 3500) / 800, 0, 1) * waste
    color = climate
    color *= (1 - rock[..., None])
    color += np.array(ROCK, np.float32) * rock[..., None]
    color *= (1 - alpine[..., None])
    color += np.array(TUNDRA, np.float32) * alpine[..., None]
    color *= (1 - snow[..., None])
    color += np.array(SNOW, np.float32) * snow[..., None]
    del rock, alpine, snow, h

    # 4. Hill shading (exaggerated so hills read at map scale).
    smooth = ndimage.gaussian_filter(np.where(land, elev, 0), 1.2 * k)
    dy_m = 111320.0 / (32.0 * k)
    dx_m = dy_m * np.cos(np.radians(lat))
    gy, gx = np.gradient(smooth)
    del smooth
    exaggerate = 7.0
    nx = -gx / dx_m * exaggerate
    ny = gy / dy_m * exaggerate   # image rows go south; flip so north is up
    del gx, gy, dx_m
    norm = np.sqrt(nx * nx + ny * ny + 1.0)
    az, alt = np.radians(315), np.radians(42)
    lx, ly, lz = np.cos(alt) * np.sin(az), np.cos(alt) * np.cos(az), np.sin(alt)
    shade = (nx * lx + ny * ly + lz) / norm
    del nx, ny, norm
    flat = lz
    light = np.clip(0.62 + 0.9 * (shade - flat) + 0.38, 0.45, 1.25)
    color *= light[..., None]
    del shade, light

    # 5. Water by depth; lakes fixed.
    depth = np.clip(-elev[water], 0, None)
    t = np.sqrt(np.clip(depth / 3000, 0, 1))[:, None]
    sea = np.array(SHALLOW, np.float32) * (1 - t) + np.array(DEEP, np.float32) * t
    lake = elev[water] > -5
    sea[lake] = LAKE
    sea *= (1 + 0.04 * n1[water])[:, None]
    color[water] = sea
    return color


def bake_edges(ids):
    """Phase 20.7: the smooth border and coast field (edge_field.py)."""
    path = os.path.join(ROOT, "App/Resources/Terrain/edges.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(edge_field.bake(ids), "L").save(path, optimize=True)
    print(f"wrote {path} ({os.path.getsize(path) / 1e6:.1f} MB)")


def main():
    ids = load_idmap(os.path.join(ROOT, "Packages/GezCore/Sources/GezCore/Resources/provinces1453.idmap"))
    bake_edges(ids)
    if "--edges-only" in sys.argv[1:]:
        return
    elev = np.array(Image.open(os.path.join(ROOT, "data/terrain/elevation.png"))).astype(np.float32) - OFFSET
    scenario = json.load(open(os.path.join(ROOT, "Packages/GezCore/Sources/GezCore/Resources/scenario1453.json")))
    H, W = ids.shape
    assert elev.shape == ids.shape, "elevation and province map sizes differ (run the Fetch elevation job after mapgen)"
    LAT_MAX, PPD = scenario["map"]["latitudeMax"], scenario["map"]["pixelsPerDegree"]
    k = PPD / 32.0  # blur and noise sizes were tuned at 32 pixels per degree
    lat_rows = (LAT_MAX - (np.arange(H) + 0.5) / PPD).astype(np.float32)
    prov_terrain = np.array([list(PALETTE).index(p["terrain"]) for p in scenario["provinces"]])
    rng0 = np.random.default_rng(7)
    wobble = ((value_noise((H, W), int(60 * k), rng0) - 0.5) * 6).astype(np.float32)   # degrees of latitude
    rng = np.random.default_rng(1453)
    n1 = (value_noise((H, W), int(40 * k), rng) - 0.5).astype(np.float32)
    n2 = (value_noise((H, W), int(9 * k), rng) - 0.5).astype(np.float32)

    # Paint in strips of rows, each with a margin wide enough for the
    # largest blur (4 sigma), so the result matches painting it all at once
    # while memory stays small at any map size.
    out = np.zeros((H, W, 3), dtype=np.uint8)
    margin = int(4 * 25 * k) + 8
    strip = 512
    for y0 in range(0, H, strip):
        y1 = min(H, y0 + strip)
        a, b = max(0, y0 - margin), min(H, y1 + margin)
        lat = lat_rows[a:b, None] * np.ones((1, W), dtype=np.float32)
        color = paint(elev[a:b], ids[a:b], lat, prov_terrain, wobble[a:b], n1[a:b], n2[a:b], k)
        out[y0:y1] = np.clip(color[y0 - a:y1 - a], 0, 255).astype(np.uint8)
        del color, lat
    # Unknown land (Australia, New Guinea): plain parchment, no relief.
    seas = load_idmap(os.path.join(ROOT, "Packages/GezCore/Sources/GezCore/Resources/seas1453.idmap"))
    unknown = (seas == UNKNOWN_MARK) & (ids == 1)
    del seas
    out[unknown] = np.clip(np.array(PARCHMENT, np.float32) * (1 + 0.05 * n1[unknown])[:, None], 0, 255).astype(np.uint8)
    del elev, wobble, n1, n2, unknown
    img = Image.fromarray(out, "RGB")
    del out

    # 6. Rivers, drawn at double size then shrunk for smooth edges.
    scale = 2
    overlay = Image.new("L", (W * scale, H * scale), 0)
    draw = ImageDraw.Draw(overlay)
    for river in scenario.get("rivers", []):
        pts = [(x * scale, y * scale) for x, y in river["points"]]
        draw.line(pts, fill=255, width=int(round((3 * scale // 2 + 1) * k)), joint="curve")
    overlay = overlay.filter(ImageFilter.GaussianBlur(1.0 * k)).resize((W, H), Image.LANCZOS)
    a = np.array(overlay)
    del overlay
    rows = np.flatnonzero(a.any(axis=1))
    arr = np.array(img)
    for y0 in range(0, H, strip):
        r = rows[(rows >= y0) & (rows < y0 + strip)]
        if len(r) == 0:
            continue
        sl = slice(y0, min(H, y0 + strip))
        al = (a[sl].astype(np.float32) / 255 * 0.9)[..., None]
        arr[sl] = np.clip(arr[sl].astype(np.float32) * (1 - al) + np.array(RIVER, np.float32) * al, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr, "RGB")
    del arr, a

    out_path = os.path.join(ROOT, "App/Resources/Terrain/terrain.jpg")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, quality=90, optimize=True)
    img.resize((W // 3, H // 3), Image.LANCZOS).save(os.path.join(ROOT, "docs/terrain_preview.jpg"), quality=85)
    print(f"wrote {out_path} ({os.path.getsize(out_path) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
