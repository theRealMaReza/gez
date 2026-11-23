#!/usr/bin/env python3
"""Builds the 3D model library for the Godot map and battle view (Phase 17).

Inputs
  tools/models/kaykit/hexagon/*.gltf      KayKit Medieval Hexagon Pack (CC0)
  tools/models/kaykit/adventurers/*.gltf  KayKit Adventurers pack weapons (CC0)
Output
  godot/assets/models/models.bin          every mesh, with colours baked in

What it does
  * Reads the free KayKit models and bakes their palette texture into
    vertex colours, recolouring the palette per regional style (European,
    Islamic, Indian, East Asian, Steppe): roofs, plaster, timber and stone
    each get the region's colours.
  * Builds the simple models the kits do not have, in code: flat-roofed
    houses, domes and minarets, Indian temples, pagodas, yurts, palisades,
    ships (cog, dhow, junk), soldiers, riders, flags, siege engines.
  * Writes one small binary file the game loads at start (no import step).

Units: one model unit is about the width of a house. Y is up, models stand
on y = 0 and face +z.

File format (little endian): b"GZMZ", u32 size of the unpacked data, then
gzip of: u32 version (1), u32 mesh count, then per mesh:
  u16 name length, name (utf-8), u32 vertex count, u32 index count,
  f32 positions[3n], f32 normals[3n], f32 colours[4n] (sRGB), i32 indices.
Colour alpha (Phase 20.6) is how much a vertex may move: 0 to 1 on flags
and sails (the game waves them), 1 everywhere else. Town buildings and forts
stand on a dark plinth, and towns, forts, ports, armies and fleets have
ambient occlusion baked into their colours.

Run after changing a model:  python3 tools/models/build_models.py
"""
import gzip
import json
import math
import os
import struct

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KAY = os.path.join(ROOT, "tools/models/kaykit")
OUT = os.path.join(ROOT, "godot/assets/models/models.bin")

STYLES = ["european", "islamic", "indian", "eastasian", "steppe"]

# KayKit hexagon palette: an 8 x 4 grid of gradient cells (column, row).
CELL_PLASTER = (1, 0)
CELL_STONE = (2, 0)
CELL_DARK = (3, 0)
CELL_TERRACOTTA = (5, 0)
CELL_TIMBER = (6, 0)
CELL_TEAM = (0, 3)       # roofs and banners of the "blue" models
CELL_CANVAS = (5, 1)

# Per-style colour for each palette role (sRGB 0..1). None = keep the kit colour.
PALETTES = {
    "european": {CELL_TEAM: (0.72, 0.40, 0.28), CELL_TIMBER: (0.76, 0.64, 0.48)},
    "islamic": {
        CELL_PLASTER: (0.90, 0.84, 0.70), CELL_STONE: (0.80, 0.70, 0.52),
        CELL_TIMBER: (0.62, 0.48, 0.32), CELL_TEAM: (0.86, 0.80, 0.66),
        CELL_TERRACOTTA: (0.74, 0.60, 0.42),
    },
    "indian": {
        CELL_PLASTER: (0.80, 0.48, 0.34), CELL_STONE: (0.74, 0.42, 0.30),
        CELL_TIMBER: (0.55, 0.32, 0.22), CELL_TEAM: (0.93, 0.90, 0.84),
        CELL_TERRACOTTA: (0.86, 0.66, 0.40),
    },
    "eastasian": {
        CELL_PLASTER: (0.90, 0.88, 0.80), CELL_STONE: (0.58, 0.58, 0.56),
        CELL_TIMBER: (0.62, 0.16, 0.12), CELL_TEAM: (0.20, 0.27, 0.30),
        CELL_TERRACOTTA: (0.24, 0.32, 0.34),
    },
    "steppe": {
        CELL_PLASTER: (0.88, 0.84, 0.74), CELL_STONE: (0.62, 0.56, 0.46),
        CELL_TIMBER: (0.52, 0.36, 0.22), CELL_TEAM: (0.70, 0.56, 0.38),
        CELL_TERRACOTTA: (0.64, 0.50, 0.34),
    },
}

# Colours for the models built in code, per style.
STYLE_COL = {
    "european": dict(wall=(0.90, 0.87, 0.80), roof=(0.72, 0.40, 0.28), trim=(0.45, 0.30, 0.20),
                     dome=(0.40, 0.44, 0.48), accent=(0.70, 0.64, 0.50), stone=(0.66, 0.64, 0.60)),
    "islamic": dict(wall=(0.90, 0.84, 0.70), roof=(0.86, 0.80, 0.66), trim=(0.62, 0.48, 0.32),
                    dome=(0.22, 0.58, 0.58), accent=(0.95, 0.93, 0.86), stone=(0.80, 0.70, 0.52)),
    "indian": dict(wall=(0.80, 0.48, 0.34), roof=(0.93, 0.90, 0.84), trim=(0.55, 0.32, 0.22),
                   dome=(0.95, 0.93, 0.88), accent=(0.92, 0.70, 0.30), stone=(0.74, 0.42, 0.30)),
    "eastasian": dict(wall=(0.90, 0.88, 0.80), roof=(0.20, 0.27, 0.30), trim=(0.62, 0.16, 0.12),
                      dome=(0.20, 0.27, 0.30), accent=(0.85, 0.68, 0.25), stone=(0.58, 0.58, 0.56)),
    "steppe": dict(wall=(0.88, 0.84, 0.74), roof=(0.70, 0.56, 0.38), trim=(0.52, 0.36, 0.22),
                   dome=(0.64, 0.30, 0.22), accent=(0.30, 0.45, 0.70), stone=(0.62, 0.56, 0.46)),
}

WOOD = (0.48, 0.33, 0.20)
DARK_WOOD = (0.32, 0.22, 0.14)
SKIN = (0.86, 0.66, 0.50)
STEEL = (0.62, 0.64, 0.68)
WHITE = (1.0, 1.0, 1.0)
CLOTH = (0.94, 0.92, 0.86)
LEATHER = (0.40, 0.28, 0.18)
HORSE = (0.46, 0.32, 0.22)


# --------------------------------------------------------------------------
# Mesh builder (flat-shaded triangles with vertex colours)

class Mesh:
    def __init__(self):
        self.p = []   # list of (x, y, z)
        self.c = []   # list of (r, g, b)
        self.a = None  # optional per-vertex alpha: how much the vertex may move (flags, sails)

    def tri(self, a, b, c, col):
        self.p += [a, b, c]
        self.c += [col, col, col]

    def quad(self, a, b, c, d, col):
        self.tri(a, b, c, col)
        self.tri(a, c, d, col)

    def extend(self, other):
        if self.a is not None or other.a is not None:
            self.a = (self.a or [0.0] * len(self.p)) + (other.a or [0.0] * len(other.p))
        self.p += other.p
        self.c += other.c
        return self

    def transformed(self, scale=1.0, rot_y=0.0, offset=(0, 0, 0), rot_x=0.0, rot_z=0.0):
        m = Mesh()
        P = np.array(self.p, dtype=np.float64).reshape(-1, 3) * np.array(scale if np.ndim(scale) else (scale,) * 3)
        P = P @ rot_matrix(rot_x, rot_y, rot_z).T + np.array(offset)
        m.p = [tuple(v) for v in P]
        m.c = list(self.c)
        m.a = list(self.a) if self.a is not None else None
        return m

    # ---- primitives ----
    def box(self, center, size, col, rot_y=0.0, top_col=None):
        cx, cy, cz = center
        sx, sy, sz = (s * 0.5 for s in size)
        v = np.array([[x, y, z] for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)])
        v = v @ rot_matrix(0, rot_y, 0).T + np.array(center)
        V = [tuple(x) for x in v]
        # index: x*4 + y*2 + z
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for f in faces:
            col_f = top_col if (top_col and f == (2, 3, 7, 6)) else col
            self.quad(V[f[0]], V[f[1]], V[f[2]], V[f[3]], col_f)
        return self

    def frustum(self, base_center, r0, r1, h, segs, col, cap_bottom=False, cap_top=True, top_col=None, rot=0.0):
        """Cylinder (r0 == r1), cone (r1 == 0) or truncated cone, `segs` sides."""
        bx, by, bz = base_center
        for i in range(segs):
            a0 = rot + 2 * math.pi * i / segs
            a1 = rot + 2 * math.pi * (i + 1) / segs
            p0 = (bx + r0 * math.sin(a0), by, bz + r0 * math.cos(a0))
            p1 = (bx + r0 * math.sin(a1), by, bz + r0 * math.cos(a1))
            q0 = (bx + r1 * math.sin(a0), by + h, bz + r1 * math.cos(a0))
            q1 = (bx + r1 * math.sin(a1), by + h, bz + r1 * math.cos(a1))
            if r1 > 1e-6:
                self.quad(p0, p1, q1, q0, col)
            else:
                self.tri(p0, p1, q0, col)
            if cap_top and r1 > 1e-6:
                self.tri((bx, by + h, bz), q0, q1, top_col or col)
            if cap_bottom:
                self.tri((bx, by, bz), p1, p0, col)
        return self

    def dome(self, center, r, col, segs=10, rings=4, squash=1.0, onion=0.0):
        cx, cy, cz = center
        def pt(ring, i):
            t = ring / rings * (math.pi / 2)
            rr = r * math.cos(t) * (1.0 + onion * math.sin(2 * t))
            a = 2 * math.pi * i / segs
            return (cx + rr * math.sin(a), cy + r * squash * math.sin(t), cz + rr * math.cos(a))
        for ring in range(rings):
            for i in range(segs):
                a, b = pt(ring, i), pt(ring, i + 1)
                c, d = pt(ring + 1, i + 1), pt(ring + 1, i)
                if ring == rings - 1:
                    self.tri(a, b, c, col)
                else:
                    self.quad(a, b, c, d, col)
        return self

    def gable_roof(self, center, w, d, h, col, overhang=0.06, gable_col=None, rot_y=0.0):
        """Ridge along x. center = middle of the roof's base."""
        cx, cy, cz = center
        w2, d2 = w * 0.5 + overhang, d * 0.5 + overhang
        pts = np.array([[-w2, 0, -d2], [w2, 0, -d2], [w2, 0, d2], [-w2, 0, d2], [-w2, h, 0], [w2, h, 0]])
        pts = pts @ rot_matrix(0, rot_y, 0).T + np.array(center)
        P = [tuple(x) for x in pts]
        self.quad(P[0], P[4], P[5], P[1], col)
        self.quad(P[3], P[2], P[5], P[4], col)
        g = gable_col or col
        self.tri(P[0], P[3], P[4], g)
        self.tri(P[1], P[5], P[2], g)
        return self

    def hip_roof(self, center, w, d, h, col, overhang=0.08, flare=0.0):
        """Four-sided roof; flare > 0 widens the eaves (East Asian look)."""
        cx, cy, cz = center
        w2, d2 = w * 0.5 + overhang + flare, d * 0.5 + overhang + flare
        rw = max(w * 0.5 - d * 0.5, 0.0) * 0.6
        base = [(cx - w2, cy, cz - d2), (cx + w2, cy, cz - d2), (cx + w2, cy, cz + d2), (cx - w2, cy, cz + d2)]
        ridge = [(cx - rw, cy + h, cz), (cx + rw, cy + h, cz)]
        self.quad(base[0], ridge[0], ridge[1], base[1], col)
        self.quad(base[2], ridge[1], ridge[0], base[3], col)
        self.tri(base[3], ridge[0], base[0], col)
        self.tri(base[1], ridge[1], base[2], col)
        # underside so the flared eaves are not see-through
        self.quad(base[0], base[1], base[2], base[3], tuple(x * 0.6 for x in col))
        return self

    def prism(self, profile_xy, depth, col, z0=0.0):
        """Extrude a convex 2D outline (in x/y) along z from z0 - depth/2 to z0 + depth/2."""
        d = depth * 0.5
        n = len(profile_xy)
        front = [(x, y, z0 + d) for x, y in profile_xy]
        back = [(x, y, z0 - d) for x, y in profile_xy]
        for i in range(1, n - 1):
            self.tri(front[0], front[i], front[i + 1], col)
            self.tri(back[0], back[i + 1], back[i], col)
        for i in range(n):
            j = (i + 1) % n
            self.quad(front[i], back[i], back[j], front[j], col)
        return self


def rot_matrix(rx, ry, rz):
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def shade(col, k):
    return tuple(min(1.0, max(0.0, x * k)) for x in col)


# --------------------------------------------------------------------------
# KayKit glTF loading with palette baking

def load_gltf(path):
    g = json.load(open(path))
    base = os.path.dirname(path)
    buf = open(os.path.join(base, g["buffers"][0]["uri"]), "rb").read()
    img = None
    if g.get("images"):
        img = np.asarray(Image.open(os.path.join(base, g["images"][0]["uri"])).convert("RGB")).astype(np.float32) / 255.0

    def acc(i):
        a = g["accessors"][i]
        bv = g["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        dt = {5126: "<f4", 5123: "<u2", 5125: "<u4", 5121: "u1"}[a["componentType"]]
        return np.frombuffer(buf, dt, a["count"] * n, off).reshape(a["count"], n) if n > 1 else \
            np.frombuffer(buf, dt, a["count"], off)

    tris_p, tris_uv = [], []
    for node in g["nodes"]:
        if "mesh" not in node:
            continue
        for pr in g["meshes"][node["mesh"]]["primitives"]:
            P = acc(pr["attributes"]["POSITION"]).astype(np.float64)
            UV = acc(pr["attributes"]["TEXCOORD_0"]).astype(np.float64)
            I = acc(pr["indices"]).astype(np.int64) if "indices" in pr else np.arange(len(P))
            if "scale" in node:
                P = P * np.array(node["scale"])
            if "translation" in node:
                P = P + np.array(node["translation"])
            tris_p.append(P[I])
            tris_uv.append(UV[I])
    return np.concatenate(tris_p), np.concatenate(tris_uv), img


def kaykit(name, style=None, pack="hexagon", scale=1.0, rot_y=0.0, offset=(0, 0, 0)):
    P, UV, img = load_gltf(os.path.join(KAY, pack, name + ".gltf"))
    h, w = img.shape[:2]
    px = np.clip((UV[:, 0] % 1.0) * w, 0, w - 1).astype(int)
    py = np.clip((UV[:, 1] % 1.0) * h, 0, h - 1).astype(int)
    cols = img[py, px]
    if pack == "hexagon" and style is not None:
        pal = PALETTES[style]
        cx = np.clip((UV[:, 0] % 1.0) * 8, 0, 7.999).astype(int)
        cy = np.clip((UV[:, 1] % 1.0) * 4, 0, 3.999).astype(int)
        for cell, target in pal.items():
            mask = (cx == cell[0]) & (cy == cell[1])
            if not mask.any():
                continue
            # Keep the kit's light-to-dark gradient, in the new colour.
            frac = (UV[mask, 1] % 1.0) * 4 - cell[1]
            k = 1.12 - 0.45 * np.clip(frac, 0, 1)
            cols[mask] = np.clip(np.array(target)[None, :] * k[:, None], 0, 1)
    m = Mesh()
    P = P * scale
    P = P @ rot_matrix(0, rot_y, 0).T + np.array(offset)
    m.p = [tuple(v) for v in P]
    m.c = [tuple(c) for c in cols]
    return m


# --------------------------------------------------------------------------
# Models built in code

def flat_house(style, w=0.9, d=0.8, h=0.62, seed=0):
    c = STYLE_COL[style]
    m = Mesh()
    m.box((0, h * 0.5, 0), (w, h, d), c["wall"], top_col=c["roof"])
    m.box((0, h + 0.03, 0), (w + 0.06, 0.06, d + 0.06), shade(c["wall"], 0.88))
    m.box((0, 0.17, d * 0.5 + 0.005), (0.18, 0.32, 0.02), DARK_WOOD)
    m.box((w * 0.28, h * 0.62, d * 0.5 + 0.005), (0.12, 0.1, 0.02), shade(c["trim"], 0.7))
    if seed % 2:
        m.box((-w * 0.2, h + 0.18, -d * 0.15), (w * 0.45, 0.3, d * 0.5), c["wall"], top_col=c["roof"])
    return m


def mosque(style, big=False):
    c = STYLE_COL[style]
    k = 1.35 if big else 1.0
    m = Mesh()
    m.box((0, 0.36 * k, 0), (1.3 * k, 0.72 * k, 1.2 * k), c["wall"], top_col=c["roof"])
    m.frustum((0, 0.72 * k, 0), 0.46 * k, 0.46 * k, 0.12 * k, 12, c["wall"])
    m.dome((0, 0.84 * k, 0), 0.46 * k, c["dome"], segs=12, rings=4, onion=0.25 if style == "indian" else 0.0)
    m.frustum((0, 0.84 * k + 0.46 * k, 0), 0.03, 0.0, 0.18 * k, 6, c["accent"])
    corners = [(0.62, 0.55)] if not big else [(0.72, 0.65), (-0.72, 0.65), (0.72, -0.65), (-0.72, -0.65)]
    for (x, z) in corners:
        mh = 1.75 * k
        m.frustum((x * k, 0, z * k), 0.1 * k, 0.085 * k, mh, 8, c["wall"])
        m.frustum((x * k, mh * 0.72, z * k), 0.15 * k, 0.15 * k, 0.05 * k, 8, shade(c["wall"], 0.85))
        m.frustum((x * k, mh, z * k), 0.1 * k, 0.0, 0.3 * k, 8, c["dome"])
    if big:
        for (x, z) in [(0.45, 0), (-0.45, 0)]:
            m.dome((x * k, 0.72 * k, z), 0.22 * k, c["dome"], segs=10, rings=3)
    return m


def indian_temple(style, big=False):
    c = STYLE_COL[style]
    k = 1.3 if big else 1.0
    m = Mesh()
    m.box((0, 0.12 * k, 0), (1.5 * k, 0.24 * k, 1.5 * k), c["stone"])
    m.box((0, 0.5 * k, 0.25 * k), (0.9 * k, 0.52 * k, 0.7 * k), c["wall"])
    # Shikhara: a curved tower of shrinking tiers.
    y = 0.24 * k
    for i in range(6):
        r = (0.42 - i * 0.055) * k
        hh = 0.26 * k
        m.frustum((0, y, -0.2 * k), r, r * 0.86, hh, 8, shade(c["wall"], 1.0 - i * 0.03), rot=math.pi / 8)
        y += hh
    m.frustum((0, y, -0.2 * k), 0.12 * k, 0.12 * k, 0.05 * k, 8, c["accent"])
    m.dome((0, y + 0.05 * k, -0.2 * k), 0.1 * k, c["accent"], segs=8, rings=2)
    for (x, z) in [(0.55, 0.55), (-0.55, 0.55)]:
        m.frustum((x * k, 0.24 * k, z * k), 0.04 * k, 0.04 * k, 0.4 * k, 6, c["roof"])
        m.dome((x * k, 0.64 * k, z * k), 0.13 * k, c["roof"], segs=8, rings=3, onion=0.3)
    return m


def pagoda(style, tiers=4):
    c = STYLE_COL[style]
    m = Mesh()
    m.box((0, 0.08, 0), (1.3, 0.16, 1.3), c["stone"])
    y = 0.16
    for i in range(tiers):
        w = 0.95 - i * 0.14
        hh = 0.34 - i * 0.02
        m.box((0, y + hh * 0.5, 0), (w, hh, w), c["trim"] if i == 0 else c["wall"])
        m.hip_roof((0, y + hh, 0), w, w, 0.16, c["roof"], overhang=0.05, flare=0.12)
        y += hh + 0.14
    m.frustum((0, y - 0.04, 0), 0.03, 0.03, 0.4, 6, c["accent"])
    return m


def east_house(style, seed=0):
    c = STYLE_COL[style]
    m = Mesh()
    w, d = (1.0, 0.75) if seed % 2 == 0 else (0.85, 0.7)
    m.box((0, 0.27, 0), (w, 0.54, d), c["wall"])
    for x in (-w * 0.5 + 0.03, w * 0.5 - 0.03):
        m.box((x, 0.27, d * 0.5), (0.06, 0.54, 0.04), c["trim"])
    m.hip_roof((0, 0.54, 0), w, d, 0.3, c["roof"], flare=0.1)
    return m


def yurt(style, r=0.48, big=False):
    c = STYLE_COL[style]
    k = 1.45 if big else 1.0
    m = Mesh()
    m.frustum((0, 0, 0), r * k, r * k, 0.36 * k, 12, c["wall"], cap_top=False)
    m.frustum((0, 0.36 * k, 0), r * k * 1.02, 0.08 * k, 0.26 * k, 12, c["roof"])
    m.frustum((0, 0.36 * k, 0), r * k * 1.03, r * k * 1.03, 0.04 * k, 12, c["trim"], cap_top=False)
    m.box((0, 0.15 * k, r * k), (0.2 * k, 0.28 * k, 0.04), c["accent"])
    if big:
        m.frustum((0, 0.62 * k, 0), 0.02, 0.02, 0.5, 5, WOOD)
        m.box((0.12, 1.0, 0), (0.22, 0.14, 0.02), c["dome"])
    return m


def palisade(style, r=0.95, posts=18):
    c = STYLE_COL[style]
    m = Mesh()
    for i in range(posts):
        a = 2 * math.pi * i / posts
        if abs(a - math.pi * 0.0) < 0.2:
            continue  # gate gap facing +z
        m.frustum((r * math.sin(a), 0, r * math.cos(a)), 0.07, 0.07, 0.55, 5, c["trim"], cap_top=False)
        m.frustum((r * math.sin(a), 0.55, r * math.cos(a)), 0.07, 0.0, 0.12, 5, shade(c["trim"], 0.8))
    m.box((0, 0.6, r + 0.02), (0.5, 0.08, 0.08), c["trim"])
    return m


def ship(style):
    """Hull + mast(s); sails are a separate mesh so they can take the owner's colour."""
    c = STYLE_COL[style]
    m = Mesh()
    if style == "eastasian":
        hull = [(-0.85, 0.35), (-0.95, 0.42), (0.75, 0.32), (0.85, 0.12), (0.6, 0.0), (-0.65, 0.0)]
        m.prism([(x, y) for x, y in hull], 0.5, (0.42, 0.26, 0.16))
        m.box((-0.62, 0.48, 0), (0.42, 0.18, 0.46), (0.55, 0.18, 0.12))
        for x, h in [(0.1, 1.25), (0.55, 0.95)]:
            m.frustum((x, 0.3, 0), 0.03, 0.025, h, 6, DARK_WOOD)
    elif style in ("islamic", "indian"):
        hull = [(-0.9, 0.3), (0.95, 0.38), (0.7, 0.05), (0.4, 0.0), (-0.6, 0.0), (-0.85, 0.12)]
        m.prism([(x, y) for x, y in hull], 0.38, (0.55, 0.40, 0.26))
        m.frustum((0.1, 0.25, 0), 0.03, 0.02, 1.1, 6, DARK_WOOD)
    else:
        hull = [(-0.85, 0.42), (0.85, 0.42), (0.72, 0.1), (0.5, 0.0), (-0.55, 0.0), (-0.78, 0.15)]
        m.prism([(x, y) for x, y in hull], 0.52, (0.46, 0.31, 0.18))
        m.box((-0.62, 0.56, 0), (0.36, 0.26, 0.5), (0.52, 0.36, 0.22))
        m.box((0.66, 0.53, 0), (0.28, 0.2, 0.46), (0.52, 0.36, 0.22))
        m.frustum((0.0, 0.35, 0), 0.035, 0.028, 1.3, 6, DARK_WOOD)
        if style == "steppe":
            m.box((-0.7, 0.75, 0), (0.06, 0.4, 0.06), DARK_WOOD)
    # Ships are built along x; turn them so the bow faces +z like everything else.
    return m.transformed(rot_y=-math.pi / 2)


def ship_sails(style):
    s = Mesh()
    if style == "eastasian":
        for x, h, w in [(0.1, 0.9, 0.62), (0.55, 0.65, 0.46)]:
            for j in range(4):
                y0 = 0.5 + j * h / 4
                s.box((x - 0.04, y0 + h / 8, 0), (w, h / 4 - 0.02, 0.03), shade(CLOTH, 0.92 if j % 2 else 1.0))
    elif style in ("islamic", "indian"):
        tri = [(-0.55, 0.45), (0.65, 1.45), (0.25, 0.42)]
        s.prism(tri, 0.03, CLOTH)
    else:
        s.box((0.0, 1.08, 0.05), (0.07, 0.72, 0.74), CLOTH)
        s.box((0.0, 1.5, 0.0), (0.04, 0.04, 0.8), DARK_WOOD)
    # Phase 20.6: the cloth may move (most in the middle, away from mast,
    # yard and edges); wood never does.
    P = np.array(s.p)
    cloth = np.array([c != DARK_WOOD for c in s.c])
    lo, hi = P[cloth].min(axis=0), P[cloth].max(axis=0)
    mid = (lo + hi) * 0.5
    half = np.maximum((hi - lo) * 0.5, 1e-6)
    # how far from the sail's edges, across its two long sides (the third,
    # thin side is ignored)
    keep = np.argsort(hi - lo)[1:]
    t = 1.0 - np.max(np.abs((P - mid) / half)[:, keep], axis=1)
    w = np.where(cloth, np.clip(t * 1.4, 0.0, 1.0), 0.0)
    s.a = [float(v) for v in w]
    return s.transformed(rot_y=-math.pi / 2)


def pier():
    m = Mesh()
    m.box((0, 0.06, 0.45), (0.34, 0.06, 1.1), (0.55, 0.40, 0.26))
    for z in (0.05, 0.45, 0.85):
        for x in (-0.15, 0.15):
            m.frustum((x, -0.2, z), 0.03, 0.03, 0.3, 5, DARK_WOOD)
    return m


def flag_pole(h=1.7):
    m = Mesh()
    m.frustum((0, 0, 0), 0.03, 0.025, h, 6, DARK_WOOD)
    m.dome((0, h, 0), 0.05, (0.85, 0.70, 0.25), segs=6, rings=2)
    return m


def flag_cloth(h=1.7):
    m = Mesh()
    m.prism([(0.02, h - 0.05), (0.62, h - 0.12), (0.62, h - 0.47), (0.02, h - 0.40)], 0.03, WHITE)
    # Phase 20.6: fixed at the pole, free at the fly end.
    m.a = [min(max((x - 0.02) / 0.6, 0.0), 1.0) ** 1.3 for x, _, _ in m.p]
    return m


# ---- soldiers -------------------------------------------------------------

def soldier_body():
    """The parts worn in the owner's colour (tunic and sleeves). White here; the game tints it."""
    m = Mesh()
    m.frustum((0, 0.42, 0), 0.17, 0.13, 0.4, 8, WHITE)          # tunic
    m.frustum((0, 0.34, 0), 0.2, 0.17, 0.1, 8, shade(WHITE, 0.9), cap_top=False)
    for x in (-0.17, 0.17):
        m.box((x, 0.64, 0), (0.08, 0.2, 0.1), shade(WHITE, 0.95))
    return m


def soldier_gear(style):
    m = Mesh()
    m.box((-0.07, 0.17, 0), (0.09, 0.34, 0.1), shade(LEATHER, 1.2))   # legs
    m.box((0.07, 0.17, 0), (0.09, 0.34, 0.1), shade(LEATHER, 1.2))
    m.box((0, 0.84, 0), (0.14, 0.14, 0.14), SKIN)                     # head
    if style == "european":
        m.frustum((0, 0.9, 0), 0.2, 0.2, 0.02, 10, STEEL)
        m.dome((0, 0.91, 0), 0.11, STEEL, segs=8, rings=2)
        shield = kaykit("shield_square", pack="adventurers", scale=0.3, offset=(-0.22, 0.5, 0.06), rot_y=math.pi / 2)
        weapon = spear(1.5)
    elif style == "islamic":
        m.frustum((0, 0.88, 0), 0.11, 0.1, 0.09, 8, CLOTH)
        m.frustum((0, 0.97, 0), 0.08, 0.0, 0.16, 8, STEEL)
        shield = kaykit("shield_round", pack="adventurers", scale=0.3, offset=(-0.22, 0.5, 0.06), rot_y=math.pi / 2)
        weapon = kaykit("sword_1handed", pack="adventurers", scale=0.38, offset=(0.24, 0.42, 0.08))
    elif style == "indian":
        m.frustum((0, 0.88, 0), 0.12, 0.1, 0.12, 8, (0.95, 0.66, 0.20))
        shield = kaykit("shield_round", pack="adventurers", scale=0.28, offset=(-0.22, 0.5, 0.06), rot_y=math.pi / 2)
        weapon = spear(1.35)
    elif style == "eastasian":
        m.frustum((0, 0.9, 0), 0.24, 0.0, 0.14, 10, (0.72, 0.62, 0.38))
        shield = Mesh()
        weapon = spear(1.7)
    else:  # steppe
        m.frustum((0, 0.88, 0), 0.12, 0.1, 0.08, 8, (0.42, 0.30, 0.20))
        m.frustum((0, 0.96, 0), 0.08, 0.0, 0.14, 8, (0.62, 0.20, 0.16))
        shield = Mesh()
        weapon = kaykit("axe_1handed", pack="adventurers", scale=0.38, offset=(0.24, 0.42, 0.08))
    return m.extend(shield).extend(weapon)


def archer_gear(style):
    """Soldier gear with a bow (East Asia, steppe, India, Islamic lands) or a handgun (Europe) instead of shield and spear."""
    m = Mesh()
    base = soldier_gear_head_and_legs(style)
    m.extend(base)
    if style == "european":
        gun = Mesh().box((0, 0, 0), (0.05, 0.05, 0.7), DARK_WOOD)
        m.extend(gun.transformed(rot_x=-0.5, offset=(0.18, 0.62, 0.12)))
        m.box((0.18, 0.7, 0.4), (0.06, 0.06, 0.12), STEEL)
    else:
        for k in range(5):
            a0 = -0.9 + k * 0.36
            a1 = a0 + 0.36
            p0 = (0.26, 0.55 + 0.42 * math.sin(a0), 0.1 + 0.18 * math.cos(a0))
            p1 = (0.26, 0.55 + 0.42 * math.sin(a1), 0.1 + 0.18 * math.cos(a1))
            mid = tuple((p0[i] + p1[i]) * 0.5 for i in range(3))
            seg = Mesh().box((0, 0, 0), (0.04, math.dist(p0, p1), 0.04), WOOD)
            ang = math.atan2(p1[2] - p0[2], p1[1] - p0[1])
            m.extend(seg.transformed(rot_x=ang, offset=mid))
        m.box((0.26, 0.55, 0.1), (0.01, 0.82, 0.01), CLOTH)
        m.box((-0.12, 0.6, -0.12), (0.1, 0.36, 0.1), LEATHER)  # quiver
    return m


def soldier_gear_head_and_legs(style):
    """Legs, head and the regional hat of soldier_gear, without weapons."""
    hat = soldier_hat(style)
    m = Mesh()
    m.box((-0.07, 0.17, 0), (0.09, 0.34, 0.1), shade(LEATHER, 1.2))
    m.box((0.07, 0.17, 0), (0.09, 0.34, 0.1), shade(LEATHER, 1.2))
    m.box((0, 0.84, 0), (0.14, 0.14, 0.14), SKIN)
    return m.extend(hat)


def soldier_hat(style):
    m = Mesh()
    if style == "european":
        m.frustum((0, 0.9, 0), 0.2, 0.2, 0.02, 10, STEEL)
        m.dome((0, 0.91, 0), 0.11, STEEL, segs=8, rings=2)
    elif style == "islamic":
        m.frustum((0, 0.88, 0), 0.11, 0.1, 0.09, 8, CLOTH)
        m.frustum((0, 0.97, 0), 0.08, 0.0, 0.16, 8, STEEL)
    elif style == "indian":
        m.frustum((0, 0.88, 0), 0.12, 0.1, 0.12, 8, (0.95, 0.66, 0.20))
    elif style == "eastasian":
        m.frustum((0, 0.9, 0), 0.24, 0.0, 0.14, 10, (0.72, 0.62, 0.38))
    else:
        m.frustum((0, 0.88, 0), 0.12, 0.1, 0.08, 8, (0.42, 0.30, 0.20))
        m.frustum((0, 0.96, 0), 0.08, 0.0, 0.14, 8, (0.62, 0.20, 0.16))
    return m


def spear(length):
    m = Mesh()
    m.frustum((0.24, 0.25, 0.05), 0.018, 0.018, length, 5, WOOD)
    m.frustum((0.24, 0.25 + length, 0.05), 0.04, 0.0, 0.14, 5, STEEL)
    return m


def horse():
    m = Mesh()
    m.box((0, 0.62, 0), (0.3, 0.3, 0.8), HORSE)
    m.box((0, 0.86, 0.42), (0.18, 0.36, 0.18), HORSE, rot_y=0.0)
    m.box((0, 1.0, 0.56), (0.14, 0.14, 0.3), HORSE)
    for x in (-0.1, 0.1):
        for z in (-0.3, 0.3):
            m.box((x, 0.24, z), (0.08, 0.48, 0.08), shade(HORSE, 0.8))
    m.box((0, 0.7, -0.44), (0.06, 0.3, 0.06), DARK_WOOD)
    return m


def rider_body():
    return soldier_body().transformed(offset=(0, 0.55, -0.05))


def rider_gear(style):
    g = soldier_gear(style)
    # Drop the legs (the first 24 triangles' worth of vertices = 2 boxes x 36).
    g.p, g.c = g.p[72:], g.c[72:]
    return g.transformed(offset=(0, 0.55, -0.05)).extend(horse())


# ---- siege engines and walls (battle view) --------------------------------

def trebuchet():
    beam = Mesh().prism([(-0.3, 0.1), (0.3, 0.1), (0.04, 1.2), (-0.04, 1.2)], 0.08, WOOD)
    m = Mesh()
    for x in (-0.35, 0.35):
        m.box((x, 0.06, 0), (0.1, 0.12, 1.4), WOOD)
        m.extend(beam.transformed(rot_y=math.pi / 2, offset=(x, 0, 0)))
    m.box((0, 1.18, 0), (0.8, 0.07, 0.07), DARK_WOOD)
    m.box((0, 1.25, 0.15), (0.06, 0.06, 1.6), DARK_WOOD)
    m.box((0, 0.95, -0.55), (0.3, 0.3, 0.3), (0.45, 0.45, 0.45))
    return m


def battering_ram():
    m = Mesh()
    m.box((0, 0.35, 0), (0.6, 0.06, 1.1), WOOD)
    for x in (-0.28, 0.28):
        for z in (-0.45, 0.45):
            m.frustum((x, 0.0, z), 0.03, 0.03, 0.35, 5, DARK_WOOD)
            m.box((x * 1.1, 0.12, z), (0.04, 0.24, 0.24), DARK_WOOD)
    m.gable_roof((0, 0.38, 0), 1.1, 0.6, 0.38, (0.55, 0.42, 0.28), rot_y=math.pi / 2)
    log = Mesh().frustum((0, 0, 0), 0.07, 0.07, 1.4, 6, WOOD, cap_bottom=True)
    m.extend(log.transformed(rot_x=math.pi / 2, offset=(0, 0.25, -0.65)))
    head = Mesh().frustum((0, 0, 0), 0.09, 0.09, 0.12, 6, STEEL)
    m.extend(head.transformed(rot_x=math.pi / 2, offset=(0, 0.25, 0.75)))
    return m


def cannon():
    m = Mesh()
    barrel = Mesh().frustum((0, 0, 0), 0.1, 0.075, 0.95, 8, (0.30, 0.30, 0.32), cap_bottom=True)
    m.extend(barrel.transformed(rot_x=math.pi / 2 - 0.12, offset=(0, 0.26, -0.35)))
    m.box((0, 0.16, -0.1), (0.3, 0.12, 0.7), WOOD)
    for x in (-0.2, 0.2):
        w = Mesh().frustum((0, 0, 0), 0.17, 0.17, 0.05, 10, DARK_WOOD, cap_bottom=True)
        m.extend(w.transformed(rot_z=math.pi / 2, offset=(x + (0.025 if x > 0 else -0.025), 0.17, 0.05)))
    return m


def siege_tower():
    m = Mesh()
    m.box((0, 0.9, 0), (0.7, 1.8, 0.7), (0.55, 0.40, 0.26))
    for y in (0.45, 0.9, 1.35):
        m.box((0, y, 0.36), (0.72, 0.05, 0.02), DARK_WOOD)
    m.box((0, 1.86, 0), (0.78, 0.12, 0.78), DARK_WOOD)
    for x in (-0.3, 0.3):
        w = Mesh().frustum((0, 0, 0), 0.14, 0.14, 0.05, 8, DARK_WOOD, cap_bottom=True)
        for z in (-0.25, 0.25):
            m.extend(w.transformed(rot_z=math.pi / 2, offset=(x * 1.25, 0.14, z)))
    return m


def stone_wall(style, length=1.0):
    c = STYLE_COL[style]
    m = Mesh()
    m.box((0, 0.45, 0), (length, 0.9, 0.36), c["stone"], top_col=shade(c["stone"], 0.9))
    n = 4
    for i in range(n):
        x = -length * 0.5 + (i + 0.5) * length / n
        m.box((x, 0.97, 0.12), (length / n * 0.55, 0.14, 0.12), shade(c["stone"], 0.95))
    return m


def wall_tower(style):
    c = STYLE_COL[style]
    m = Mesh()
    m.frustum((0, 0, 0), 0.42, 0.38, 1.3, 10, c["stone"])
    for i in range(10):
        a = 2 * math.pi * (i + 0.5) / 10
        if i % 2 == 0:
            m.box((0.38 * math.sin(a), 1.38, 0.38 * math.cos(a)), (0.16, 0.16, 0.12), c["stone"], rot_y=a)
    if style == "eastasian":
        m.hip_roof((0, 1.4, 0), 0.8, 0.8, 0.35, c["roof"], flare=0.12)
    elif style in ("european",):
        m.frustum((0, 1.46, 0), 0.44, 0.0, 0.55, 10, c["roof"])
    elif style in ("islamic", "indian"):
        m.dome((0, 1.46, 0), 0.26, c["dome"], segs=10, rings=3, onion=0.2 if style == "indian" else 0.0)
    return m


def gate(style):
    c = STYLE_COL[style]
    m = Mesh()
    for x in (-0.55, 0.55):
        m.box((x, 0.6, 0), (0.4, 1.2, 0.5), c["stone"])
    m.box((0, 1.05, 0), (0.7, 0.3, 0.5), c["stone"])
    m.box((0, 0.42, 0.0), (0.66, 0.84, 0.08), DARK_WOOD)
    return m


def keep(style):
    c = STYLE_COL[style]
    m = Mesh()
    m.box((0, 0.8, 0), (1.3, 1.6, 1.3), c["stone"])
    for (x, z) in [(-0.65, -0.65), (0.65, -0.65), (-0.65, 0.65), (0.65, 0.65)]:
        m.frustum((x, 0, z), 0.24, 0.22, 1.95, 8, shade(c["stone"], 0.95))
    if style == "eastasian":
        m.hip_roof((0, 1.6, 0), 1.3, 1.3, 0.5, c["roof"], flare=0.15)
    elif style in ("islamic", "indian"):
        m.dome((0, 1.6, 0), 0.5, c["dome"], segs=12, rings=4, onion=0.2 if style == "indian" else 0.0)
    else:
        m.hip_roof((0, 1.6, 0), 1.3, 1.3, 0.55, c["roof"])
    return m


def rubble(style):
    c = STYLE_COL[style]
    m = Mesh()
    rng = np.random.default_rng(7)
    for i in range(9):
        x, z = rng.uniform(-0.45, 0.45, 2)
        s = rng.uniform(0.12, 0.26)
        m.box((x, s * 0.4, z), (s, s * 0.8, s), shade(c["stone"], rng.uniform(0.75, 1.0)), rot_y=rng.uniform(0, 3))
    return m


def tree(kind=0):
    m = Mesh()
    m.frustum((0, 0, 0), 0.06, 0.05, 0.35, 5, DARK_WOOD)
    if kind == 0:
        m.frustum((0, 0.25, 0), 0.32, 0.0, 0.9, 7, (0.24, 0.40, 0.22))
    else:
        m.dome((0, 0.32, 0), 0.34, (0.30, 0.46, 0.24), segs=7, rings=3)
    return m


# --------------------------------------------------------------------------
# Library

# ---- Phase 20.6: plinths and baked ambient occlusion -----------------------

PLINTH = (0.31, 0.26, 0.20)
# Meshes (name before the style) that get baked ambient occlusion: towns,
# forts, ports, armies and fleets.
AO_MESHES = {"house_a", "house_b", "temple", "landmark", "market", "fort1", "fort2", "fort3",
             "pier", "ship", "sail", "soldier_body", "soldier_gear", "archer_gear", "rider_body",
             "rider_gear", "flag_pole", "flag_cloth"}


def with_plinth(m, pad=0.07, h=0.035, col=PLINTH):
    """An opaque dark base under a building (instead of a see-through shadow
    quad): the footprint's box with cut corners, a little wider than the
    walls, so the model sits on the ground at every angle."""
    P = np.array(m.p)
    height = P[:, 1].max()
    low = P[P[:, 1] < max(height * 0.12, 0.05)]
    if len(low) == 0:
        low = P
    x0, z0 = low[:, 0].min() - pad, low[:, 2].min() - pad
    x1, z1 = low[:, 0].max() + pad, low[:, 2].max() + pad
    cut = min(x1 - x0, z1 - z0) * 0.22
    ring = [(x0 + cut, z0), (x1 - cut, z0), (x1, z0 + cut), (x1, z1 - cut),
            (x1 - cut, z1), (x0 + cut, z1), (x0, z1 - cut), (x0, z0 + cut)]
    cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    top = [(cx + (x - cx) * 0.97, h, cz + (z - cz) * 0.97) for x, z in ring]
    bot = [(x, -0.02, z) for x, z in ring]
    b = Mesh()
    for i in range(8):
        j = (i + 1) % 8
        b.quad(bot[i], bot[j], top[j], top[i], shade(col, 0.85))
        b.tri((cx, h, cz), top[i], top[j], col)
    return b.extend(m) if m.a is None else m.extend(b)


def _voxels(P, T, cell):
    """Occupancy grid of the mesh's surface (points sampled on every triangle)."""
    lo = P.min(axis=0) - cell * 2
    dims = np.ceil((P.max(axis=0) + cell * 2 - lo) / cell).astype(int) + 1
    grid = np.zeros(dims, bool)
    tri = P[T]
    edge = np.maximum(np.linalg.norm(tri[:, 1] - tri[:, 0], axis=1),
                      np.linalg.norm(tri[:, 2] - tri[:, 0], axis=1))
    for k in np.unique(np.clip(np.ceil(edge / (cell * 0.7)).astype(int), 1, 40)):
        sel = tri[np.clip(np.ceil(edge / (cell * 0.7)).astype(int), 1, 40) == k]
        u, v = np.meshgrid(np.arange(k + 1), np.arange(k + 1))
        ok = (u + v) <= k
        u, v = u[ok] / k, v[ok] / k
        pts = (sel[:, None, 0] * (1 - u - v)[None, :, None] + sel[:, None, 1] * u[None, :, None]
               + sel[:, None, 2] * v[None, :, None]).reshape(-1, 3)
        idx = np.floor((pts - lo) / cell).astype(int)
        grid[idx[:, 0], idx[:, 1], idx[:, 2]] = True
    return grid, lo


def _dirs(n=24):
    """Fixed directions over a sphere (golden spiral)."""
    i = np.arange(n) + 0.5
    phi = np.arccos(1 - 2 * i / n)
    th = math.pi * (1 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.cos(phi), np.sin(th) * np.sin(phi)], axis=1)


def ambient_occlusion(P, N, T, strength=0.55, reach=0.45):
    """Per-vertex light from the sky that the model itself does not block.
    Rays are marched through a voxel copy of the surface; the ground (y < 0)
    blocks too, so walls darken where they meet it. Winding is not
    consistent between builders, so each vertex takes the more open of its
    two sides."""
    span = (P.max(axis=0) - P.min(axis=0)).max()
    cell = max(span / 72.0, 0.012)
    grid, lo = _voxels(P, T, cell)
    D = _dirs()
    steps = np.linspace(cell * 2.2, reach, 9)
    best = np.zeros(len(P))
    for sign in (1.0, -1.0):
        n = N * sign
        cos = n @ D.T                                   # vertices x directions
        start = P + n * cell * 1.6
        hit = np.zeros(cos.shape, bool)
        for d in steps:
            q = start[:, None, :] + D[None, :, :] * d   # V x D x 3
            idx = np.floor((q - lo) / cell).astype(int)
            inside = np.all((idx >= 0) & (idx < np.array(grid.shape)), axis=2)
            idc = np.clip(idx, 0, np.array(grid.shape) - 1)
            occ = grid[idc[..., 0], idc[..., 1], idc[..., 2]] & inside
            hit |= occ | (q[..., 1] < -0.01)
        w = np.clip(cos, 0, None)
        vis = ((~hit) * w).sum(axis=1) / np.maximum(w.sum(axis=1), 1e-6)
        best = np.maximum(best, vis)
    return 1.0 - strength * (1.0 - best)


def normalise_base(m, target_width=None, target_height=None):
    P = np.array(m.p)
    lo, hi = P.min(axis=0), P.max(axis=0)
    centre = np.array([(lo[0] + hi[0]) * 0.5, lo[1], (lo[2] + hi[2]) * 0.5])
    P = P - centre
    k = 1.0
    if target_width:
        k = target_width / max(hi[0] - lo[0], hi[2] - lo[2])
    elif target_height:
        k = target_height / (hi[1] - lo[1])
    m.p = [tuple(v) for v in P * k]
    return m


def build_library():
    lib = {}
    for st in STYLES:
        # Houses: KayKit homes recoloured, mixed with flat-roofed or eaved houses built in code.
        if st == "european":
            lib[f"house_a.{st}"] = normalise_base(kaykit("building_home_A_blue", st), 1.0)
            lib[f"house_b.{st}"] = normalise_base(kaykit("building_home_B_blue", st), 1.0)
            lib[f"temple.{st}"] = normalise_base(kaykit("building_church_blue", st), 1.5)
            lib[f"landmark.{st}"] = normalise_base(kaykit("building_church_blue", st), 2.2)
        elif st in ("islamic", "indian"):
            lib[f"house_a.{st}"] = normalise_base(flat_house(st, seed=0), 0.95)
            lib[f"house_b.{st}"] = normalise_base(kaykit("building_home_B_blue", st), 0.95) if st == "islamic" \
                else normalise_base(flat_house(st, seed=1), 0.95)
            if st == "islamic":
                lib[f"temple.{st}"] = normalise_base(mosque(st), 1.6)
                lib[f"landmark.{st}"] = normalise_base(mosque(st, big=True), 2.4)
            else:
                lib[f"temple.{st}"] = normalise_base(indian_temple(st), 1.5)
                lib[f"landmark.{st}"] = normalise_base(mosque(st, big=True), 2.4)
        elif st == "eastasian":
            lib[f"house_a.{st}"] = normalise_base(east_house(st, 0), 1.0)
            lib[f"house_b.{st}"] = normalise_base(kaykit("building_home_A_blue", st), 0.95)
            lib[f"temple.{st}"] = normalise_base(pagoda(st, 3), 1.4)
            lib[f"landmark.{st}"] = normalise_base(pagoda(st, 5), 1.8)
        else:
            lib[f"house_a.{st}"] = normalise_base(yurt(st), 0.95)
            lib[f"house_b.{st}"] = normalise_base(yurt(st, r=0.4).transformed(scale=(1.0, 0.9, 1.0)), 0.8)
            lib[f"temple.{st}"] = normalise_base(yurt(st, big=True), 1.5)
            lib[f"landmark.{st}"] = normalise_base(mosque("islamic"), 2.0)
        lib[f"market.{st}"] = normalise_base(kaykit("building_market_blue", st), 1.4)

        # Forts by level: 1 = small tower, 2 = tower and walls, 3 = castle.
        if st == "steppe":
            lib[f"fort1.{st}"] = normalise_base(palisade(st), 1.6)
            lib[f"fort2.{st}"] = normalise_base(palisade(st).extend(
                kaykit("building_tower_base_blue", st, scale=0.5)), 1.9)
        else:
            lib[f"fort1.{st}"] = normalise_base(kaykit("building_tower_A_blue", st), 0.9)
            lib[f"fort2.{st}"] = normalise_base(kaykit("building_tower_B_blue", st), 1.2)
        lib[f"fort3.{st}"] = normalise_base(kaykit("building_castle_blue", st), target_height=2.6)

        lib[f"ship.{st}"] = normalise_base(ship(st))
        lib[f"sail.{st}"] = ship_sails(st)
        lib[f"soldier_gear.{st}"] = soldier_gear(st)
        lib[f"archer_gear.{st}"] = archer_gear(st)
        lib[f"rider_gear.{st}"] = rider_gear(st)
        lib[f"wall.{st}"] = stone_wall(st)
        lib[f"tower.{st}"] = wall_tower(st)
        lib[f"gate.{st}"] = gate(st)
        lib[f"keep.{st}"] = keep(st)
        lib[f"rubble.{st}"] = rubble(st)

        # Phase 20.6: town buildings and forts stand on a dark plinth.
        for kind in ("house_a", "house_b", "temple", "landmark", "market", "fort1", "fort2", "fort3"):
            lib[f"{kind}.{st}"] = with_plinth(lib[f"{kind}.{st}"], pad=0.09 if kind.startswith("fort") else 0.07)

    lib["pier"] = pier()
    lib["flag_pole"] = flag_pole()
    lib["flag_cloth"] = flag_cloth()
    lib["soldier_body"] = soldier_body()
    lib["rider_body"] = rider_body()
    lib["trebuchet"] = trebuchet()
    lib["ram"] = battering_ram()
    lib["cannon"] = cannon()
    lib["siege_tower"] = siege_tower()
    lib["ladder"] = normalise_base(kaykit("ladder", "european"), target_height=1.6)
    lib["catapult_tower"] = normalise_base(kaykit("building_tower_catapult_blue", "european"), 1.3)
    lib["palisade_wall"] = normalise_base(kaykit("fence_wood_straight", "european"), 1.0)
    lib["tree_pine"] = tree(0)
    lib["tree_leaf"] = tree(1)
    return lib


def mesh_arrays(m, ao=False):
    P = np.array(m.p, dtype=np.float32).reshape(-1, 3)
    C = np.array(m.c, dtype=np.float32).reshape(-1, 3)
    A = np.array(m.a if m.a is not None else [1.0] * len(m.p), dtype=np.float32).reshape(-1, 1)
    # Flat normals per triangle (low-poly look).
    T = P.reshape(-1, 3, 3)
    n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    n = np.where(ln > 1e-12, n / np.maximum(ln, 1e-12), np.array([0, 1, 0], np.float32))
    N = np.repeat(n, 3, axis=0).astype(np.float32)
    # Share identical corners (same place, normal and colour) between triangles.
    # Winding is not consistent between builders: the game draws both sides
    # and Godot turns the normal towards the viewer, so lighting stays right.
    key = np.concatenate([np.round(P, 4), np.round(N, 3), np.round(C, 3), np.round(A, 3)], axis=1)
    _, first, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    I = inverse.reshape(-1).astype(np.int32)
    C4 = np.concatenate([C[first], A[first]], axis=1)
    if ao:
        k = ambient_occlusion(P[first].astype(np.float64), N[first].astype(np.float64), I.reshape(-1, 3))
        C4[:, :3] *= k[:, None].astype(np.float32)
    return P[first], N[first], C4, I


def write_library(lib, path, ao=None):
    raw = bytearray()
    raw += struct.pack("<II", 1, len(lib))
    for name in sorted(lib):
        P, N, C, I = mesh_arrays(lib[name], ao=(ao is not None and name.split(".")[0] in ao))
        nb = name.encode()
        raw += struct.pack("<H", len(nb)) + nb
        raw += struct.pack("<II", len(P), len(I))
        raw += P.astype("<f4").tobytes() + N.astype("<f4").tobytes()
        raw += C.astype("<f4").tobytes() + I.astype("<i4").tobytes()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"GZMZ")
        f.write(struct.pack("<I", len(raw)))
        f.write(gzip.compress(bytes(raw), 9, mtime=0))
    return os.path.getsize(path)


# --------------------------------------------------------------------------
# Building icons (Phase 20 part 2): one small scene per building of
# data/economy/buildings.txt, made of the KayKit pieces and the models above.
# Written to tools/models/icon_models.bin (not committed; only for rendering the icons with
# godot/tools/render_building_icons.gd; the game does not load it).

ICON_OUT = os.path.join(ROOT, "tools/models/icon_models.bin")


def _k(name, x=0.0, z=0.0, scale=1.0, rot=0.0, style="european"):
    return kaykit(name, style, scale=scale, rot_y=rot, offset=(x, 0.0, z))


def _scene(*parts):
    m = Mesh()
    for p in parts:
        m.extend(p)
    return normalise_base(m, 1.0)


def _chimney(x, z, h=1.1):
    m = Mesh()
    m.frustum((x, 0.0, z), 0.12, 0.09, h, 8, (0.55, 0.42, 0.34), top_col=(0.2, 0.18, 0.16))
    return m


def _ship_with_sails(width, x, z, rot):
    return normalise_base(ship("european").extend(ship_sails("european")), width).transformed(offset=(x, 0, z), rot_y=rot)


def building_icon_models():
    isl = "islamic"
    P = 1.8   # props drawn larger than life so they read at icon size
    lib = {}
    lib["farm_estate"] = _scene(_k("building_grain", 0.0, 0.2), _k("building_home_A_blue", -0.45, -0.3, 0.6))
    lib["mine"] = _scene(_k("building_mine_blue"))
    lib["plantation"] = _scene(_k("building_grain", 0.0, 0.25), _k("building_home_B_blue", -0.45, -0.35, 0.55, style=isl),
                               _k("tree_single_A", 0.5, -0.4, 0.8))
    lib["pasture"] = _scene(_k("fence_wood_straight", 0.0, 0.45), _k("fence_wood_straight", 0.45, 0.0, rot=math.pi / 2),
                            _k("building_home_B_blue", -0.3, -0.3, 0.55), _k("sack", 0.25, 0.15, 3.0))
    lib["vineyard"] = _scene(_k("trees_A_small", -0.3, 0.1, 0.7), _k("trees_A_small", 0.35, 0.1, 0.7),
                             _k("fence_wood_straight", 0.0, 0.55), _k("barrel", 0.35, -0.4, P))
    lib["forestry"] = _scene(_k("building_lumbermill_blue"))
    lib["fishery"] = _scene(normalise_base(pier(), 1.0), _ship_with_sails(0.75, 0.3, 0.2, 0.6))
    lib["brewery"] = _scene(_k("building_tavern_blue"), _k("barrel", 0.7, 0.5, P))
    for key, house, prop, ps, st in [("weaver", "building_home_B_blue", "crate_open", 1.4, "european"),
                                     ("linen_weaver", "building_home_A_blue", "sack", 3.0, "european"),
                                     ("bookmakers", "building_home_A_blue", "crate_A_big", 1.2, "european"),
                                     ("potters", "building_home_A_blue", "barrel", P, "european"),
                                     ("goldsmiths", "building_home_B_blue", "crate_A_big", 1.2, "european"),
                                     ("tannery", "building_home_A_blue", "resource_lumber", 1.0, "european"),
                                     ("cotton_weaver", "building_home_B_blue", "sack", 3.0, isl),
                                     ("silk_weaver", "building_home_B_blue", "crate_open", 1.4, "eastasian"),
                                     ("carpet_maker", "building_home_A_blue", "crate_open", 1.4, isl),
                                     ("glassworks", "building_home_B_blue", "barrel", P, "european")]:
        lib[key] = _scene(_k(house, style=st), _k(prop, 0.55, 0.45, ps))
    lib["glassworks"].extend(normalise_base(_chimney(0, 0), None, 0.9).transformed(offset=(-0.35, 0, -0.3)))
    lib["smithy"] = _scene(_k("building_blacksmith_blue"))
    lib["armourer"] = _scene(_k("building_blacksmith_blue"), _k("weaponrack", 0.7, 0.55, 1.2))
    lib["powder_mill"] = _scene(_k("building_windmill_blue"), _k("barrel", 0.55, 0.5, P))
    lib["foundry"] = _scene(_k("building_blacksmith_blue"), normalise_base(cannon(), 0.6).transformed(offset=(0.7, 0, 0.6)))
    lib["paper_mill"] = _scene(_k("building_watermill_blue"))
    lib["ropewalk"] = _scene(_k("barrel", -0.25, 0.0, P), _k("barrel", 0.2, 0.15, P), _k("resource_lumber", 0.0, -0.4))
    lib["market_hall"] = _scene(_k("building_market_blue"))
    lib["guild_hall"] = _scene(_k("building_home_B_blue", 0.0, 0.0, 1.2), normalise_base(flag_pole(), None, 1.2).transformed(offset=(0.55, 0, 0.35)),
                               normalise_base(flag_cloth(), None, 1.2).transformed(offset=(0.55, 0, 0.35)))
    lib["port"] = _scene(normalise_base(pier(), 1.0), _ship_with_sails(0.8, 0.25, 0.25, 0.4), _k("crate_A_big", -0.35, -0.3, 1.2))
    lib["road"] = _scene(_k("fence_stone_straight", 0.0, -0.3), _k("wheelbarrow", -0.2, 0.25, 1.5), _k("resource_stone", 0.35, 0.2))
    lib["caravanserai"] = _scene(_k("building_home_B_blue", -0.3, -0.2, 1.0, style=isl), _k("building_home_A_blue", 0.45, -0.25, 0.8, style=isl),
                                 _k("tent", 0.4, 0.5, 0.8))
    lib["temple"] = _scene(_k("building_church_blue"))
    lib["college"] = _scene(_k("building_church_blue", 0.2, 0.0, 0.9), _k("building_home_A_blue", -0.5, 0.3, 0.6))
    lib["fort"] = _scene(_k("building_castle_blue"))
    lib["barracks"] = _scene(_k("building_barracks_blue"))
    lib["shipyard"] = _scene(_k("building_scaffolding"), _ship_with_sails(0.7, 0.1, 0.35, 0.0))
    return lib


def write_icon_models():
    lib = building_icon_models()
    size = write_library(lib, ICON_OUT)
    print(f"wrote {ICON_OUT}: {len(lib)} building scenes, {size / 1e6:.2f} MB")


def main():
    lib = build_library()
    size = write_library(lib, OUT, ao=AO_MESHES)
    tris = sum(len(m.p) // 3 for m in lib.values())
    print(f"wrote {OUT}: {len(lib)} meshes, {tris} triangles, {size / 1e6:.2f} MB")


if __name__ == "__main__":
    import sys
    if "--icons" in sys.argv:
        write_icon_models()
    else:
        main()
