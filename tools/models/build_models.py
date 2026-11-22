"""
Vygeneruje assets/models/DuneDiggersModels.glb – všechny 3D modely hry v jednom souboru.

Spuštění:  python3 tools/models/build_models.py            (vše)
           python3 tools/models/build_models.py SandBunny  (jen vybrané – rychlé ladění)

Soubor se importuje do Roblox Studia (File → Import 3D) – viz docs/NAVOD.md.
Každý mesh se jmenuje  <Asset>__<Díl>__<RRGGBB>__<Materiál>__<cx>_<cz>  a hra si podle
jména nastaví barvu, materiál a pozici. Značky RefOrigin/RefUp/RefRight/RefForward
slouží k automatické opravě měřítka a natočení po importu.
"""

import json
import os
import re
import sys
import time

import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sdf import hex_color, mesh_piece, octahedron  # noqa: E402
import pets  # noqa: E402
import tools  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "DuneDiggersModels.glb")
SPACING = 8.0  # rozestup modelů v souboru (studs) – jen aby byly po importu hezky vedle sebe
MAX_TRIS = 15000  # Roblox povolí max. 20 000 trojúhelníků na jeden mesh

MATERIALS = {
    "S": dict(metallic=0.0, rough=0.55),
    "M": dict(metallic=0.85, rough=0.3),
    "N": dict(metallic=0.0, rough=0.4),
    "G": dict(metallic=0.0, rough=0.1),
    "W": dict(metallic=0.0, rough=0.8),
}


def all_assets():
    assets = []
    for i, fn in enumerate(pets.PETS):
        assets.append(fn((i % 6, i // 6)))
    for j, fn in enumerate(pets.EGGS):
        assets.append(fn((j + 1, 2)))
    for j, fn in enumerate(tools.TOOLS):
        assets.append(fn((j, 4)))
    return assets


def make_mesh(name, color, mat, verts, faces, normals):
    m = trimesh.Trimesh(vertices=verts, faces=faces, vertex_normals=normals, process=False)
    props = MATERIALS[mat]
    alpha = 150 if mat == "G" else 255
    material = trimesh.visual.material.PBRMaterial(
        name=name,
        baseColorFactor=[int(color[0]), int(color[1]), int(color[2]), alpha],
        metallicFactor=props["metallic"],
        roughnessFactor=props["rough"],
        emissiveFactor=[c / 255 for c in color] if mat == "N" else None,
        alphaMode="BLEND" if mat == "G" else None,
    )
    m.visual = trimesh.visual.TextureVisuals(material=material)
    return m


def build(only=None):
    t0 = time.time()
    scene = trimesh.Scene()
    stats = {}
    for asset in all_assets():
        if only and asset.name not in only:
            continue
        t1 = time.time()
        off = np.array([asset.cell[0] * SPACING, 0.0, asset.cell[1] * SPACING])
        groups = {}
        order = []
        for piece in asset.pieces:
            for rname, color, mat, v, f, n in mesh_piece(piece):
                key = (hex_color(color), mat)
                if key not in groups:
                    groups[key] = []
                    order.append((key, rname))
                groups[key].append((v, f, n))
        tris = 0
        used = set()
        for (key, rname) in order:
            parts = groups[key]
            # spojit díly stejné barvy (méně MeshPartů v Robloxu), ale max. MAX_TRIS na mesh
            chunks, cur, cur_tris = [], [], 0
            for v, f, n in parts:
                if cur and cur_tris + len(f) > MAX_TRIS:
                    chunks.append(cur)
                    cur, cur_tris = [], 0
                cur.append((v, f, n))
                cur_tris += len(f)
            chunks.append(cur)
            for ci, chunk in enumerate(chunks):
                vs, fs, ns, base = [], [], [], 0
                for v, f, n in chunk:
                    vs.append(v + off)
                    fs.append(f + base)
                    ns.append(n)
                    base += len(v)
                label = rname if ci == 0 else "%s%d" % (rname, ci + 1)
                while label in used:
                    label += "X"
                used.add(label)
                name = "%s__%s__%s__%s__%d_%d" % (asset.name, label, key[0], key[1], asset.cell[0], asset.cell[1])
                # musí sedět se vzorem v src/shared/MeshLibrary.luau (Lua %w = jen písmena a číslice)
                if not re.fullmatch(r"[A-Za-z0-9]+__[A-Za-z0-9]+__[0-9A-F]{6}__[A-Z]__-?\d+_-?\d+", name):
                    raise ValueError("Neplatné jméno meshe: " + name)
                col = tuple(int(key[0][i : i + 2], 16) for i in (0, 2, 4))
                mesh = make_mesh(name, col, key[1], np.vstack(vs), np.vstack(fs), np.vstack(ns))
                scene.add_geometry(mesh, node_name=name, geom_name=name)
                tris += len(mesh.faces)
        stats[asset.name] = {"meshes": len(used), "tris": tris}
        print("  %-14s %3d meshů %6d trojúhelníků  (%.1f s)" % (asset.name, len(used), tris, time.time() - t1))
    # značky pro automatickou opravu měřítka/natočení po importu
    for name, pos in (("RefOrigin", (0, 0, 0)), ("RefUp", (0, 10, 0)), ("RefRight", (10, 0, 0)), ("RefForward", (0, 0, -10))):
        v, f = octahedron(pos, 0.15)
        m = make_mesh(name, (255, 0, 255), "N", v, f, v - np.array(pos))
        scene.add_geometry(m, node_name=name, geom_name=name)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out = OUT if not only else OUT.replace(".glb", "_test.glb")
    scene.export(out, file_type="glb", include_normals=True)
    total_m = sum(s["meshes"] for s in stats.values())
    total_t = sum(s["tris"] for s in stats.values())
    print("Hotovo: %s  (%d meshů, %d trojúhelníků, %.1f MB, %.0f s)" % (os.path.relpath(out, ROOT), total_m, total_t, os.path.getsize(out) / 1e6, time.time() - t0))
    with open(out.replace(".glb", ".json"), "w") as fh:
        json.dump(stats, fh, indent=1)
    return out


if __name__ == "__main__":
    build(set(sys.argv[1:]) or None)
