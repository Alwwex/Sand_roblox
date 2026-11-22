"""Mazlíčci a vajíčka Dune Diggers – hladké modely (viz sdf.py).

Konvence: mazlíček stojí na zemi y=0, kouká dopředu po -Z, výška cca 2.5–3 studů.
"""

import numpy as np

from sdf import (
    Asset,
    Shape,
    arc,
    basis_z,
    capsule,
    cylinder,
    ellipsoid,
    flat_cone,
    rot,
    round_box,
    round_cone,
    scaled,
    smax,
    sphere,
    surface_point,
    torus,
    triangle,
)

DARK = (38, 26, 24)
WHITE = (255, 255, 255)
BLUSH = (255, 140, 160)
NOSE = (240, 120, 140)


# ---------------------------------------------------------------- společné prvky obličeje


def eyes(a, body, x, y, size=(0.16, 0.2, 0.11), color=DARK, origin_z=0.0, origin_y=None, name="Eyes", glow=None):
    """Lesklé oči "přilepené" na povrch hlavy + bílé odlesky."""
    eye_fs, shine_fs = [], []
    for side in (-1, 1):
        oy = y if origin_y is None else origin_y
        p, n = surface_point(body, (side * x * 0.6, oy, origin_z), (side * x * 0.4, y - oy, -1.0))
        R = basis_z(n)
        c = p - n * size[2] * 0.35
        eye_fs.append(ellipsoid(c, size, R))
        hx = R[:, 0] * size[0] * 0.38 + R[:, 1] * size[1] * 0.42 + n * size[2] * 0.62
        shine_fs.append(sphere(c + hx, size[0] * 0.34))
        lx = -R[:, 0] * size[0] * 0.35 - R[:, 1] * size[1] * 0.38 + n * size[2] * 0.6
        shine_fs.append(sphere(c + lx, size[0] * 0.16))
    s = Shape()
    for f in eye_fs:
        s.add(f)
    a.piece(name, s, glow or color, "N" if glow else "S", res=0.012, density=900)
    sh = Shape()
    for f in shine_fs:
        sh.add(f)
    a.piece(name + "Shine", sh, WHITE, "N", res=0.01, density=900)
    return eye_fs


def blush(piece, body, x, y, size=(0.17, 0.1, 0.25), color=BLUSH, oz=0.0):
    for side in (-1, 1):
        p, n = surface_point(body, (side * x * 0.5, y, oz), (side * x * 0.5, 0, -1.0))
        piece.paint("Blush", ellipsoid(p, size, basis_z(n)), color)


def smile(piece, body, y, width=0.07, double=True, color=DARK, thick=0.022, angle=70, oz=0.0):
    """Pusinka "w" (double) nebo jednoduchý úsměv namalovaný na povrch."""
    centers = [-width, width] if double else [0.0]
    for cx in centers:
        p, n = surface_point(body, (cx, y, oz), (0, 0, -1.0))
        R = basis_z(n)
        local = arc((0, 0, 0), width, thick, angle, down=True)
        piece.paint("Mouth", scaled(local, p + R[:, 1] * width * 0.5, R, (1, 1, 5)), color)


def chibi_body(head_c=(0, 1.15, 0), head_r=(0.98, 0.9, 0.9), low_c=(0, 0.62, 0.1), low_r=(0.9, 0.6, 0.86), k=0.35):
    return Shape(ellipsoid(head_c, head_r)).add(ellipsoid(low_c, low_r), k)


def feet(s, color_piece, x=0.42, z=-0.42, r=(0.27, 0.16, 0.34), k=0.12, paint=None):
    for side in (-1, 1):
        s.add(ellipsoid((side * x, 0.15, z), r), k)
        if paint is not None:
            color_piece.paint("Feet", ellipsoid((side * x, 0.1, z - 0.06), (r[0] + 0.03, 0.16, r[2] + 0.02)), paint)


# ---------------------------------------------------------------- mazlíčci


def sand_bunny(cell):
    a = Asset("SandBunny", cell)
    fur, cream, pink = (242, 218, 178), (255, 248, 234), (255, 160, 178)
    s = chibi_body()
    for side in (-1, 1):
        tip_x = 0.6 if side > 0 else 0.5
        s.add(flat_cone((side * 0.32, 1.75, 0.1), (side * tip_x, 2.95, 0.3), 0.25, 0.2, 0.55, (0, 0, -1)), 0.18)
        s.add(ellipsoid((side * 0.58, 0.78, -0.62), (0.17, 0.2, 0.17)), 0.1)
    s.add(ellipsoid((0, 0.98, -0.8), (0.36, 0.26, 0.22)), 0.18)
    s.add(ellipsoid((0, 1.09, -1.0), (0.09, 0.07, 0.06)), 0.04)
    s.add(sphere((0, 0.6, 0.9), 0.3), 0.08)
    body = a.piece("Body", s, fur)
    feet(s, body, paint=cream)
    body.paint("Belly", ellipsoid((0, 0.62, -0.6), (0.6, 0.5, 0.6)), cream)
    body.paint("Muzzle", ellipsoid((0, 0.96, -0.92), (0.42, 0.3, 0.3)), cream)
    body.paint("Tail", sphere((0, 0.6, 0.92), 0.33), WHITE)
    for side in (-1, 1):
        tip_x = 0.6 if side > 0 else 0.5
        body.paint(
            "EarIn",
            flat_cone((side * 0.33, 1.85, -0.05), (side * (tip_x - 0.02), 2.85, 0.15), 0.15, 0.1, 1.2, (0, 0, -1)),
            pink,
        )
    body.paint("Nose", sphere((0, 1.1, -1.05), 0.09), NOSE)
    blush(body, s, 0.62, 1.0)
    smile(body, s, 0.93)
    eyes(a, s, 0.38, 1.3)
    return a


def desert_mouse(cell):
    a = Asset("DesertMouse", cell)
    fur, belly, pink = (190, 160, 132), (245, 228, 206), (250, 168, 176)
    s = chibi_body(head_r=(0.95, 0.85, 0.92), low_r=(0.88, 0.58, 0.9))
    s.add(round_cone((0, 1.05, -0.3), (0, 0.95, -1.12), 0.55, 0.16), 0.3)
    for side in (-1, 1):
        s.add(ellipsoid((side * 0.68, 1.85, 0.08), (0.46, 0.46, 0.12), rot(0, side * 18, side * 18)), 0.14)
        s.add(ellipsoid((side * 0.55, 0.72, -0.62), (0.15, 0.18, 0.15)), 0.1)
    body = a.piece("Body", s, fur)
    feet(s, body, x=0.4, r=(0.24, 0.14, 0.32), paint=pink)
    body.paint("Belly", ellipsoid((0, 0.6, -0.62), (0.58, 0.5, 0.6)), belly)
    body.paint("Muzzle", ellipsoid((0, 0.88, -0.9), (0.4, 0.28, 0.35)), belly)
    for side in (-1, 1):
        body.paint(
            "EarIn", ellipsoid((side * 0.66, 1.86, -0.02), (0.33, 0.33, 0.12), rot(0, side * 18, side * 18)), pink
        )
    body.paint("Nose", sphere((0, 0.98, -1.27), 0.11), NOSE)
    blush(body, s, 0.6, 0.98)
    smile(body, s, 0.84, width=0.06)
    eyes(a, s, 0.34, 1.22, size=(0.15, 0.19, 0.1))
    # ocásek (zakroucený)
    pts = [(0, 0.45, 0.95), (0.3, 0.35, 1.4), (0.7, 0.45, 1.6), (0.95, 0.8, 1.5), (0.85, 1.05, 1.3)]
    t = Shape()
    for p0, p1 in zip(pts[:-1], pts[1:]):
        t.add(capsule(p0, p1, 0.075), 0.04)
    a.piece("Tail", t, pink, res=0.015, density=700)
    # vousky
    w = Shape()
    for side in (-1, 1):
        for k, dy in enumerate((0.05, -0.05, -0.14)):
            w.add(capsule((side * 0.22, 0.98 + dy, -1.05), (side * 0.75, 1.03 + dy * 2.2, -0.95 + k * 0.04), 0.018))
    a.piece("Whiskers", w, (90, 70, 60), res=0.01, density=900)
    return a


def _beetle_legs(a, color, z_list=(-0.45, 0.1, 0.6), spread=0.85, name="Legs"):
    s = Shape()
    for side in (-1, 1):
        for i, z in enumerate(z_list):
            knee = (side * (spread + 0.25), 0.55, z + (i - 1) * 0.12)
            foot = (side * (spread + 0.35), 0.06, z + (i - 1) * 0.3)
            s.add(capsule((side * 0.5, 0.55, z), knee, 0.075), 0.03)
            s.add(capsule(knee, foot, 0.065), 0.03)
            s.add(ellipsoid(foot, (0.1, 0.06, 0.13)), 0.03)
    a.piece(name, s, color, res=0.015, density=700)


def scarab_bug(cell):
    a = Asset("ScarabBug", cell)
    shell, head, seam, spot = (30, 160, 140), (120, 220, 195), (15, 95, 85), (255, 210, 80)
    s = Shape(ellipsoid((0, 0.88, 0.25), (0.95, 0.66, 1.12)))
    s.add(ellipsoid((0, 0.7, 0.2), (0.85, 0.45, 1.0)), 0.1)
    body = a.piece("Shell", s, shell)
    body.paint("Seam", round_box((0, 1.3, 0.45), (0.035, 0.7, 1.0), 0.02), seam)
    for side in (-1, 1):
        for (y, z, r) in ((1.25, 0.05, 0.13), (1.12, 0.65, 0.16), (0.95, 1.05, 0.11)):
            p, n = surface_point(s, (side * 0.3, 0.88, z), (side * 0.6, (y - 0.88), 0))
            body.paint("Spots", sphere(p, r), spot)
    h = Shape(ellipsoid((0, 0.82, -0.72), (0.66, 0.58, 0.5)))
    h.add(round_cone((0, 1.15, -0.95), (0, 1.55, -1.12), 0.13, 0.08), 0.08)
    h.add(round_cone((0, 1.55, -1.12), (0, 1.78, -0.92), 0.08, 0.05), 0.04)
    hp = a.piece("Head", h, head)
    hp.paint("Horn", sphere((0, 1.65, -1.05), 0.42), seam)
    blush(hp, h, 0.42, 0.68, size=(0.12, 0.08, 0.2), oz=-0.7)
    smile(hp, h, 0.6, width=0.055, oz=-0.7)
    eyes(a, h, 0.27, 0.9, size=(0.14, 0.18, 0.1), origin_z=-0.7)
    ant = Shape()
    for side in (-1, 1):
        ant.add(capsule((side * 0.25, 1.25, -0.8), (side * 0.55, 1.75, -0.75), 0.035))
        ant.add(sphere((side * 0.57, 1.78, -0.75), 0.08), 0.03)
    a.piece("Antennae", ant, seam, res=0.012, density=800)
    _beetle_legs(a, (25, 70, 65))
    return a


def fennec_fox(cell):
    a = Asset("FennecFox", cell)
    fur, cream, inner, dark = (240, 168, 92), (255, 244, 228), (255, 208, 190), (110, 60, 35)
    s = chibi_body(head_r=(0.92, 0.86, 0.88), low_r=(0.82, 0.58, 0.82))
    s.add(round_cone((0, 1.02, -0.4), (0, 0.92, -1.12), 0.45, 0.15), 0.22)
    for side in (-1, 1):
        s.add(flat_cone((side * 0.42, 1.72, 0.12), (side * 1.12, 2.9, 0.3), 0.42, 0.06, 0.32, (0, 0, -1)), 0.15)
        s.add(ellipsoid((side * 0.42, 0.25, -0.38), (0.2, 0.25, 0.22)), 0.08)
        s.add(ellipsoid((side * 0.45, 0.25, 0.55), (0.2, 0.25, 0.22)), 0.08)
    tail = [((0.3, 0.6, 0.85), (0.36, 0.36, 0.48)), ((0.55, 1.05, 1.3), (0.42, 0.5, 0.42)), ((0.62, 1.6, 1.38), (0.34, 0.4, 0.34))]
    for c, r in tail:
        s.add(ellipsoid(c, r), 0.25)
    body = a.piece("Body", s, fur)
    body.paint("Chest", ellipsoid((0, 0.72, -0.62), (0.48, 0.48, 0.42)), cream)
    body.paint("Muzzle", ellipsoid((0, 0.86, -0.92), (0.36, 0.22, 0.4)), cream)
    body.paint("Cheeks", ellipsoid((0, 1.0, -0.62), (0.85, 0.2, 0.3)), cream)
    body.paint("TailTip", sphere((0.66, 1.85, 1.42), 0.36), cream)
    for side in (-1, 1):
        body.paint(
            "EarIn",
            flat_cone((side * 0.45, 1.85, 0.0), (side * 1.05, 2.8, 0.18), 0.28, 0.05, 0.9, (0, 0, -1)),
            inner,
        )
        body.paint("Socks", ellipsoid((side * 0.43, 0.08, -0.38), (0.24, 0.17, 0.26)), dark)
        body.paint("Socks", ellipsoid((side * 0.46, 0.08, 0.55), (0.24, 0.17, 0.26)), dark)
    body.paint("Nose", sphere((0, 0.98, -1.25), 0.11), DARK)
    blush(body, s, 0.62, 0.98)
    smile(body, s, 0.82, width=0.055)
    eyes(a, s, 0.36, 1.28)
    return a


def lily_frog(cell):
    a = Asset("LilyFrog", cell)
    green, belly, pad, petal, mid = (125, 205, 105), (226, 242, 178), (70, 165, 85), (255, 170, 205), (255, 220, 80)
    s = Shape(ellipsoid((0, 0.78, 0), (1.05, 0.72, 0.95)))
    for side in (-1, 1):
        s.add(sphere((side * 0.46, 1.36, -0.32), 0.36), 0.2)
        s.add(ellipsoid((side * 0.82, 0.42, 0.35), (0.38, 0.32, 0.52)), 0.15)
        s.add(ellipsoid((side * 0.55, 0.1, -0.62), (0.3, 0.1, 0.28)), 0.08)
        s.add(ellipsoid((side * 0.95, 0.1, 0.7), (0.3, 0.1, 0.32)), 0.08)
    body = a.piece("Body", s, green)
    body.paint("Belly", ellipsoid((0, 0.55, -0.6), (0.75, 0.48, 0.6)), belly)
    blush(body, s, 0.72, 0.8, size=(0.2, 0.12, 0.3))
    p, n = surface_point(s, (0, 0.78, 0), (0, 0, -1))
    R = basis_z(n)
    body.paint("Mouth", scaled(arc((0, 0, 0), 0.32, 0.03, 50, down=True), p + R[:, 1] * 0.33, R, (1, 1, 6)), DARK)
    eyes(a, s, 0.46, 1.4, size=(0.16, 0.2, 0.11), origin_y=1.36, origin_z=-0.32)
    # leknín s kytičkou na hlavě
    lp = Shape(cylinder((0, 1.53, 0.12), 0.035, 0.42, 0.03, rot(-8, 0, 0)))
    lp.sub(round_box((0.18, 1.53, -0.25), (0.06, 0.2, 0.28), 0, rot(0, 35, 0)))
    a.piece("LilyPad", lp, pad, res=0.012, density=700)
    fl = Shape()
    for k in range(5):
        ang = np.radians(k * 72)
        c = (np.sin(ang) * 0.14, 1.62, 0.12 + np.cos(ang) * 0.14)
        fl.add(ellipsoid(c, (0.1, 0.06, 0.15), rot(0, k * 72, 0) @ rot(-25, 0, 0)), 0.02)
    a.piece("Flower", fl, petal, res=0.01, density=800)
    a.piece("FlowerMid", Shape(sphere((0, 1.67, 0.12), 0.07)), mid, res=0.01, density=800)
    return a


def oasis_turtle(cell):
    a = Asset("OasisTurtle", cell)
    skin, shell, plate, rim = (168, 216, 122), (40, 140, 120), (95, 200, 165), (230, 210, 150)
    s = Shape(ellipsoid((0, 0.88, 0.15), (1.0, 0.66, 1.1)))
    s.add(ellipsoid((0, 0.55, 0.15), (1.14, 0.2, 1.24)), 0.12)
    s.add(ellipsoid((0, 0.85, -1.0), (0.52, 0.48, 0.5)), 0.2)
    for side in (-1, 1):
        s.add(ellipsoid((side * 0.72, 0.25, -0.5), (0.28, 0.26, 0.3)), 0.1)
        s.add(ellipsoid((side * 0.72, 0.25, 0.8), (0.28, 0.26, 0.3)), 0.1)
    s.add(round_cone((0, 0.45, 1.25), (0, 0.35, 1.55), 0.14, 0.05), 0.06)
    body = a.piece("Body", s, skin)
    head_zone = ellipsoid((0, 0.85, -1.0), (0.62, 0.58, 0.64))
    shell_vol = smax_f(smax_f(ellipsoid((0, 0.88, 0.15), (1.06, 0.72, 1.16)), lambda P: 0.42 - P[:, 1]), lambda P: -head_zone(P))
    body.paint("Shell", shell_vol, shell)
    rim_vol = smax_f(ellipsoid((0, 0.55, 0.15), (1.2, 0.26, 1.3)), lambda P: -ellipsoid((0, 0.88, 0.15), (0.96, 0.62, 1.06))(P))
    body.paint("Rim", smax_f(rim_vol, lambda P: -head_zone(P)), rim)
    top, _ = surface_point(s, (0, 0.9, 0.15), (0, 1, 0))
    body.paint("Plates", sphere(top, 0.34), plate)
    for k in range(6):
        ang = np.radians(k * 60 + 30)
        d = (np.sin(ang), 0.75, np.cos(ang) * 1.05)
        p, _ = surface_point(s, (0, 0.9, 0.15), d)
        body.paint("Plates", sphere(p, 0.3), plate)
    blush(body, s, 0.4, 0.75, size=(0.12, 0.08, 0.2))
    smile(body, s, 0.68, width=0.05)
    eyes(a, s, 0.24, 0.95, size=(0.13, 0.17, 0.09), origin_z=-1.0)
    return a


def smax_f(f, g, k=0.0):
    return lambda P: smax(f(P), g(P), k)


def palm_parrot(cell):
    a = Asset("PalmParrot", cell)
    red, yellow, blue, green, face = (232, 62, 56), (255, 206, 60), (60, 120, 230), (80, 190, 95), (255, 245, 235)
    s = Shape(ellipsoid((0, 1.0, 0.05), (0.72, 0.92, 0.7)))
    s.add(sphere((0, 1.72, -0.08), 0.56), 0.32)
    for side in (-1, 1):
        s.add(ellipsoid((side * 0.66, 1.05, 0.18), (0.2, 0.62, 0.48), rot(-12, 0, side * 10)), 0.08)
        s.add(ellipsoid((side * 0.24, 0.12, -0.12), (0.12, 0.1, 0.18)), 0.1)
    body = a.piece("Body", s, red)
    body.paint("Belly", ellipsoid((0, 0.72, -0.55), (0.55, 0.5, 0.42)), yellow)
    for side in (-1, 1):
        body.paint("Wing", ellipsoid((side * 0.78, 1.05, 0.18), (0.26, 0.68, 0.56), rot(-12, 0, side * 10)), blue)
        body.paint("WingTip", ellipsoid((side * 0.8, 0.55, 0.35), (0.3, 0.3, 0.4)), green)
        body.paint("Face", ellipsoid((side * 0.3, 1.72, -0.48), (0.28, 0.24, 0.2)), face)
    body.paint("Feet", sphere((0, 0.1, -0.12), 0.25), (120, 120, 130))
    eyes(a, s, 0.3, 1.78, size=(0.13, 0.16, 0.09))
    bk = Shape(round_cone((0, 1.72, -0.5), (0, 1.5, -0.86), 0.2, 0.06))
    bk.add(ellipsoid((0, 1.62, -0.62), (0.16, 0.16, 0.18)), 0.08)
    beak = a.piece("Beak", bk, (255, 196, 70), res=0.012, density=800)
    beak.paint("BeakLow", round_box((0, 1.45, -0.6), (0.3, 0.1, 0.3), 0), (70, 60, 60))
    for i, (tip, col) in enumerate((((0, -0.35, 1.0), red), ((-0.28, -0.25, 0.9), blue), ((0.28, -0.25, 0.9), yellow))):
        tf = Shape(flat_cone((tip[0] * 0.2, 0.5, 0.45), tip, 0.18, 0.07, 0.3, (0, 1, 0.3)))
        a.piece("Tail%d" % i, tf, col, res=0.014, density=700)
    cr = Shape()
    for ang in (-35, 0, 35):
        r = np.radians(ang)
        cr.add(flat_cone((0, 2.18, -0.02), (np.sin(r) * 0.45, 2.62, 0.25 + abs(np.sin(r)) * 0.1), 0.1, 0.03, 0.35, (0, 0.3, -1)), 0.03)
    a.piece("Crest", cr, green, res=0.012, density=800)
    return a


def water_spirit(cell):
    a = Asset("WaterSpirit", cell)
    water, core, navy = (110, 205, 255), (140, 245, 255), (20, 45, 95)
    s = Shape(sphere((0, 1.05, 0), 0.88))
    s.add(round_cone((0, 1.35, 0.08), (0, 2.3, 0.42), 0.5, 0.07), 0.35)
    s.add(round_cone((0, 2.3, 0.42), (0, 2.38, 0.72), 0.07, 0.04), 0.05)
    for side in (-1, 1):
        s.add(flat_cone((side * 0.7, 0.95, 0.05), (side * 1.12, 0.62, -0.1), 0.2, 0.06, 0.4, (0, 0, -1)), 0.12)
    body = a.piece("Body", s, water, "G")
    blush(body, s, 0.55, 0.92, color=(255, 170, 200))
    smile(body, s, 0.82, width=0.06, color=navy)
    eyes(a, s, 0.32, 1.15, size=(0.15, 0.2, 0.1), color=navy)
    a.piece("Core", Shape(sphere((0, 1.0, 0.1), 0.42)), core, "N", res=0.02)
    d = Shape()
    for c, r in (((0.98, 0.55, 0.4), 0.13), ((-1.0, 1.55, 0.25), 0.11), ((0.75, 1.95, -0.15), 0.09)):
        d.add(sphere(c, r))
        d.add(round_cone(c, (c[0], c[1] + r * 1.9, c[2]), r, 0.02), r * 0.6)
    a.piece("Drops", d, water, "G", res=0.012, density=700)
    return a


def mummy_cat(cell):
    a = Asset("MummyCat", cell)
    wrap, gap, inner = (240, 232, 212), (196, 182, 156), (225, 170, 165)
    s = chibi_body(head_r=(0.95, 0.85, 0.88))
    for side in (-1, 1):
        s.add(flat_cone((side * 0.42, 1.72, 0.05), (side * 0.72, 2.42, 0.15), 0.32, 0.05, 0.45, (0, 0, -1)), 0.12)
    tail = [(0, 0.5, 0.85), (0.25, 0.55, 1.25), (0.45, 0.95, 1.35), (0.45, 1.35, 1.2)]
    for p0, p1 in zip(tail[:-1], tail[1:]):
        s.add(capsule(p0, p1, 0.11), 0.06)
    body = a.piece("Body", s, wrap)
    feet(s, body, r=(0.25, 0.15, 0.3))
    bands = [
        (0.35, 0, 8, 0),
        (0.62, 0, -10, 0),
        (0.9, 0, 6, 0),
        (1.55, 0, -14, 0),
        (1.78, 0, 10, 0),
        (1.02, 0, 22, 0),
    ]
    for y, rx, rz, ry in bands:
        body.paint("Band", round_box((0, y, 0), (2.5, 0.028, 2.5), 0, rot(rx, ry, rz)), gap)
    for side in (-1, 1):
        body.paint(
            "EarIn", flat_cone((side * 0.44, 1.8, -0.05), (side * 0.7, 2.35, 0.05), 0.2, 0.04, 1.0, (0, 0, -1)), inner
        )
    body.paint("Nose", sphere((0, 1.05, -0.88), 0.07), NOSE)
    blush(body, s, 0.6, 1.0, color=(240, 160, 160))
    smile(body, s, 0.94, width=0.055)
    # jedno oko svítí zeleně, druhé je pod obvazem (spokojeně přivřené)
    p, n = surface_point(s, (-0.25, 1.3, 0), (-0.15, 0, -1))
    R = basis_z(n)
    a.piece("EyeGlow", Shape(ellipsoid(p - n * 0.04, (0.17, 0.2, 0.1), R)), (120, 255, 150), "N", res=0.012)
    a.piece("EyeGlowShine", Shape(sphere(p + R[:, 0] * 0.06 + R[:, 1] * 0.08 + n * 0.06, 0.05)), WHITE, "N", res=0.01)
    p2, n2 = surface_point(s, (0.25, 1.3, 0), (0.15, 0, -1))
    R2 = basis_z(n2)
    body.paint("EyeClosed", scaled(arc((0, 0, 0), 0.12, 0.028, 65, down=False), p2 - R2[:, 1] * 0.06, R2, (1, 1, 6)), DARK)
    loose = Shape(flat_cone((0.72, 1.62, 0.05), (1.02, 1.18, 0.2), 0.15, 0.12, 0.28, (0.35, 0.1, -1)))
    a.piece("LooseBand", loose, wrap, res=0.012, density=700)
    return a


def golden_scarab(cell):
    a = Asset("GoldenScarab", cell)
    gold, lapis, bronze, sun = (255, 196, 60), (35, 75, 190), (150, 100, 35), (255, 140, 40)
    s = Shape(ellipsoid((0, 0.9, 0.25), (1.0, 0.68, 1.15)))
    s.add(ellipsoid((0, 0.72, 0.2), (0.9, 0.45, 1.05)), 0.1)
    for side in (-1, 1):
        s.add(capsule((side * 0.45, 1.35, -0.4), (side * 0.6, 1.25, 1.0), 0.07), 0.12)
    body = a.piece("Shell", s, gold, "M")
    body.paint("Seam", round_box((0, 1.3, 0.45), (0.05, 0.7, 1.0), 0.02), lapis)
    body.paint("Edge", smax_f(ellipsoid((0, 0.72, 0.2), (1.2, 0.3, 1.3)), lambda P: P[:, 1] - 0.62), lapis)
    h = Shape(ellipsoid((0, 0.85, -0.75), (0.66, 0.55, 0.5)))
    for side in (-1, 1):
        h.add(round_cone((side * 0.2, 1.2, -0.85), (side * 0.32, 1.5, -0.95), 0.07, 0.04), 0.05)
    hp = a.piece("Head", h, (236, 176, 70), "M")
    hp.paint("Face", ellipsoid((0, 0.78, -1.1), (0.5, 0.4, 0.3)), (255, 226, 150), "S")
    blush(hp, h, 0.42, 0.7, size=(0.12, 0.08, 0.2), oz=-0.72)
    smile(hp, h, 0.62, width=0.055, oz=-0.72)
    eyes(a, h, 0.27, 0.92, size=(0.14, 0.18, 0.1), origin_z=-0.72)
    a.piece("Sun", Shape(sphere((0, 1.95, -0.85), 0.3)), sun, "N", res=0.015)
    a.piece("SunRing", Shape(torus((0, 1.95, -0.85), 0.38, 0.035, rot(90, 0, 0))), gold, "M", res=0.01)
    gem = Shape(round_box((0, 1.52, 0.45), (0.14, 0.14, 0.14), 0.03, rot(45, 0, 45)))
    a.piece("Gem", gem, (230, 40, 70), "N", res=0.01)
    _beetle_legs(a, bronze)
    return a


def sphinx_cat(cell):
    a = Asset("SphinxCat", cell)
    fur, gold, blue, inner = (236, 196, 132), (255, 204, 70), (40, 90, 205), (245, 175, 160)
    s = chibi_body(head_r=(0.95, 0.85, 0.88), low_r=(0.86, 0.6, 0.84))
    for side in (-1, 1):
        s.add(flat_cone((side * 0.42, 1.8, 0.05), (side * 0.75, 2.62, 0.12), 0.33, 0.05, 0.45, (0, 0, -1)), 0.12)
    tail = [(0, 0.45, 0.85), (0.4, 0.3, 1.2), (0.75, 0.45, 1.25), (0.9, 0.8, 1.05)]
    for p0, p1 in zip(tail[:-1], tail[1:]):
        s.add(capsule(p0, p1, 0.1), 0.06)
    body = a.piece("Body", s, fur)
    feet(s, body, r=(0.25, 0.15, 0.32))
    body.paint("Muzzle", ellipsoid((0, 0.96, -0.85), (0.34, 0.24, 0.22)), (255, 236, 206))
    for side in (-1, 1):
        body.paint(
            "EarIn", flat_cone((side * 0.44, 1.9, -0.05), (side * 0.72, 2.55, 0.02), 0.2, 0.04, 1.0, (0, 0, -1)), inner
        )
    body.paint("TailTip", sphere((0.9, 0.8, 1.05), 0.15), gold)
    body.paint("Nose", sphere((0, 1.05, -0.92), 0.08), NOSE)
    blush(body, s, 0.6, 0.98)
    smile(body, s, 0.92, width=0.055)
    eye_fs = eyes(a, s, 0.37, 1.24, size=(0.15, 0.19, 0.1))
    # linky kolem očí (egyptské líčení)
    for side in (-1, 1):
        p, n = surface_point(s, (side * 0.37 * 0.6, 1.24, 0), (side * 0.15, 0, -1))
        R = basis_z(n)
        outer = p + R[:, 0] * side * 0.2 - R[:, 1] * 0.02
        body.paint("Liner", capsule(outer, outer + R[:, 0] * side * 0.2 - R[:, 1] * 0.08, 0.03), DARK)
    # čelenka nemes
    hd = Shape(ellipsoid((0, 1.38, 0.08), (1.03, 0.78, 0.95)))
    hd.sub(round_box((0, 1.0, -0.75), (0.66, 0.5, 0.6), 0.2), 0.04)
    hd.sub(lambda P: P[:, 1] - 1.0, 0.03)
    for side in (-1, 1):
        hd.add(round_box((side * 0.8, 0.95, -0.05), (0.16, 0.48, 0.32), 0.1, rot(0, 0, side * 6)), 0.08)
    hp = a.piece("Headdress", hd, gold, res=0.026, density=380)
    for y in (0.6, 0.85, 1.1, 1.35, 1.62, 1.88):
        hp.paint("Stripe", round_box((0, y, 0), (3, 0.06, 3), 0), blue)
    co = Shape(torus((0, 0.8, 0.05), 0.84, 0.11))
    cp = a.piece("Collar", co, gold, "M", res=0.02, density=300)
    cp.paint("CollarBlue", round_box((0, 0.8, 0.05), (3, 0.035, 3), 0), blue)
    a.piece("Cobra", Shape(round_cone((0, 1.75, -0.78), (0, 2.05, -0.8), 0.1, 0.07)).add(sphere((0, 2.08, -0.82), 0.1), 0.05), gold, "M", res=0.012)
    return a


def sun_dragon(cell):
    a = Asset("SunDragon", cell)
    orange, belly, plate, membrane, bone, horn = (255, 138, 38), (255, 226, 140), (240, 190, 90), (238, 72, 48), (190, 60, 30), (255, 244, 214)
    s = chibi_body(head_c=(0, 1.2, 0), head_r=(0.92, 0.85, 0.88), low_c=(0, 0.65, 0.15), low_r=(0.88, 0.62, 0.88))
    s.add(round_cone((0, 1.05, -0.42), (0, 0.98, -1.05), 0.5, 0.33), 0.2)
    s.sub(sphere((0.14, 1.12, -1.33), 0.06), 0.02)
    s.sub(sphere((-0.14, 1.12, -1.33), 0.06), 0.02)
    for side in (-1, 1):
        s.add(flat_cone((side * 0.78, 1.28, 0.1), (side * 1.18, 1.5, 0.38), 0.2, 0.03, 0.3, (side, 0, -0.3)), 0.08)
        s.add(ellipsoid((side * 0.6, 0.75, -0.62), (0.17, 0.2, 0.17)), 0.1)
    tail = [((0, 0.55, 0.8), 0.38), ((0.3, 0.45, 1.4), 0.26), ((0.75, 0.62, 1.78), 0.16), ((0.95, 1.05, 1.88), 0.09)]
    for (p0, r0), (p1, r1) in zip(tail[:-1], tail[1:]):
        s.add(round_cone(p0, p1, r0, r1), 0.12)
    body = a.piece("Body", s, orange)
    feet(s, body, r=(0.27, 0.16, 0.34), paint=belly)
    bel = ellipsoid((0, 0.72, -0.6), (0.58, 0.52, 0.5))
    body.paint("Belly", bel, belly)
    for y in (0.48, 0.68, 0.88):
        body.paint("Plate", smax_f(round_box((0, y, -0.8), (1, 0.025, 1), 0), bel), plate)
    body.paint("Snout", ellipsoid((0, 0.95, -0.9), (0.42, 0.3, 0.38)), belly)
    for side in (-1, 1):
        body.paint("Frill", flat_cone((side * 0.86, 1.32, 0.15), (side * 1.18, 1.5, 0.38), 0.22, 0.05, 1.5, (side, 0, -0.3)), membrane)
        body.paint("Nostril", sphere((side * 0.14, 1.12, -1.33), 0.09), bone)
    blush(body, s, 0.66, 1.25, size=(0.15, 0.09, 0.22))
    smile(body, s, 0.86, width=0.07, double=False, angle=60)
    eyes(a, s, 0.42, 1.52, size=(0.17, 0.21, 0.11))
    a.piece("Fang", Shape(round_cone((0.12, 0.87, -1.27), (0.12, 0.76, -1.3), 0.045, 0.01)), WHITE, res=0.008)
    hs = Shape()
    for side in (-1, 1):
        hs.add(round_cone((side * 0.36, 1.85, 0.05), (side * 0.5, 2.25, 0.3), 0.15, 0.1), 0.05)
        hs.add(round_cone((side * 0.5, 2.25, 0.3), (side * 0.52, 2.42, 0.66), 0.1, 0.03), 0.05)
    a.piece("Horns", hs, horn, res=0.014, density=700)
    sp = Shape()
    for z, y, r in ((0.35, 2.0, 0.14), (0.7, 1.72, 0.13), (1.0, 1.35, 0.12), (1.28, 0.95, 0.1)):
        sp.add(round_cone((0, y - 0.2, z), (0, y + 0.12, z + 0.12), r, 0.02))
    a.piece("Spikes", sp, membrane, res=0.014, density=700)
    # netopýří křídla: kosti + blána mezi nimi
    for side in (-1, 1):
        sh = np.array([side * 0.55, 1.5, 0.62])
        el = np.array([side * 1.2, 2.15, 0.9])
        tips = [np.array([side * 2.05, 2.05, 1.05]), np.array([side * 1.95, 1.4, 1.1]), np.array([side * 1.5, 0.95, 1.0])]
        w = Shape(triangle(sh, el, tips[2], 0.035))
        w.add(triangle(el, tips[0], tips[1], 0.035), 0.02)
        w.add(triangle(el, tips[1], tips[2], 0.035), 0.02)
        for i in range(2):
            mid = (tips[i] + tips[i + 1]) / 2
            out = mid + (mid - el) / np.linalg.norm(mid - el) * 0.22
            w.sub(sphere(out, 0.3), 0.03)
        mid = (sh + tips[2]) / 2
        w.sub(sphere(mid + (mid - el) / np.linalg.norm(mid - el) * 0.22, 0.3), 0.03)
        w.add(capsule(sh, el, 0.085), 0.05)
        for t in tips:
            w.add(round_cone(el, t, 0.065, 0.025), 0.03)
        wp = a.piece("Wing" + ("L" if side < 0 else "R"), w, membrane, res=0.016, density=600)
        wp.paint("Bone", capsule(sh, el, 0.1), bone)
        for t in tips:
            wp.paint("Bone", round_cone(el, t, 0.08, 0.04), bone)
        wp.paint("Bone", sphere(el, 0.12), horn)
    fl = Shape(sphere((1.0, 1.3, 1.92), 0.2))
    fl.add(round_cone((1.0, 1.3, 1.92), (1.05, 1.85, 2.0), 0.2, 0.03), 0.1)
    a.piece("Flame", fl, (255, 120, 30), "N", res=0.012)
    a.piece("FlameCore", Shape(sphere((1.0, 1.3, 1.9), 0.12)).add(round_cone((1.0, 1.3, 1.9), (1.02, 1.6, 1.95), 0.12, 0.02), 0.06), (255, 230, 120), "N", res=0.01)
    return a


# ---------------------------------------------------------------- vajíčka


def egg_shape():
    return Shape(sphere((0, 1.0, 0), 0.98)).add(sphere((0, 1.82, 0), 0.6), 0.85)


def sand_egg(cell):
    a = Asset("SandEgg", cell)
    s = egg_shape()
    e = a.piece("Shell", s, (246, 226, 182), density=300)
    spots = [((0.6, 1.5, -0.6), 0.2), ((-0.75, 1.1, -0.5), 0.26), ((0.1, 2.25, -0.3), 0.15), ((0.85, 0.8, 0.3), 0.22),
             ((-0.3, 0.55, -0.85), 0.17), ((-0.6, 1.8, 0.45), 0.2), ((0.2, 1.2, 0.95), 0.24), ((-0.9, 0.9, 0.5), 0.15)]
    for d, r in spots:
        p, _ = surface_point(s, (0, 1.2, 0), d)
        e.paint("Spots", sphere(p, r), (205, 150, 90))
    zig = lambda P: np.abs(P[:, 1] - 1.3 - 0.1 * np.abs(((np.arctan2(P[:, 2], P[:, 0]) * 8 / np.pi) % 2) - 1) * 2) - 0.035
    e.paint("Zigzag", zig, (225, 180, 115))
    return a


def oasis_egg(cell):
    a = Asset("OasisEgg", cell)
    s = egg_shape()
    e = a.piece("Shell", s, (88, 200, 214), density=300)
    wave = lambda P: np.abs(P[:, 1] - 1.15 - 0.09 * np.sin(6 * np.arctan2(P[:, 2], P[:, 0]))) - 0.11
    e.paint("Wave", wave, (238, 255, 250))
    for d, r in (((0.5, 1.9, -0.6), 0.16), ((-0.7, 0.6, -0.4), 0.2), ((0.8, 0.55, 0.4), 0.15), ((-0.4, 2.05, 0.5), 0.13), ((0.1, 0.4, 0.9), 0.17)):
        p, _ = surface_point(s, (0, 1.2, 0), d)
        e.paint("Dots", sphere(p, r), (130, 215, 120))
    return a


def pharaoh_egg(cell):
    a = Asset("PharaohEgg", cell)
    s = egg_shape()
    e = a.piece("Shell", s, (255, 200, 62), "M", density=150)
    for y in (0.75, 1.55):
        e.paint("Band", round_box((0, y, 0), (3, 0.08, 3), 0), (38, 78, 195), "S")
    for k in range(10):
        ang = k * np.pi / 5
        p, _ = surface_point(s, (0, 1.15, 0), (np.cos(ang), 0, np.sin(ang)))
        e.paint("Dots", sphere(p, 0.07), (38, 78, 195), "S")
    p, n = surface_point(s, (0, 1.4, 0), (0, 0.2, -1))
    a.piece("Gem", Shape(round_box(p, (0.17, 0.17, 0.1), 0.04, basis_z(n) @ rot(0, 0, 45))), (235, 40, 70), "N", res=0.01)
    return a


PETS = [sand_bunny, desert_mouse, scarab_bug, fennec_fox, lily_frog, oasis_turtle, palm_parrot, water_spirit, mummy_cat, golden_scarab, sphinx_cat, sun_dragon]
EGGS = [sand_egg, oasis_egg, pharaoh_egg]
