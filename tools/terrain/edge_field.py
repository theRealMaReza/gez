"""Phase 20.7: the border distance field the map shader draws lines from.

For every map pixel: how far (in map pixels) its centre is from the nearest
edge of its own province. On water the only edges are coasts, so there it is
the distance to the coast. The edge runs half-way between two neighbouring
pixels of different provinces (and through the corners where they meet), so
the shader can rebuild a smooth signed distance across it: positive on its
own side, negative on the far side (font-SDF style). Province shapes never
change during a game, so this is baked once; who owns a province does
change, so the shader still looks up owners and states, but only next to an
edge.

Stored as one 8-bit channel, square-root encoded so it is fine near the
edge (about 1/14 pixel) and coarse far away:
    value = round(255 * sqrt(min(d, DMAX) / DMAX)),  d = DMAX * (value/255)^2
DMAX must match EDGE_DMAX in godot/shaders/map3d.gdshader.
"""
import numpy as np
from scipy import ndimage

DMAX = 160.0   # map pixels: widest country band / coast ripple when zoomed out
SMOOTH = 1.2   # pixels: signed blur that rounds off the 1-pixel steps of the map
FLOOR = 0.3    # every pixel centre stays this far inside its own province, so
               # one-pixel straits and islets never vanish


def edge_points(ids):
    """Edge points on a grid twice as fine as the map (pixel centres at even
    coordinates): midpoints between 4-neighbours of different id, and the
    corner points where they meet."""
    h, w = ids.shape
    horiz = ids[:, 1:] != ids[:, :-1]          # (h, w-1)
    vert = ids[1:, :] != ids[:-1, :]           # (h-1, w)
    mask = np.zeros((2 * h - 1, 2 * w - 1), dtype=bool)
    mask[0::2, 1::2] = horiz
    mask[1::2, 0::2] = vert
    mask[1::2, 1::2] = horiz[1:, :] | horiz[:-1, :] | vert[:, 1:] | vert[:, :-1]
    return mask


def distance_rows(ids):
    """Distance (map pixels, float32) from each pixel centre to its nearest edge."""
    mask = edge_points(ids)
    if not mask.any():
        return np.full(ids.shape, DMAX, dtype=np.float32)
    d2 = ndimage.distance_transform_edt(~mask)
    return (d2[0::2, 0::2] * 0.5).astype(np.float32)


def smooth_rows(ids, d, sigma=SMOOTH, floor=FLOOR):
    """Blur the distance as seen from each pixel's own province (neighbours of
    another province count negative), which turns the map's pixel steps into
    smooth curves; then keep every pixel at least `floor` inside its own side."""
    r = int(np.ceil(2.5 * sigma))
    h, w = ids.shape
    pid = np.pad(ids, r, mode="edge")
    pd = np.pad(d, r, mode="edge")
    acc = np.zeros_like(d)
    total = 0.0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            g = float(np.exp(-(dx * dx + dy * dy) / (2 * sigma * sigma)))
            total += g
            sid = pid[r + dy:r + dy + h, r + dx:r + dx + w]
            sd = pd[r + dy:r + dy + h, r + dx:r + dx + w]
            acc += np.where(sid == ids, sd, -sd) * g
    return np.maximum(acc / total, floor)


def encode(d):
    return np.round(255.0 * np.sqrt(np.clip(d, 0.0, DMAX) / DMAX)).astype(np.uint8)


def decode(v):
    return DMAX * (v.astype(np.float32) / 255.0) ** 2


def bake(ids, strip=512):
    """Whole map in strips of rows, each with a margin of DMAX, so the result
    matches doing it at once while memory stays bounded."""
    h, w = ids.shape
    out = np.zeros((h, w), dtype=np.uint8)
    margin = int(DMAX) + 8
    for y0 in range(0, h, strip):
        y1 = min(h, y0 + strip)
        a, b = max(0, y0 - margin), min(h, y1 + margin)
        d = smooth_rows(ids[a:b], distance_rows(ids[a:b]))
        out[y0:y1] = encode(d[y0 - a:y1 - a])
    return out
