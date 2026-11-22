"""
SDF modelování – hladké "sochařské" 3D modely pro Roblox (MeshPart).

Tvar se skládá z primitiv (koule, elipsoid, kužel, kapsle, zaoblený kvádr…),
které se HLADCE spojují (smooth union) – díky tomu modely vypadají jako
vymodelované v Blenderu, ne slepené z kostek. Barvy se "malují" na povrch
(objem barvy protne povrch => ostrá hranice barev, jako textura).

Každá barevná oblast = samostatný uzavřený mesh (v Robloxu jeden MeshPart,
barvu nastaví hra podle jména). Jméno meshe:
    <Asset>__<Díl>__<RRGGBB>__<Materiál>__<cx>_<cz>
Materiál: S = SmoothPlastic, M = Metal, N = Neon, G = Glass (průhledné), W = Wood
"""

import numpy as np
from skimage.measure import marching_cubes
import fast_simplification

# ---------------------------------------------------------------- matematika


def rot(rx=0.0, ry=0.0, rz=0.0):
    """Rotace jako Roblox CFrame.Angles(rx, ry, rz) ve stupních (R = Rx·Ry·Rz)."""
    ax, ay, az = np.radians([rx, ry, rz])
    cx, sx, cy, sy, cz, sz = np.cos(ax), np.sin(ax), np.cos(ay), np.sin(ay), np.cos(az), np.sin(az)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rx @ Ry @ Rz


def basis_z(n, up=(0.0, 1.0, 0.0)):
    """Rotace, jejíž lokální osa Z míří ve směru n (pro "nalepení" na povrch)."""
    z = np.asarray(n, float)
    z = z / np.linalg.norm(z)
    upv = np.asarray(up, float)
    if abs(np.dot(z, upv)) > 0.95:
        upv = np.array([1.0, 0.0, 0.0])
    x = np.cross(upv, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1)


def _v(a):
    return np.asarray(a, dtype=float)


def _local(P, c, R):
    q = P - c
    return q if R is None else q @ R


def _len(q):
    return np.sqrt(np.sum(q * q, axis=-1))


# ---------------------------------------------------------------- primitiva


def sphere(c, r):
    c = _v(c)
    return lambda P: _len(P - c) - r


def ellipsoid(c, r, R=None):
    c, r = _v(c), _v(r)

    def f(P):
        q = _local(P, c, R)
        k0 = _len(q / r)
        k1 = _len(q / (r * r))
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

    return f


def round_cone(a, b, r1, r2):
    """Kužel se zaoblenými konci mezi body a (poloměr r1) a b (poloměr r2)."""
    a, b = _v(a), _v(b)
    ba = b - a
    l2 = float(np.dot(ba, ba))
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2

    def f(P):
        pa = P - a
        y = pa @ ba
        z = y - l2
        w = pa * l2 - np.outer(y, ba)
        x2 = np.sum(w * w, axis=-1)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        d1 = np.sqrt(x2 + z2) * il2 - r2
        d2 = np.sqrt(x2 + y2) * il2 - r1
        d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
        return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))

    return f


def capsule(a, b, r):
    return round_cone(a, b, r, r)


def round_box(c, half, r=0.0, R=None):
    c, half = _v(c), _v(half)

    def f(P):
        q = np.abs(_local(P, c, R)) - half + r
        return _len(np.maximum(q, 0)) + np.minimum(np.max(q, axis=-1), 0) - r

    return f


def cylinder(c, h, ra, rb=0.0, R=None):
    """Válec s osou lokální Y, polovina výšky h, poloměr ra, zaoblení hran rb."""
    c = _v(c)

    def f(P):
        q = _local(P, c, R)
        dx = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - ra + rb
        dy = np.abs(q[:, 1]) - h + rb
        return np.minimum(np.maximum(dx, dy), 0) + np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2) - rb

    return f


def torus(c, major, minor, R=None):
    """Prstenec v lokální rovině XZ (osa Y)."""
    c = _v(c)

    def f(P):
        q = _local(P, c, R)
        qx = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - major
        return np.sqrt(qx * qx + q[:, 1] ** 2) - minor

    return f


def arc(c, major, minor, half_angle, R=None, down=True):
    """Oblouk (část prstence) v lokální rovině XY – úsměv, ucho hrnku, D-rukojeť."""
    c = _v(c)
    sa, ca = np.sin(np.radians(half_angle)), np.cos(np.radians(half_angle))

    def f(P):
        q = _local(P, c, R).copy()
        if down:
            q[:, 1] = -q[:, 1]
        qx = np.abs(q[:, 0])
        qy = q[:, 1]
        k = np.where(ca * qx > sa * qy, qx * sa + qy * ca, np.sqrt(qx * qx + qy * qy))
        return np.sqrt(np.maximum(qx * qx + qy * qy + q[:, 2] ** 2 + major * major - 2 * major * k, 0)) - minor

    return f


def triangle(a, b, c, thickness):
    """Tenká deska ve tvaru trojúhelníku (blána křídla)."""
    a, b, c = _v(a), _v(b), _v(c)
    ba, cb, ac = b - a, c - b, a - c
    nor = np.cross(ba, ac)
    n_ba, n_cb, n_ac = np.cross(ba, nor), np.cross(cb, nor), np.cross(ac, nor)

    def seg(p, d):
        t = np.clip((p @ d) / np.dot(d, d), 0, 1)
        q = np.outer(t, d) - p
        return np.sum(q * q, axis=-1)

    def f(P):
        pa, pb, pc = P - a, P - b, P - c
        inside = (np.sign(pa @ n_ba) + np.sign(pb @ n_cb) + np.sign(pc @ n_ac)) >= 2
        d_edge = np.minimum(np.minimum(seg(pa, ba), seg(pb, cb)), seg(pc, ac))
        d_face = (pa @ nor) ** 2 / np.dot(nor, nor)
        return np.sqrt(np.where(inside, d_face, d_edge)) - thickness

    return f


def plane(c, n):
    c, n = _v(c), _v(n)
    n = n / np.linalg.norm(n)
    return lambda P: (P - c) @ n


def scaled(fn_local, c, R, s):
    """Nerovnoměrně zmenšené primitivum: fn_local je definované v lokálním prostoru."""
    c, s = _v(c), _v(s)
    m = float(np.min(s))
    return lambda P: fn_local(_local(P, c, R) / s) * m


def flat_cone(a, b, r1, r2, thickness, normal):
    """Plochý kužel (ucho lišky, list, ploutev) – round_cone zploštělý ve směru normal."""
    a, b, normal = _v(a), _v(b), _v(normal)
    axis = (b - a) / np.linalg.norm(b - a)
    n = normal - axis * np.dot(normal, axis)
    n /= np.linalg.norm(n)
    x = np.cross(axis, n)
    R = np.stack([x, axis, n], axis=1)  # lokální: x=šířka, y=osa, z=tloušťka
    length = np.linalg.norm(b - a)
    local = round_cone((0, 0, 0), (0, length, 0), r1, r2)
    return scaled(local, a, R, (1.0, 1.0, thickness))


# ---------------------------------------------------------------- operace


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


class Shape:
    """Posloupnost operací: add (hladké sjednocení), sub (odečtení), inter (průnik)."""

    def __init__(self, f=None):
        self.ops = []
        if f is not None:
            self.add(f)

    def add(self, f, k=0.0):
        self.ops.append(("add", f, k))
        return self

    def sub(self, f, k=0.0):
        self.ops.append(("sub", f, k))
        return self

    def inter(self, f, k=0.0):
        self.ops.append(("inter", f, k))
        return self

    def __call__(self, P):
        d = None
        for op, f, k in self.ops:
            v = f(P)
            if d is None:
                d = v
            elif op == "add":
                d = smin(d, v, k)
            elif op == "sub":
                d = smax(d, -v, k)
            else:
                d = smax(d, v, k)
        return d


def union(*fs, k=0.0):
    s = Shape()
    for f in fs:
        s.add(f, k)
    return s


def gradient(f, P, e=1e-3):
    g = np.zeros_like(P)
    for i in range(3):
        d = np.zeros(3)
        d[i] = e
        g[:, i] = f(P + d) - f(P - d)
    n = np.linalg.norm(g, axis=1, keepdims=True)
    return g / np.maximum(n, 1e-12)


def surface_point(f, origin, direction, max_dist=6.0):
    """Najde bod na povrchu: od origin (uvnitř tvaru) ve směru direction."""
    o, d = _v(origin), _v(direction)
    d = d / np.linalg.norm(d)
    lo, hi = 0.0, max_dist
    if f(o[None])[0] > 0:
        raise ValueError(f"surface_point: počátek {origin} není uvnitř tvaru")
    for _ in range(60):
        mid = (lo + hi) / 2
        if f((o + d * mid)[None])[0] < 0:
            lo = mid
        else:
            hi = mid
    p = o + d * lo
    n = gradient(f, p[None])[0]
    return p, n


# ---------------------------------------------------------------- modely


def hex_color(c):
    return "%02X%02X%02X" % tuple(int(round(v)) for v in c)


class Piece:
    def __init__(self, name, shape, color, mat="S", res=0.025, density=480.0):
        self.name = name
        self.shape = shape
        self.color = color
        self.mat = mat
        self.res = res
        self.density = density
        self.paints = []

    def paint(self, name, f, color, mat=None):
        """Obarví část povrchu uvnitř objemu f (pozdější barva přebije dřívější)."""
        self.paints.append((name, f, color, mat or self.mat))
        return self


class Asset:
    def __init__(self, name, cell=(0, 0)):
        self.name = name
        self.cell = cell
        self.pieces = []

    def piece(self, name, shape, color, mat="S", res=0.025, density=480.0):
        p = Piece(name, shape, color, mat, res, density)
        self.pieces.append(p)
        return p


def _grid(lo, hi, step):
    axes = [np.arange(lo[i], hi[i] + step * 0.5, step) for i in range(3)]
    X, Y, Z = np.meshgrid(*axes, indexing="ij")
    return axes, np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1)


def _bounds(f, lo=(-6, -2, -8), hi=(6, 7, 8), step=0.1):
    axes, P = _grid(lo, hi, step)
    d = f(P).reshape(len(axes[0]), len(axes[1]), len(axes[2]))
    idx = np.argwhere(d < step * 1.2)
    if len(idx) == 0:
        return None
    a = np.array([axes[i][idx[:, i].min()] for i in range(3)]) - step
    b = np.array([axes[i][idx[:, i].max()] for i in range(3)]) + step
    return a, b


def mesh_piece(piece, search_lo=(-6, -2, -8), search_hi=(6, 7, 8)):
    """Vrátí seznam (jméno oblasti, barva, materiál, vertices, faces, normals)."""
    b = _bounds(piece.shape, search_lo, search_hi)
    if b is None:
        raise ValueError(f"Díl {piece.name} je prázdný")
    res = piece.res
    lo, hi = b[0] - 3 * res, b[1] + 3 * res
    axes, P = _grid(lo, hi, res)
    shape_dims = (len(axes[0]), len(axes[1]), len(axes[2]))
    F = piece.shape(P)
    # barva jen v tenké "slupce" pod povrchem – jinak by řezy uvnitř těla zbytečně
    # přidávaly tisíce schovaných trojúhelníků
    skin = max(4 * res, 0.08)
    paints = [np.maximum(p[1](P), -(F + skin)) for p in piece.paints]
    regions = [("", piece.color, piece.mat)] + [(n, c, m) for n, _, c, m in piece.paints]
    out = []
    for i, (rname, color, mat) in enumerate(regions):
        vol = F.copy()
        if i > 0:
            vol = np.maximum(vol, paints[i - 1])
        for j in range(i, len(paints)):
            vol = np.maximum(vol, -paints[j])
        if vol.min() >= 0:
            continue
        verts, faces, _, _ = marching_cubes(vol.reshape(shape_dims), level=0.0, spacing=(res, res, res))
        verts = verts + lo
        verts, faces = _decimate(verts, faces, piece.density * (1.6 if mat == "M" else 1.0))
        if len(faces) == 0:
            continue
        # orientace trojúhelníků ven – rozhoduje jen vnější povrch (|F| ~ 0),
        # vnitřní řezy mezi barvami jsou schované a nesmí hlasovat
        tri = verts[faces]
        fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        cen = tri.mean(axis=1)
        outer = np.abs(piece.shape(cen)) < res * 0.6
        if outer.sum() < 3:
            outer = np.ones(len(cen), bool)
        g = gradient(piece.shape, cen[outer])
        if np.sum(np.sum(fn[outer] * g, axis=1)) < 0:
            faces = faces[:, ::-1]
        normals = gradient(piece.shape, verts)
        out.append((piece.name + rname, color, mat, verts, faces, normals))
    return out


def _decimate(verts, faces, density):
    tri = verts[faces]
    area = 0.5 * np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1).sum()
    target = int(np.clip(area * density, 300, 6000))
    if len(faces) > target * 1.1:
        reduction = 1.0 - target / len(faces)
        verts, faces = fast_simplification.simplify(
            verts.astype(np.float32), faces.astype(np.int32), reduction, agg=9
        )
        verts = verts.astype(float)
    return verts, faces


def octahedron(c, s=0.12):
    c = _v(c)
    v = np.array([[s, 0, 0], [-s, 0, 0], [0, s, 0], [0, -s, 0], [0, 0, s], [0, 0, -s]]) + c
    f = np.array([[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]])
    return v, f
