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


# Additional palette tones for regional 1453 landmarks.
TERRACOTTA = (0.76, 0.36, 0.22)
GREEN_MARBLE = (0.26, 0.36, 0.28)
LIMESTONE = (0.82, 0.78, 0.70)
SANDSTONE = (0.84, 0.72, 0.52)
RED_SANDSTONE = (0.72, 0.34, 0.24)
TURQUOISE = (0.16, 0.58, 0.64)
CRIMSON = (0.64, 0.16, 0.14)
IMPERIAL_GOLD = (0.88, 0.68, 0.20)
DARK_SLATE = (0.24, 0.27, 0.30)
CELADON = (0.34, 0.52, 0.44)
POND_BLUE = (0.22, 0.42, 0.50)
WOOD = (0.48, 0.33, 0.20)


def florence_cathedral():
    """Santa Maria del Fiore (Florence, 1453).
    Real proportions: nave 153 m long, 38 m wide; Brunelleschi's octagonal dome
    (completed 1436) 45.5 m wide, ~91 m high (lantern under construction in 1453);
    Giotto's Campanile (completed 1359) 84.7 m tall, 14.5 m square to the south-west.
    Scale: ~0.02 units/m."""
    m = Mesh()
    # Nave and side aisles (west along -x, crossing at +x).
    m.box((-0.65, 0.30, 0), (1.70, 0.60, 0.84), WHITE_STONE, top_col=TERRACOTTA)
    m.box((-0.65, 0.58, 0), (1.66, 0.28, 0.46), WHITE_STONE)
    m.gable_roof((-0.65, 0.72, 0), 1.66, 0.46, 0.20, TERRACOTTA, overhang=0.03, gable_col=WHITE_STONE)
    # Tuscan green marble horizontal bands along nave.
    m.box((-0.65, 0.42, 0), (1.72, 0.05, 0.86), GREEN_MARBLE)
    # West facade (unfinished raw stone lower half in 1453, no 19th-c. marble facade).
    m.box((-1.51, 0.34, 0), (0.08, 0.68, 0.84), STONE)
    # Octagonal crossing drum + three tribune exedrae (north, south, east).
    cx = 0.55
    m.frustum((cx, 0, 0), 0.56, 0.56, 0.92, 8, WHITE_STONE, top_col=STONE, rot=math.pi / 8)
    m.frustum((cx, 0.68, 0), 0.57, 0.57, 0.06, 8, GREEN_MARBLE, cap_top=False, rot=math.pi / 8)
    for dx, dz in ((0.62, 0), (0, 0.62), (0, -0.62)):
        m.frustum((cx + dx, 0, dz), 0.34, 0.34, 0.56, 6, WHITE_STONE, top_col=TERRACOTTA)
        m.frustum((cx + dx, 0.56, dz), 0.34, 0.06, 0.22, 6, TERRACOTTA)
    # Brunelleschi's pointed octagonal terracotta dome (stacked tapering frustums).
    r_prev, y_prev = 0.54, 0.92
    for r_next, dy in ((0.48, 0.26), (0.37, 0.26), (0.22, 0.22), (0.11, 0.14)):
        m.frustum((cx, y_prev, 0), r_prev, r_next, dy, 8, TERRACOTTA, cap_top=False, rot=math.pi / 8)
        r_prev, y_prev = r_next, y_prev + dy
    # Marble lantern (begun 1446, rising in 1453).
    m.frustum((cx, y_prev, 0), 0.12, 0.11, 0.20, 8, WHITE_STONE, top_col=WHITE_STONE, rot=math.pi / 8)
    m.frustum((cx, y_prev + 0.20, 0), 0.08, 0.0, 0.12, 8, WHITE_STONE, rot=math.pi / 8)
    # Giotto's Campanile (detached square bell tower south-west of facade).
    tx, tz = -1.35, 0.72
    m.box((tx, 0.85, tz), (0.30, 1.70, 0.30), WHITE_STONE, top_col=TERRACOTTA)
    for by in (0.40, 0.80, 1.20, 1.56):
        m.box((tx, by, tz), (0.32, 0.04, 0.32), GREEN_MARBLE)
    m.box((tx, 1.40, tz), (0.10, 0.22, 0.32), DARK)
    m.box((tx, 1.40, tz), (0.32, 0.22, 0.10), DARK)
    return m


def notre_dame():
    """Notre-Dame de Paris (Paris, 1453).
    Real proportions: 128 m long, 48 m transept width, twin square west towers
    69 m high (flat tops), medieval crossing fleche ~78 m high. Scale: ~0.02 units/m."""
    m = Mesh()
    # Nave & choir body.
    m.box((0.15, 0.42, 0), (2.10, 0.84, 0.84), LIMESTONE, top_col=LEAD)
    m.gable_roof((0.15, 0.84, 0), 2.06, 0.52, 0.28, LEAD, overhang=0.02, gable_col=LIMESTONE)
    # Apse (east end).
    m.frustum((1.20, 0, 0), 0.40, 0.40, 0.80, 10, LIMESTONE, top_col=LEAD)
    # Transept (north-south crossing).
    m.box((0.10, 0.44, 0), (0.42, 0.88, 1.12), LIMESTONE, top_col=LEAD)
    m.gable_roof((0.10, 0.88, 0), 1.12, 0.42, 0.24, LEAD, overhang=0.02, gable_col=LIMESTONE, rot_y=math.pi / 2)
    # Flying buttresses along nave and choir.
    for x in (-0.45, -0.15, 0.45, 0.75, 1.02):
        for s in (-1, 1):
            m.box((x, 0.36, s * 0.48), (0.08, 0.72, 0.12), shade(LIMESTONE, 0.92), top_col=LEAD)
    # Twin flat-topped west towers (69 m).
    for s in (-1, 1):
        m.box((-0.96, 0.70, s * 0.28), (0.36, 1.40, 0.34), LIMESTONE, top_col=LEAD)
        m.box((-1.15, 1.08, s * 0.28), (0.02, 0.26, 0.12), DARK)
        m.box((-1.15, 0.20, s * 0.28), (0.02, 0.24, 0.14), DARK)
    # West facade centre + rose window + portal.
    m.box((-0.96, 0.46, 0), (0.32, 0.92, 0.26), LIMESTONE, top_col=LEAD)
    m.box((-1.13, 0.20, 0), (0.02, 0.26, 0.16), DARK)
    m.box((-1.13, 0.62, 0), (0.02, 0.18, 0.18), DARK)
    # Medieval wooden crossing fleche (standing in 1453).
    m.frustum((0.10, 1.08, 0), 0.08, 0.0, 0.62, 8, LEAD)
    return m


def cologne_cathedral():
    """Cologne Cathedral (Cologne, 1453 — unfinished with its famous crane).
    Real proportions: completed east choir (61 m ridge, 43 m vaults) with apse
    and flying buttresses; low unfinished nave walls; half-built south-west tower
    (~56 m) topped by the wooden Domkran (treadwheel crane). Scale: ~0.02 units/m."""
    m = Mesh()
    # Completed Gothic choir (east half).
    m.box((0.68, 0.48, 0), (0.96, 0.96, 0.86), STONE, top_col=LEAD)
    m.gable_roof((0.68, 0.96, 0), 0.94, 0.56, 0.34, LEAD, overhang=0.02, gable_col=STONE)
    m.frustum((1.16, 0, 0), 0.42, 0.42, 0.94, 10, STONE, top_col=LEAD)
    for x in (0.35, 0.65, 0.95):
        for s in (-1, 1):
            m.box((x, 0.42, s * 0.49), (0.08, 0.84, 0.12), shade(STONE, 0.90), top_col=LEAD)
    # Unfinished nave: low stub walls & foundations.
    m.box((-0.25, 0.14, 0), (0.92, 0.28, 0.84), shade(STONE, 0.88), top_col=shade(STONE, 0.78))
    # North-west tower: barely above ground in 1453.
    m.box((-0.96, 0.18, -0.32), (0.42, 0.36, 0.42), shade(STONE, 0.90), top_col=shade(STONE, 0.78))
    # South-west tower: half-built (~56 m) with flat top.
    tx, tz = -0.96, 0.32
    m.box((tx, 0.58, tz), (0.44, 1.16, 0.44), STONE, top_col=shade(STONE, 0.82))
    m.box((tx - 0.23, 0.30, tz), (0.02, 0.34, 0.16), DARK)
    m.box((tx - 0.23, 0.80, tz), (0.02, 0.28, 0.14), DARK)
    # The famous Domkran (wooden treadwheel crane perched on the south tower).
    m.box((tx, 1.32, tz), (0.10, 0.32, 0.10), WOOD)
    m.box((tx + 0.16, 1.46, tz), (0.48, 0.06, 0.06), WOOD, rot_y=0.25)
    m.box((tx + 0.34, 1.32, tz - 0.04), (0.02, 0.24, 0.02), DARK)
    return m


def westminster_abbey():
    """Westminster Abbey (London, 1453).
    Real proportions: cruciform Gothic abbey (~156 m long, 34 m nave roof,
    61 m transept), NO Hawksmoor west towers (1722) and NO Henry VII Lady Chapel
    (1503). Octagonal Chapter House on the south-east side. Scale: ~0.018 units/m."""
    m = Mesh()
    # Long nave & choir.
    m.box((0.0, 0.36, 0), (2.20, 0.72, 0.64), LIMESTONE, top_col=LEAD)
    m.gable_roof((0.0, 0.72, 0), 2.18, 0.46, 0.24, LEAD, overhang=0.02, gable_col=LIMESTONE)
    # Prominent north & south transepts.
    m.box((0.22, 0.38, 0), (0.42, 0.76, 1.18), LIMESTONE, top_col=LEAD)
    m.gable_roof((0.22, 0.76, 0), 1.18, 0.42, 0.22, LEAD, overhang=0.02, gable_col=LIMESTONE, rot_y=math.pi / 2)
    # East apse (pre-Henry VII Lady Chapel).
    m.frustum((1.10, 0, 0), 0.30, 0.30, 0.66, 8, LIMESTONE, top_col=LEAD)
    # Low unfinished medieval west front (stubby tower bases only).
    for s in (-1, 1):
        m.box((-1.06, 0.44, s * 0.22), (0.24, 0.88, 0.22), LIMESTONE, top_col=LEAD)
    m.box((-1.19, 0.18, 0), (0.02, 0.24, 0.14), DARK)
    # Flying buttresses along nave.
    for x in (-0.75, -0.45, -0.15, 0.65, 0.90):
        for s in (-1, 1):
            m.box((x, 0.30, s * 0.38), (0.07, 0.60, 0.10), shade(LIMESTONE, 0.92), top_col=LEAD)
    # Octagonal Chapter House (south-east).
    m.frustum((0.76, 0, 0.68), 0.28, 0.28, 0.48, 8, LIMESTONE, top_col=LEAD)
    m.frustum((0.76, 0.48, 0.68), 0.30, 0.0, 0.26, 8, LEAD)
    return m


def alhambra():
    """The Alhambra (Granada, 1453).
    Nasrid red-earth hilltop palace-fortress (no 1527 Palace of Charles V):
    Torre de la Vela (west Alcazaba), Torre de Comares (45 m, north-east),
    crenellated red curtain walls and Nasrid courtyard palaces with terracotta roofs."""
    m = Mesh()
    # Hilltop terrace / fortified perimeter walls.
    m.box((0.0, 0.22, 0.0), (2.40, 0.44, 1.30), RED_SANDSTONE, top_col=SANDSTONE)
    # Alcazaba (west fortress) + Torre de la Vela.
    m.box((-0.96, 0.48, 0.0), (0.56, 0.96, 0.96), RED_SANDSTONE, top_col=SANDSTONE)
    m.box((-1.12, 0.72, 0.26), (0.34, 1.44, 0.34), RED_SANDSTONE, top_col=SANDSTONE)
    # Nasrid Palaces (central courtyard pavilions with hip roofs).
    m.box((0.15, 0.46, -0.34), (1.10, 0.36, 0.42), SANDSTONE)
    m.hip_roof((0.15, 0.64, -0.34), 1.10, 0.42, 0.16, TERRACOTTA, overhang=0.04)
    m.box((0.15, 0.46, 0.34), (1.10, 0.36, 0.42), SANDSTONE)
    m.hip_roof((0.15, 0.64, 0.34), 1.10, 0.42, 0.16, TERRACOTTA, overhang=0.04)
    # Reflecting pool in the Court of the Myrtles.
    m.box((0.15, 0.45, 0.0), (0.76, 0.02, 0.22), POND_BLUE)
    # Torre de Comares (tallest Nasrid tower, 45 m, north-east).
    m.box((0.92, 0.78, -0.26), (0.48, 1.56, 0.48), RED_SANDSTONE, top_col=SANDSTONE)
    for dy in (0.90, 1.18):
        m.box((0.92, dy, -0.51), (0.18, 0.12, 0.02), DARK)
    # East wall watchtower.
    m.box((1.06, 0.56, 0.36), (0.32, 1.12, 0.32), RED_SANDSTONE, top_col=SANDSTONE)
    return m


def pyramids_of_giza():
    """Pyramids of Giza (Cairo, 1453).
    Real proportions: Khufu (146 m high, 230 m base), Khafre (143 m high, 215 m base,
    with its surviving smooth white limestone cap at the peak), Menkaure (65 m high,
    105 m base) on their diagonal, plus a small Sphinx in front. Scale: ~0.0055 units/m."""
    m = Mesh()
    # Khufu (Great Pyramid, north-east).
    m.frustum((0.62, 0, -0.56), 0.90, 0.0, 0.88, 4, SANDSTONE, rot=math.pi / 4)
    # Khafre (centre, with smooth white limestone cap at the top).
    m.frustum((-0.18, 0, 0.12), 0.84, 0.22, 0.64, 4, shade(SANDSTONE, 0.96), cap_top=False, rot=math.pi / 4)
    m.frustum((-0.18, 0.64, 0.12), 0.22, 0.0, 0.22, 4, WHITE_STONE, rot=math.pi / 4)
    # Menkaure (south-west).
    m.frustum((-0.86, 0, 0.72), 0.42, 0.0, 0.42, 4, shade(SANDSTONE, 0.92), rot=math.pi / 4)
    # Small Sphinx silhouette on the east side.
    m.box((0.88, 0.07, 0.46), (0.28, 0.14, 0.10), shade(SANDSTONE, 0.88))
    m.box((1.00, 0.14, 0.46), (0.08, 0.12, 0.08), shade(SANDSTONE, 0.92))
    return m


def dome_of_the_rock():
    """Dome of the Rock (Jerusalem, 1453).
    Real proportions: octagonal base (~46 m wide, 11 m high) on the Haram platform,
    cylindrical drum, gilded golden dome (20 m wide, ~35 m total height).
    In 1453: marble & mosaic walls (Suleiman's blue Iznik tiles were added 1545)."""
    m = Mesh()
    # Raised Haram al-Sharif stone terrace.
    m.box((0, 0.08, 0), (2.30, 0.16, 2.30), shade(STONE, 0.92), top_col=WHITE_STONE)
    # Octagonal sanctuary walls (marble lower, warm ochre/mosaic upper, lead roof).
    m.frustum((0, 0.16, 0), 0.96, 0.96, 0.28, 8, WHITE_STONE, cap_top=False, rot=math.pi / 8)
    m.frustum((0, 0.44, 0), 0.96, 0.96, 0.24, 8, SANDSTONE, top_col=LEAD, rot=math.pi / 8)
    # Four cardinal porches.
    for dx, dz in ((0.96, 0), (-0.96, 0), (0, 0.96), (0, -0.96)):
        m.box((dx, 0.36, dz), (0.24, 0.40, 0.24), WHITE_STONE, top_col=LEAD)
    # Cylindrical drum with window band.
    m.frustum((0, 0.68, 0), 0.48, 0.48, 0.34, 16, WHITE_STONE, cap_top=False)
    for i in range(12):
        a = 2 * math.pi * i / 12
        m.box((0.49 * math.sin(a), 0.84, 0.49 * math.cos(a)), (0.05, 0.10, 0.01), DARK, rot_y=a)
    # Iconic golden dome + finial.
    m.dome((0, 1.02, 0), 0.48, GOLD, segs=16, rings=5, squash=1.08)
    m.frustum((0, 1.54, 0), 0.025, 0.0, 0.18, 6, GOLD)
    return m


def lalibela():
    """Bete Giyorgis — Church of Saint George (Lalibela, Ethiopia, 1453).
    Monolithic Greek-cross church (12 m x 12 m x 12 m, carved ~1200 CE) in red
    volcanic tuff, standing inside its sunken rock-cut courtyard."""
    m = Mesh()
    # Outer rock-cut rim framing the sunken courtyard.
    rim = shade(RED_SANDSTONE, 0.85)
    m.box((0, 0.10, -0.95), (2.10, 0.20, 0.22), rim)
    m.box((0, 0.10, 0.95), (2.10, 0.20, 0.22), rim)
    m.box((-0.95, 0.10, 0), (0.22, 0.20, 1.68), rim)
    m.box((0.95, 0.10, 0), (0.22, 0.20, 1.68), rim)
    # Three-stepped plinth of the church.
    m.box((0, 0.10, 0), (1.36, 0.20, 0.62), shade(RED_SANDSTONE, 0.92))
    m.box((0, 0.10, 0), (0.62, 0.20, 1.36), shade(RED_SANDSTONE, 0.92))
    # Greek-cross monolithic church body.
    m.box((0, 0.66, 0), (1.16, 0.96, 0.48), RED_SANDSTONE, top_col=shade(RED_SANDSTONE, 1.08))
    m.box((0, 0.66, 0), (0.48, 0.96, 1.16), RED_SANDSTONE, top_col=shade(RED_SANDSTONE, 1.08))
    # Carved nested cross relief on the flat roof.
    m.box((0, 1.16, 0), (0.96, 0.05, 0.30), shade(RED_SANDSTONE, 1.12))
    m.box((0, 1.16, 0), (0.30, 0.05, 0.96), shade(RED_SANDSTONE, 1.12))
    m.box((0, 1.20, 0), (0.68, 0.04, 0.16), WHITE_STONE)
    m.box((0, 1.20, 0), (0.16, 0.04, 0.68), WHITE_STONE)
    # Cross-shaped dark window openings on the four arms.
    for dx, dz in ((0.59, 0), (-0.59, 0), (0, 0.59), (0, -0.59)):
        w, d = (0.02, 0.12) if dx else (0.12, 0.02)
        m.box((dx, 0.80, dz), (w, 0.18, d), DARK)
    return m


def gur_e_amir():
    """Gur-e Amir (Samarkand, 1453).
    Timur's mausoleum (completed 1404; Ulugh Beg buried here 1449).
    Octagonal brick base, tall cylindrical drum, iconic ribbed turquoise-blue
    bulbous dome (32 m high), front pishtaq portal and flanking tiled minarets."""
    m = Mesh()
    # Octagonal brick mausoleum base.
    m.frustum((0, 0, 0), 0.74, 0.74, 0.64, 8, SANDSTONE, top_col=shade(SANDSTONE, 0.88), rot=math.pi / 8)
    # Front pishtaq (monumental entrance portal on +z).
    m.box((0, 0.50, 0.72), (0.76, 1.00, 0.24), TURQUOISE, top_col=SANDSTONE)
    m.box((0, 0.36, 0.85), (0.38, 0.64, 0.04), DARK)
    # Tall cylindrical drum with turquoise & gold band.
    m.frustum((0, 0.64, 0), 0.44, 0.44, 0.48, 16, TURQUOISE, cap_top=False)
    m.frustum((0, 0.98, 0), 0.45, 0.45, 0.09, 16, GOLD, cap_top=False)
    # Iconic bulbous turquoise dome + golden finial.
    m.dome((0, 1.10, 0), 0.46, TURQUOISE, segs=16, rings=6, squash=1.22, onion=0.14)
    m.frustum((0, 1.66, 0), 0.025, 0.0, 0.20, 6, GOLD)
    # Two flanking Timurid minarets.
    for sx in (-1, 1):
        mx, mz = sx * 0.84, 0.58
        m.frustum((mx, 0, mz), 0.10, 0.08, 1.32, 10, SANDSTONE, top_col=TURQUOISE)
        m.frustum((mx, 1.05, mz), 0.11, 0.11, 0.08, 10, TURQUOISE, cap_top=False)
        m.dome((mx, 1.32, mz), 0.08, TURQUOISE, segs=8, rings=3, squash=1.1)
    return m


def qutb_minar():
    """Qutb Minar & Quwwat-ul-Islam Mosque screen (Delhi, 1453).
    Real proportions: 72.5 m tall tapering victory tower (14.3 m base to 2.7 m top),
    5 storeys with projecting balconies (lower 3 red sandstone, upper 2 white marble
    from Firuz Shah Tughlaq's 1369 repair), beside the red sandstone mosque arch screen."""
    m = Mesh()
    # Mosque courtyard plinth & ruined arched screen (gives grounded footprint).
    m.box((-0.38, 0.06, 0), (1.30, 0.12, 1.10), shade(STONE, 0.90), top_col=SANDSTONE)
    m.box((-0.62, 0.44, -0.18), (0.84, 0.68, 0.18), RED_SANDSTONE, top_col=shade(RED_SANDSTONE, 0.85))
    for dx in (-0.84, -0.62, -0.40):
        m.box((dx, 0.34, -0.08), (0.14, 0.46, 0.02), DARK)
    # Qutb Minar: 5 tapering storeys with projecting balconies.
    tx, tz = 0.46, 0.12
    storeys = [
        (0.00, 0.62, 0.30, 0.25, RED_SANDSTONE),
        (0.62, 0.46, 0.25, 0.21, RED_SANDSTONE),
        (1.08, 0.38, 0.21, 0.17, RED_SANDSTONE),
        (1.46, 0.30, 0.17, 0.13, WHITE_STONE),
        (1.76, 0.26, 0.13, 0.10, WHITE_STONE),
    ]
    for y0, h, r0, r1, col in storeys:
        m.frustum((tx, y0, tz), r0, r1, h, 14, col, top_col=WHITE_STONE)
        m.frustum((tx, y0 + h - 0.04, tz), r1 + 0.05, r1 + 0.05, 0.05, 14, shade(col, 0.82))
    return m


def virupaksha_temple():
    """Virupaksha Temple (Vijayanagara / Hampi, 1453).
    Dravidian temple complex: tall 9-tier pyramidal gopuram gateway (~50 m) with
    barrel-vaulted sala roof and golden kalasha finials, behind it a pillared
    mandapa hall and inner sanctum shikhara within a walled courtyard."""
    m = Mesh()
    # Courtyard enclosure wall.
    m.box((0.0, 0.14, 0), (2.10, 0.28, 1.40), shade(SANDSTONE, 0.88), top_col=SANDSTONE)
    # Main east gopuram (stepped rectangular pyramid).
    gx = 0.72
    w, d, y = 0.78, 0.56, 0.28
    for tier in range(7):
        col = SANDSTONE if tier % 2 == 0 else shade(SANDSTONE, 0.92)
        h = 0.18
        m.box((gx, y + h / 2, 0), (w, h, d), col, top_col=shade(col, 0.85))
        w *= 0.84
        d *= 0.84
        y += h
    # Barrel-vaulted sala cap & golden kalasha finials on top of gopuram.
    m.box((gx, y + 0.08, 0), (w * 1.05, 0.16, d * 0.90), WHITE_STONE)
    for dz in (-0.08, 0.0, 0.08):
        m.frustum((gx, y + 0.16, dz), 0.025, 0.0, 0.10, 6, GOLD)
    # Gateway portal opening.
    m.box((gx + 0.40, 0.34, 0), (0.02, 0.38, 0.20), DARK)
    # Inner pillared mandapa hall & sanctum shikhara tower.
    m.box((-0.18, 0.38, 0), (0.76, 0.26, 0.62), SANDSTONE, top_col=shade(SANDSTONE, 0.92))
    sx = -0.68
    sw, sy = 0.44, 0.28
    for tier in range(4):
        m.box((sx, sy + 0.09, 0), (sw, 0.18, sw), SANDSTONE)
        sw *= 0.76
        sy += 0.18
    m.dome((sx, sy, 0), 0.12, GOLD, segs=8, rings=3)
    return m


def gyantse_kumbum():
    """Gyantse Kumbum (Gyantse, Tibet, 1453).
    Completed 1427: largest stupa/chorten in Tibet (~35 m high, 50 m base).
    Four receding whitewashed stepped terraces with crimson frieze bands,
    white bumpa dome, golden harmika and 13-ringed golden conical spire."""
    m = Mesh()
    # Four receding stepped terraces (mandala plan).
    y = 0.0
    for w, h in ((1.80, 0.22), (1.44, 0.20), (1.10, 0.18), (0.78, 0.16)):
        m.box((0, y + h / 2, 0), (w, h, w), WHITE_STONE, top_col=shade(WHITE_STONE, 0.94))
        m.box((0, y + h - 0.03, 0), (w + 0.02, 0.04, w + 0.02), CRIMSON)
        y += h
    # White bumpa (cylindrical-bell dome).
    m.frustum((0, y, 0), 0.34, 0.30, 0.34, 14, WHITE_STONE, top_col=WHITE_STONE)
    y += 0.34
    # Golden square harmika.
    m.box((0, y + 0.09, 0), (0.26, 0.18, 0.26), GOLD, top_col=GOLD)
    y += 0.18
    # Golden 13-ringed conical spire & parasol finial.
    m.frustum((0, y, 0), 0.13, 0.02, 0.44, 10, GOLD)
    m.frustum((0, y + 0.44, 0), 0.09, 0.0, 0.08, 10, GOLD)
    return m


def forbidden_city():
    """Hall of Supreme Harmony — Forbidden City (Beijing, 1453).
    Completed 1420 under the Yongle Emperor: 3-tiered white marble terrace,
    vermilion-red hall (64 m x 37 m x 35 m), sweeping double-eaved imperial
    yellow glazed hip-and-gable roof."""
    m = Mesh()
    # Three-tiered white marble terrace.
    m.box((0, 0.07, 0), (2.20, 0.14, 1.48), WHITE_STONE, top_col=shade(WHITE_STONE, 0.95))
    m.box((0, 0.20, 0), (1.96, 0.12, 1.26), WHITE_STONE, top_col=shade(WHITE_STONE, 0.95))
    m.box((0, 0.32, 0), (1.72, 0.12, 1.04), WHITE_STONE, top_col=shade(WHITE_STONE, 0.95))
    # Central marble staircases (+z front).
    m.box((0, 0.18, 0.68), (0.36, 0.32, 0.22), shade(WHITE_STONE, 0.92))
    # Vermilion-red hall (lower & upper storeys).
    m.box((0, 0.54, 0), (1.42, 0.34, 0.76), CRIMSON)
    m.hip_roof((0, 0.70, 0), 1.44, 0.78, 0.22, IMPERIAL_GOLD, overhang=0.06, flare=0.10)
    m.box((0, 0.88, 0), (1.16, 0.20, 0.56), CRIMSON)
    m.hip_roof((0, 0.98, 0), 1.18, 0.58, 0.34, IMPERIAL_GOLD, overhang=0.06, flare=0.12)
    return m


def kinkaku_ji():
    """Kinkaku-ji — the Golden Pavilion (Kyoto, 1453).
    Built 1397 by Ashikaga Yoshimitsu: three-storey pavilion over its reflecting
    pond (Kyoko-chi): white plaster & timber ground floor, gleaming gold-leaf
    second and third storeys, dark shingle flared roofs, golden phoenix finial."""
    m = Mesh()
    # Reflecting pond base (Kyoko-chi).
    m.box((0, 0.04, 0), (2.00, 0.08, 1.60), POND_BLUE, top_col=POND_BLUE)
    # Stone island footing.
    m.box((0, 0.12, 0), (1.16, 0.10, 0.92), STONE)
    # Ground floor (shinden style: white plaster & dark wood).
    m.box((0, 0.34, 0), (1.02, 0.34, 0.78), WHITE_STONE)
    m.hip_roof((0, 0.50, 0), 1.04, 0.80, 0.16, DARK_SLATE, overhang=0.06, flare=0.10)
    # Second floor (gold leaf).
    m.box((0, 0.72, 0), (0.86, 0.30, 0.64), GOLD)
    m.hip_roof((0, 0.86, 0), 0.88, 0.66, 0.16, DARK_SLATE, overhang=0.06, flare=0.10)
    # Third floor (Zen style, gold leaf) + pyramidal shingle roof + golden phoenix.
    m.box((0, 1.08, 0), (0.58, 0.26, 0.58), GOLD)
    m.hip_roof((0, 1.20, 0), 0.60, 0.60, 0.32, DARK_SLATE, overhang=0.06, flare=0.12)
    m.frustum((0, 1.52, 0), 0.04, 0.0, 0.14, 6, GOLD)
    return m


def gyeongbokgung():
    """Geunjeongjeon — Gyeongbokgung Palace (Hanyang / Seoul, 1453).
    Built 1395, main Joseon throne hall: two-tiered granite woldae terrace,
    vermilion-red & celadon-trimmed two-storey hall, sweeping double-eaved
    dark blue-grey Korean tile roof."""
    m = Mesh()
    # Two-tiered grey granite terrace (woldae).
    m.box((0, 0.09, 0), (2.06, 0.18, 1.56), STONE, top_col=shade(STONE, 0.94))
    m.box((0, 0.24, 0), (1.76, 0.14, 1.28), STONE, top_col=shade(STONE, 0.94))
    m.box((0, 0.16, 0.74), (0.32, 0.28, 0.20), shade(STONE, 0.90))
    # Lower storey: crimson walls with celadon dancheong eaves band.
    m.box((0, 0.48, 0), (1.30, 0.34, 0.88), CRIMSON)
    m.box((0, 0.64, 0), (1.34, 0.06, 0.92), CELADON)
    m.hip_roof((0, 0.66, 0), 1.34, 0.92, 0.22, DARK_SLATE, overhang=0.06, flare=0.10)
    # Upper storey & grand Korean hip-and-gable roof.
    m.box((0, 0.86, 0), (1.00, 0.22, 0.64), CRIMSON)
    m.box((0, 0.96, 0), (1.04, 0.05, 0.68), CELADON)
    m.hip_roof((0, 0.98, 0), 1.04, 0.68, 0.36, DARK_SLATE, overhang=0.06, flare=0.12)
    return m
