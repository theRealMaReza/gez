#!/usr/bin/env python3
"""Height map for the 3D map (Phase 17).

Inputs
  data/terrain/elevation.png       (16-bit, metres + 12000; from fetch_elevation.py)
  Packages/GezCore/Sources/GezCore/Resources/provinces1453.idmap
Output
  App/Resources/Terrain/height.png  (8-bit grey, half the map size)

Encoding: value = sqrt(height / 6000 m), so low hills keep some detail.
Sea and lakes are 0; land is at least 2/255 so coasts sit above the water.
The Godot map (godot/scripts/MapProjector.gd, shaders/map3d.gdshader)
decodes it as value^2 * HEIGHT_MAX world units.

Run after bake_terrain.py whenever the elevation or the map changes:
  python3 tools/terrain/bake_heightmap.py
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OFFSET = 12000
ELEV_MAX = 6000.0
SCALE = 2  # output is 1/SCALE of the map size


def load_idmap(path):
    b = open(path, "rb").read()
    w, h, n = np.frombuffer(b[4:16], "<u4")
    runs = np.frombuffer(b[16:], "<u2").reshape(-1, 2)
    return np.repeat(runs[:, 0], runs[:, 1]).reshape(h, w).astype(np.int32)


def main():
    elev = np.array(Image.open(os.path.join(ROOT, "data/terrain/elevation.png"))).astype(np.float32) - OFFSET
    ids = load_idmap(os.path.join(ROOT, "Packages/GezCore/Sources/GezCore/Resources/provinces1453.idmap"))
    assert elev.shape == ids.shape, "elevation and province map sizes differ"
    land = ids != 0
    h = np.where(land, np.clip(elev, 0, ELEV_MAX), 0.0)
    # Soften single-pixel spikes; keep the coast sharp by blurring land only.
    w = ndimage.gaussian_filter(land.astype(np.float32), 1.0)
    hs = ndimage.gaussian_filter(h, 1.0) / np.maximum(w, 1e-3)
    hs = np.where(land, hs, 0.0)
    H, W = hs.shape
    hs = hs[: H - H % SCALE, : W - W % SCALE]
    small = hs.reshape(H // SCALE, SCALE, W // SCALE, SCALE).mean(axis=(1, 3))
    land_small = land[: H - H % SCALE, : W - W % SCALE].reshape(H // SCALE, SCALE, W // SCALE, SCALE).mean(axis=(1, 3)) > 0.5
    v = np.sqrt(np.clip(small / ELEV_MAX, 0, 1)) * 255.0
    v = np.where(land_small, np.maximum(v, 2.0), 0.0)
    out = os.path.join(ROOT, "App/Resources/Terrain/height.png")
    Image.fromarray(np.round(v).astype(np.uint8), "L").save(out, optimize=True)
    print("wrote", out, v.shape[::-1])


if __name__ == "__main__":
    main()
