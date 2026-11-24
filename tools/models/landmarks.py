"""Phase 20.7: named landmarks for the map, built in code (no outside art).

One model per famous building, drawn in the same low-poly, flat-shaded
look as the towns (tools/models/build_models.py). Units: one unit is about
the width of a house; y is up, the model stands on y = 0, +x is east.

Hagia Sophia (Konstantiniyye), from its real proportions (about 80 m
across, central dome 31 m wide and 55 m high), at 0.0375 units a metre:
a square core carrying the central dome on a ring of 40 windows and
buttresses, half-domes east and west (with smaller exedra half-domes),
the massive stepped buttresses on the north and south sides, the apse
to the east and the double narthex to the west, all under lead roofs.
Minarets are an option (`minarets`): 0 = as it stood until 29 May 1453;
1 = Mehmed II's red-brick minaret at the south-east corner, put up after
the conquest; 4 = all four of the later Ottoman minarets.
"""
import math

from build_models import Mesh, shade

PLASTER = (0.86, 0.70, 0.54)   # weathered ochre-pink plaster
STONE = (0.78, 0.72, 0.64)
LEAD = (0.56, 0.60, 0.64)      # lead-covered domes and roofs
BRICK = (0.66, 0.38, 0.27)
WHITE_STONE = (0.92, 0.90, 0.85)
DARK = (0.22, 0.19, 0.17)      # window openings
GOLD = (0.84, 0.68, 0.30)


def partial_dome(m, center, r, col, a0, a1, segs=12, rings=5, squash=1.0):
    """Part of a dome between angles a0..a1 (radians, around y; 0 = +z)."""
    cx, cy, cz = center

    def pt(ring, i):
        t = ring / rings * (math.pi / 2)
        a = a0 + (a1 - a0) * i / segs
        rr = r * math.cos(t)
        return (cx + rr * math.sin(a), cy + r * squash * math.sin(t), cz + rr * math.cos(a))

    for ring in range(rings):
        for i in range(segs):
            a, b = pt(ring, i), pt(ring, i + 1)
            c, d = pt(ring + 1, i + 1), pt(ring + 1, i)
            if ring == rings - 1:
                m.tri(a, b, c, col)
            else:
                m.quad(a, b, c, d, col)
    # flat back wall closing a half-dome
    if abs((a1 - a0) - 2 * math.pi) > 1e-6:
        pts = [pt(ring, 0) for ring in range(rings + 1)]
        pts2 = [pt(ring, segs) for ring in range(rings + 1)]
        for ring in range(rings):
            m.tri((cx, cy, cz), pts[ring + 1], pts[ring], shade(col, 0.9))
            m.tri((cx, cy, cz), pts2[ring], pts2[ring + 1], shade(col, 0.9))
    return m


def arch_wall(m, center, width, rise, thick, col, axis="x", segs=8):
    """A semicircular tympanum wall standing on `center` (its base midpoint).
    axis: the wall runs along x or z."""
    cx, cy, cz = center
    r = width * 0.5
    prof = [(r * math.cos(math.pi * i / segs), rise / r * r * math.sin(math.pi * i / segs)) for i in range(segs + 1)]
    for i in range(segs):
        (x0, y0), (x1, y1) = prof[i], prof[i + 1]
        for s in (-1, 1):
            if axis == "x":
                a, b = (cx + x0, cy, cz + s * thick / 2), (cx + x1, cy, cz + s * thick / 2)
                c, d = (cx + x1, cy + y1, cz + s * thick / 2), (cx + x0, cy + y0, cz + s * thick / 2)
            else:
                a, b = (cx + s * thick / 2, cy, cz + x0), (cx + s * thick / 2, cy, cz + x1)
                c, d = (cx + s * thick / 2, cy + y1, cz + x1), (cx + s * thick / 2, cy + y0, cz + x0)
            m.quad(a, b, c, d, col)
        # the curved top, in lead
        if axis == "x":
            p = [(cx + x0, cy + y0, cz - thick / 2), (cx + x1, cy + y1, cz - thick / 2),
                 (cx + x1, cy + y1, cz + thick / 2), (cx + x0, cy + y0, cz + thick / 2)]
        else:
            p = [(cx - thick / 2, cy + y0, cz + x0), (cx - thick / 2, cy + y1, cz + x1),
                 (cx + thick / 2, cy + y1, cz + x1), (cx + thick / 2, cy + y0, cz + x0)]
        m.quad(*p, LEAD)
    return m


def ottoman_minaret(m, base, h, col, balconies=1, r=0.06, cap=LEAD):
    """Slender 'pencil' minaret: square foot, shaft, balconies, lead cone."""
    x, y, z = base
    m.box((x, y + 0.12, z), (r * 3.2, 0.24, r * 3.2), col)
    m.frustum((x, y + 0.24, z), r * 1.15, r, h - 0.24, 12, col)
    for k in range(balconies):
        by = y + h * (0.70 + 0.11 * k) - 0.02 * balconies
        m.frustum((x, by, z), r * 1.9, r * 1.9, 0.045, 12, shade(col, 0.82))
    m.frustum((x, y + h, z), r * 1.05, 0.0, h * 0.20, 12, cap)
    m.frustum((x, y + h * 1.20, z), 0.012, 0.0, 0.08, 4, GOLD)
    return m


def hagia_sophia(minarets=0):
    m = Mesh()
    # Main body: aisles and galleries under lead roofs.
    m.box((0.05, 0.42, 0), (2.5, 0.84, 2.36), PLASTER, top_col=LEAD)
    # West: outer and inner narthex, lower.
    m.box((-1.38, 0.34, 0), (0.26, 0.68, 2.2), shade(PLASTER, 0.96), top_col=LEAD)
    m.box((-1.62, 0.25, 0), (0.22, 0.50, 2.0), shade(PLASTER, 0.92), top_col=LEAD)
    # East: the apse, a half-round with its own half-dome.
    m.frustum((1.30, 0, 0), 0.30, 0.30, 0.80, 14, PLASTER, cap_top=False)
    partial_dome(m, (1.30, 0.80, 0), 0.30, LEAD, 0.0, math.pi, segs=8, rings=3, squash=0.75)
    # The square core rising over the nave to carry the dome.
    core_top = 1.30
    m.box((0, (0.84 + core_top) / 2, 0), (1.24, core_top - 0.84, 1.24), PLASTER, top_col=LEAD)
    # The four great arches carrying the dome: north and south walled in
    # (tympana with windows), east and west opening onto the half-domes.
    for s in (-1, 1):
        arch_wall(m, (0, core_top, s * 0.58), 1.10, 0.36, 0.10, shade(PLASTER, 0.97), axis="x")
        arch_wall(m, (s * 0.58, core_top, 0), 1.10, 0.36, 0.10, shade(PLASTER, 0.97), axis="z")
        # rows of windows in the tympanum
        for i in range(5):
            x = -0.36 + i * 0.18
            m.box((x, core_top + 0.10, s * 0.64), (0.07, 0.12, 0.02), DARK)
    # The four great stepped buttresses north and south.
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 0.52, sz * 1.30
            m.box((x, 0.56, z), (0.36, 1.12, 0.34), shade(PLASTER, 0.94), top_col=LEAD)
            m.box((x, 1.18, z - sz * 0.06), (0.30, 0.12, 0.20), shade(PLASTER, 0.94), top_col=LEAD)
            m.box((x, 0.32, z + sz * 0.22), (0.30, 0.64, 0.16), shade(PLASTER, 0.90), top_col=LEAD)
    # East and west half-domes, each with two smaller exedra half-domes.
    for sx in (-1, 1):
        a0 = math.pi * 0.0 if sx > 0 else math.pi
        partial_dome(m, (sx * 0.62, 1.16, 0), 0.60, LEAD, a0, a0 + math.pi, segs=12, rings=4, squash=0.62)
        for sz in (-1, 1):
            partial_dome(m, (sx * 0.98, 0.84, sz * 0.42), 0.28, LEAD,
                         math.atan2(sx, sz * 0.4) - math.pi / 2, math.atan2(sx, sz * 0.4) + math.pi / 2,
                         segs=6, rings=3, squash=0.6)
    # The drum: a ring of 40 windows between little buttresses.
    drum_y = core_top + 0.18
    m.frustum((0, core_top, 0), 0.62, 0.62, drum_y - core_top, 20, PLASTER, top_col=LEAD)
    for i in range(20):
        a = 2 * math.pi * (i + 0.5) / 20
        m.box((0.63 * math.sin(a), drum_y + 0.05, 0.63 * math.cos(a)), (0.06, 0.12, 0.06), PLASTER,
              rot_y=a, top_col=LEAD)
        b = 2 * math.pi * i / 20
        m.box((0.60 * math.sin(b), drum_y + 0.05, 0.60 * math.cos(b)), (0.06, 0.07, 0.01), DARK, rot_y=b)
    # The great dome, shallow as it really is, under lead.
    partial_dome(m, (0, drum_y + 0.02, 0), 0.60, LEAD, 0.0, 2 * math.pi, segs=20, rings=5, squash=0.50)
    m.frustum((0, drum_y + 0.02 + 0.30, 0), 0.03, 0.0, 0.14, 6, GOLD)
    # Minarets (optional; see the module notes).
    if minarets >= 1:   # Mehmed II, south-east, red brick
        ottoman_minaret(m, (1.42, 0, 1.30), 2.05, BRICK, balconies=1)
    if minarets >= 4:   # Bayezid II north-east; Selim II / Murad III west
        ottoman_minaret(m, (1.42, 0, -1.30), 2.15, WHITE_STONE, balconies=1)
        ottoman_minaret(m, (-1.80, 0, 1.20), 2.35, WHITE_STONE, balconies=2)
        ottoman_minaret(m, (-1.80, 0, -1.20), 2.35, WHITE_STONE, balconies=2)
    return m
