#!/usr/bin/env python3
"""Height map for the 3D map (Phase 17).

Inputs
  data/terrain/elevation.png       (16-bit, metres + 12000; from fetch_elevation.py)
  Packages/GezCore/Sources/GezCore/Resources/provinces1453.idmap
Output
  App/Resources/Terrain/height.png  (8-bit grey, half the map size)

Encoding: value = sqrt(height / 6000 m), so low hills keep some detail.
The sea is 0; land is at least 2/255 so coasts sit above the water. Lakes
(water outside every sea zone) lie flat at their own surface height (Phase
20.7: Lake Namtso is 4,700 m up on the Tibetan plateau, not a pit).
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
    # Unknown land (sea-map value 0xFFFF, Phase 20.7) lies flat, like paper.
    seas = load_idmap(os.path.join(ROOT, "Packages/GezCore/Sources/GezCore/Resources/seas1453.idmap"))
    unknown = (seas == 0xFFFF) & (ids == 1)
    lake = (ids == 0) & (seas == 0)
    del seas
    h = np.where(land & ~unknown, np.clip(elev, 0, ELEV_MAX), 0.0).astype(np.float32)
    # Each lake lies flat at its mean surface height.
    labels, n = ndimage.label(lake)
    if n:
        level = np.asarray(ndimage.mean(np.clip(elev, 0, ELEV_MAX), labels, np.arange(1, n + 1)), dtype=np.float32)
        h = np.where(lake, np.concatenate([[0.0], level]).astype(np.float32)[labels], h)
    del labels
    # Soften single-pixel spikes; keep the coast sharp by blurring land and
    # lakes only (never pulling in the sea floor's 0).
    solid = land | lake
    w = ndimage.gaussian_filter(solid.astype(np.float32), 1.0)
    hs = ndimage.gaussian_filter(h, 1.0) / np.maximum(w, 1e-3)
    hs = np.where(land, hs, np.where(lake, h, 0.0))
    H, W = hs.shape
    hs = hs[: H - H % SCALE, : W - W % SCALE]
    small = hs.reshape(H // SCALE, SCALE, W // SCALE, SCALE).mean(axis=(1, 3))
    def share(mask):
        return mask[: H - H % SCALE, : W - W % SCALE].reshape(H // SCALE, SCALE, W // SCALE, SCALE).mean(axis=(1, 3))
    land_small = share(land) > 0.5
    solid_small = share(solid) > 0.5
    v = np.sqrt(np.clip(small / ELEV_MAX, 0, 1)) * 255.0
    v = np.where(land_small, np.maximum(v, 2.0), np.where(solid_small, v, 0.0))
    out = os.path.join(ROOT, "App/Resources/Terrain/height.png")
    Image.fromarray(np.round(v).astype(np.uint8), "L").save(out, optimize=True)
    print("wrote", out, v.shape[::-1])


if __name__ == "__main__":
    main()
