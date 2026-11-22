"""Nástroje Dune Diggers – hladké modely (viz sdf.py).

Konvence (stejná jako ToolFactory.luau): ruka drží nástroj v bodě (0,0,0),
nástroj míří dopředu po -Z, nahoru je +Y.
"""

import numpy as np

from sdf import (
    Asset,
    Shape,
    capsule,
    cylinder,
    ellipsoid,
    flat_cone,
    rot,
    round_box,
    round_cone,
    smax,
    sphere,
    torus,
)

STEEL = (178, 186, 198)
STEEL_DARK = (92, 98, 110)
CHROME = (222, 226, 234)
RUBBER = (40, 40, 46)
WOOD = (176, 118, 70)
GOLD = (255, 200, 60)
SAND = (236, 194, 124)
CYAN = (80, 232, 255)

ZAX = rot(90, 0, 0)  # válec (osa Y) otočený do osy Z
XAX = rot(0, 0, 90)  # válec otočený do osy X


def ring(c, radius, thick, axis=ZAX):
    return torus(c, radius, thick, axis)


def _and(f, g, k=0.0):
    return lambda P: smax(f(P), g(P), k)


def spoon(cell):
    a = Asset("Spoon", cell)
    s = Shape(round_cone((0, 0, 0.95), (0, 0, -1.15), 0.17, 0.075))
    s.inter(lambda P: np.abs(P[:, 1]) - 0.06, 0.03)
    s.add(ellipsoid((0, 0, 1.05), (0.26, 0.07, 0.3)), 0.08)
    s.add(capsule((0, 0, -1.1), (0, -0.07, -1.45), 0.07), 0.06)
    s.add(ellipsoid((0, -0.12, -2.0), (0.48, 0.17, 0.62)), 0.12)
    s.sub(ellipsoid((0, -0.01, -2.0), (0.42, 0.14, 0.56)), 0.03)
    p = a.piece("Spoon", s, CHROME, "M", res=0.012)
    for x, z, r in ((0.05, 0.55, 0.11), (-0.04, -0.2, 0.09), (0.0, 0.95, 0.13)):
        p.paint("Rust", sphere((x, 0.06, z), r), (176, 98, 52), "S")
    sand = Shape(ellipsoid((0, -0.04, -2.0), (0.37, 0.12, 0.48)))
    sand.add(sphere((0.12, 0.03, -2.05), 0.13), 0.08)
    a.piece("Sand", sand, SAND, res=0.015)
    return a


def trowel(cell):
    a = Asset("Trowel", cell)
    red, red_dark = (214, 64, 52), (150, 34, 28)
    h = Shape(round_cone((0, 0, 0.95), (0, 0, -0.3), 0.21, 0.17))
    h.add(sphere((0, 0, 1.0), 0.23), 0.08)
    for z in (0.62, 0.32, 0.02):
        h.sub(ring((0, 0, z), 0.215, 0.035), 0.02)
    hp = a.piece("Handle", h, red, res=0.015)
    hp.paint("Cap", sphere((0, 0, 1.08), 0.2), red_dark)
    fer = Shape(cylinder((0, 0, -0.42), 0.16, 0.18, 0.04, ZAX))
    a.piece("Ferrule", fer, (214, 172, 84), "M", res=0.012)
    neck = Shape(capsule((0, 0, -0.55), (0, -0.32, -0.88), 0.065))
    neck.add(capsule((0, -0.32, -0.88), (0, -0.3, -1.15), 0.06), 0.04)
    blade = Shape(flat_cone((0, -0.3, -1.08), (0, -0.3, -2.4), 0.5, 0.07, 0.11, (0, 1, 0)))
    blade.add(capsule((0, -0.25, -1.1), (0, -0.27, -2.1), 0.04), 0.04)
    neck.add(blade, 0.05)
    a.piece("Blade", neck, STEEL, "M", res=0.012)
    return a


def _shovel(a, golden):
    metal = GOLD if golden else STEEL
    shaft_c = (92, 56, 30) if golden else WOOD
    grip_c = GOLD if golden else RUBBER
    sh = Shape(capsule((0, 0, 1.3), (0, 0, -2.7), 0.14))
    a.piece("Shaft", sh, shaft_c, "W", res=0.02)
    g = Shape(capsule((-0.4, 0, 1.92), (0.4, 0, 1.92), 0.12))
    for side in (-1, 1):
        g.add(capsule((side * 0.4, 0, 1.92), (side * 0.12, 0, 1.3), 0.085), 0.06)
    g.add(cylinder((0, 0, 1.22), 0.16, 0.17, 0.04, ZAX), 0.05)
    gp = a.piece("Grip", g, grip_c, "M" if golden else "S", res=0.015, density=1200)
    if not golden:
        gp.paint("GripBar", capsule((-0.3, 0, 1.92), (0.3, 0, 1.92), 0.16), (226, 90, 44))
    wrap = Shape()
    for z in (0.62, 0.0):
        wrap.add(cylinder((0, 0, z), 0.16, 0.165, 0.03, ZAX))
    a.piece("Wrap", wrap, GOLD if golden else RUBBER, "M" if golden else "S", res=0.012, density=3000)
    col = Shape(round_cone((0, 0, -2.55), (0, 0, -3.12), 0.17, 0.21))
    for x in (-0.2, 0.2):
        col.add(sphere((x * 0.9, 0.0, -2.85), 0.05), 0.0)
    cp = a.piece("Collar", col, GOLD if golden else STEEL_DARK, "M", res=0.012)
    cp.paint("Rivets", sphere((0.18, 0, -2.85), 0.07), CHROME)
    cp.paint("Rivets", sphere((-0.18, 0, -2.85), 0.07), CHROME)
    # list lopaty: zaoblený obdélník + špička, prohnutý (miska), s nášlapem
    blade = Shape(round_box((0, 0, -3.72), (0.66, 0.045, 0.5), 0.04))
    blade.add(round_cone((0, 0, -4.05), (0, 0, -4.68), 0.62, 0.06), 0.05)
    blade.inter(lambda P: np.abs(P[:, 1]) - 0.045, 0.0)
    blade = _bend(blade, 0.22)
    blade.add(capsule((-0.66, 0.06, -3.2), (0.66, 0.06, -3.2), 0.075), 0.04)
    blade.add(capsule((0, 0.05, -3.15), (0, 0.04, -4.3), 0.05), 0.08)
    a.piece("Blade", blade, metal, "M", res=0.012)
    return a


def _bend(shape, amount):
    """Prohne list do misky (střed níž než okraje)."""
    def f(P):
        Q = P.copy()
        Q[:, 1] = Q[:, 1] - amount * (Q[:, 0] ** 2)
        return shape(Q)

    return Shape(f)


def shovel(cell):
    a = Asset("Shovel", cell)
    _shovel(a, False)
    dirt = Shape(ellipsoid((0.15, 0.08, -4.0), (0.42, 0.12, 0.35)))
    dirt.add(sphere((0.3, 0.12, -3.85), 0.14), 0.08)
    a.piece("Dirt", dirt, SAND, res=0.015)
    return a


def golden_shovel(cell):
    a = Asset("GoldenShovel", cell)
    _shovel(a, True)
    gem = Shape(round_box((0, 0.1, -3.65), (0.17, 0.08, 0.17), 0.04, rot(0, 45, 0)))
    a.piece("Gem", gem, CYAN, "N", res=0.01)
    wings = Shape()
    for side in (-1, 1):
        wings.add(flat_cone((side * 0.18, 0.02, -2.85), (side * 0.75, 0.02, -2.55), 0.16, 0.04, 0.25, (0, 1, 0)), 0.03)
        wings.add(flat_cone((side * 0.18, 0.02, -2.95), (side * 0.65, 0.02, -2.8), 0.12, 0.03, 0.25, (0, 1, 0)), 0.03)
    a.piece("Wings", wings, GOLD, "M", res=0.012)
    return a


def vacuum(cell):
    a = Asset("Vacuum", cell)
    orange, glass = (245, 104, 46), (200, 236, 255)
    body = Shape(round_cone((0, 0.62, 1.15), (0, 0.62, -0.45), 0.55, 0.5))
    body.add(round_box((0, 0.28, 0.35), (0.3, 0.12, 0.6), 0.1), 0.15)
    bp = a.piece("Body", body, orange, res=0.02)
    bp.paint("Stripe", round_box((0, 0.62, 0.35), (2, 0.08, 2), 0, rot(0, 0, 0)), (255, 236, 220))
    for z in (0.95, -0.2):
        a.piece("Band%d" % int(z * 10 + 5), Shape(ring((0, 0.62, z), 0.53, 0.05)), CHROME, "M", res=0.012)
    tank = Shape(cylinder((0, 1.28, 0.35), 0.42, 0.33, 0.08, ZAX))
    a.piece("Tank", tank, glass, "G", res=0.015)
    a.piece("TankSand", Shape(cylinder((0, 1.2, 0.35), 0.38, 0.24, 0.06, ZAX)), SAND, res=0.015)
    caps = Shape(cylinder((0, 1.28, -0.1), 0.05, 0.36, 0.02, ZAX)).add(cylinder((0, 1.28, 0.8), 0.05, 0.36, 0.02, ZAX))
    a.piece("TankCaps", caps, RUBBER, res=0.012)
    handle = Shape(capsule((0, 0, 0.45), (0, 0, -0.22), 0.1))
    handle.add(capsule((0, 0, 0.45), (0, 0.3, 0.6), 0.08), 0.06)
    handle.add(capsule((0, 0, -0.22), (0, 0.3, -0.32), 0.08), 0.06)
    a.piece("Handle", handle, RUBBER, res=0.015)
    lights = Shape(sphere((0.52, 0.72, 0.6), 0.07)).add(sphere((0.5, 0.72, 0.38), 0.07))
    a.piece("LightGreen", Shape(sphere((0.52, 0.75, 0.62), 0.075)), (90, 255, 130), "N", res=0.01)
    a.piece("LightYellow", Shape(sphere((0.51, 0.75, 0.4), 0.075)), (255, 210, 70), "N", res=0.01)
    del lights
    # hadice podél Bézierovy křivky + žebrování
    p0, p1, p2 = np.array([0, 0.5, -0.85]), np.array([0, 0.3, -2.2]), np.array([0, -0.5, -3.0])
    pts = [p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t for t in np.linspace(0, 1, 9)]
    hose = Shape()
    for q0, q1 in zip(pts[:-1], pts[1:]):
        hose.add(capsule(q0, q1, 0.17), 0.04)
    hp = a.piece("Hose", hose, (74, 76, 84), res=0.016)
    for t in np.linspace(0.06, 0.94, 12):
        c = p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t
        hp.paint("Rib", sphere(c, 0.205), (52, 54, 60))
    noz = Shape(round_box((0, -0.62, -3.3), (0.7, 0.17, 0.32), 0.1))
    noz.add(round_box((0, -0.42, -3.2), (0.45, 0.12, 0.22), 0.08), 0.08)
    a.piece("Nozzle", noz, (58, 60, 68), res=0.016)
    a.piece("NozzleGlow", Shape(round_box((0, -0.7, -3.62), (0.6, 0.035, 0.03), 0.02)), CYAN, "N", res=0.01)
    return a


def blaster(cell):
    a = Asset("Blaster", cell)
    yellow, dark = (255, 194, 38), (62, 64, 74)
    body = Shape(ellipsoid((0, 0.35, 0.25), (0.72, 0.66, 1.02)))
    body.add(round_cone((0, 0.32, -0.5), (0, 0.3, -1.05), 0.5, 0.44), 0.2)
    bp = a.piece("Body", body, yellow, res=0.02)
    for side in (-1, 1):
        bp.paint("Stripe", round_box((side * 0.7, 0.35, 0.25), (0.15, 0.09, 0.9), 0.04), RUBBER)
    bp.paint("Top", round_box((0, 0.98, 0.2), (0.25, 0.1, 0.6), 0.05), (255, 120, 40))
    fan = Shape(cylinder((0, 0.35, 1.25), 0.22, 0.8, 0.06, ZAX))
    fan.sub(cylinder((0, 0.35, 1.45), 0.2, 0.68, 0.04, ZAX), 0.02)
    a.piece("FanHousing", fan, dark, res=0.016)
    blades = Shape(sphere((0, 0.35, 1.3), 0.17))
    for k in range(6):
        blades.add(round_box((0, 0.35, 1.32), (0.07, 0.6, 0.02), 0.02, rot(0, 0, k * 30) @ rot(0, 20, 0)), 0.02)
    a.piece("Fan", blades, CHROME, "M", res=0.012)
    barrel = Shape(cylinder((0, 0.3, -1.25), 0.4, 0.4, 0.05, ZAX))
    barrel.add(cylinder((0, 0.3, -1.95), 0.35, 0.32, 0.04, ZAX), 0.05)
    a.piece("Barrel", barrel, (120, 126, 138), "M", res=0.016)
    muz = Shape(cylinder((0, 0.3, -2.4), 0.16, 0.48, 0.06, ZAX))
    muz.sub(cylinder((0, 0.3, -2.5), 0.2, 0.34, 0.03, ZAX), 0.02)
    a.piece("Muzzle", muz, yellow, res=0.014)
    a.piece("MuzzleCore", Shape(cylinder((0, 0.3, -2.33), 0.03, 0.33, 0.01, ZAX)), (255, 140, 40), "N", res=0.01)
    grip = Shape(round_box((0, -0.45, 0.42), (0.16, 0.45, 0.22), 0.12, rot(-15, 0, 0)))
    grip.add(arc_guard(), 0.03)
    a.piece("Grip", grip, RUBBER, res=0.015)
    a.piece("Trigger", Shape(capsule((0, -0.18, 0.02), (0, -0.38, 0.06), 0.06)), (230, 60, 50), res=0.01)
    return a


def arc_guard():
    from sdf import arc

    return arc((0, -0.2, 0.0), 0.25, 0.04, 80, rot(0, 90, 0), down=True)


def excavator(cell):
    a = Asset("Excavator", cell)
    yellow, dark = (255, 196, 32), (62, 64, 72)
    g = Shape(capsule((0, 0, 1.25), (0, 0, 0.25), 0.24))
    g.add(sphere((0, 0, 1.35), 0.27), 0.06)
    a.piece("Grip", g, RUBBER, res=0.02)
    arm = Shape(round_box((0, 0, -1.85), (0.37, 0.37, 2.0), 0.12))
    arm.add(round_box((0, 0.05, -3.85), (0.42, 0.42, 0.25), 0.1), 0.05)
    ap = a.piece("Arm", arm, yellow, res=0.02, density=420)
    for i in range(4):
        ap.paint("Hazard", round_box((0, 0, -0.35 - i * 0.42), (1, 1, 0.1), 0, rot(30, 0, 0)), RUBBER)
    pis = Shape(cylinder((0, 0.6, -1.45), 0.75, 0.17, 0.04, ZAX))
    pis.add(round_box((0, 0.5, -0.65), (0.14, 0.18, 0.14), 0.05), 0.04)
    pis.add(round_box((0, 0.5, -3.35), (0.14, 0.18, 0.14), 0.05), 0.04)
    a.piece("Piston", pis, dark, "M", res=0.015)
    a.piece("PistonRod", Shape(cylinder((0, 0.6, -2.7), 0.62, 0.09, 0.02, ZAX)), CHROME, "M", res=0.012)
    joint = Shape(cylinder((0, 0, -4.1), 0.62, 0.42, 0.06, XAX))
    a.piece("Joint", joint, dark, "M", res=0.02, density=300)
    a.piece("JointPin", Shape(cylinder((0, 0, -4.1), 0.72, 0.15, 0.03, XAX)), CHROME, "M", res=0.012)
    outer = round_box((0, -0.85, -5.2), (1.45, 0.82, 0.95), 0.28)
    inner = round_box((0, -0.62, -5.28), (1.28, 0.82, 0.8), 0.2)
    bucket = Shape(outer).sub(inner, 0.04)
    bucket.add(round_box((0, -0.3, -4.35), (0.6, 0.5, 0.25), 0.1), 0.1)
    bkt = a.piece("Bucket", bucket, yellow, res=0.03, density=300)
    bkt.paint("Lip", round_box((0, -1.6, -6.1), (2, 0.2, 0.2), 0.0), dark, "M")
    teeth = Shape()
    for i in range(-2, 3):
        x = i * 0.56
        teeth.add(round_cone((x, -1.55, -6.0), (x, -1.72, -6.45), 0.15, 0.04))
    a.piece("Teeth", teeth, (90, 94, 104), "M", res=0.012)
    load = Shape(ellipsoid((0, -0.25, -5.25), (1.2, 0.4, 0.75)))
    load.add(sphere((0.4, -0.05, -5.1), 0.35), 0.2)
    load.add(sphere((-0.5, -0.1, -5.4), 0.3), 0.2)
    a.piece("Load", load, SAND, res=0.03, density=300)
    return a


TOOLS = [spoon, trowel, shovel, golden_shovel, vacuum, blaster, excavator]
