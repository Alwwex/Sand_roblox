#!/usr/bin/env python3
"""
Sestaví hratelný place soubor DuneDiggers.rbxlx ze složky src/
(stejné rozložení jako default.project.json pro Rojo).

Použití:   python3 tools/build_place.py
Výsledek:  DuneDiggers.rbxlx  -> dvojklik / otevřít v Roblox Studiu

Pravidla pojmenování (jako Rojo):
  *.server.luau -> Script
  *.client.luau -> LocalScript
  *.luau        -> ModuleScript
  složka        -> Folder
"""
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUTPUT = ROOT / "DuneDiggers.rbxlx"

_ref = 0


def next_ref() -> str:
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def cdata(text: str) -> str:
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(class_name: str, name: str, children: list[str], source: str | None = None, indent: int = 1) -> str:
    pad = "\t" * indent
    lines = [f'{pad}<Item class="{class_name}" referent="{next_ref()}">', f"{pad}\t<Properties>"]
    lines.append(f'{pad}\t\t<string name="Name">{escape(name)}</string>')
    if source is not None:
        lines.append(f'{pad}\t\t<ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    lines.append(f"{pad}\t</Properties>")
    lines.extend(children)
    lines.append(f"{pad}</Item>")
    return "\n".join(lines)


def script_item(path: Path, indent: int) -> str:
    name = path.name
    if name.endswith(".server.luau"):
        cls, inst_name = "Script", name[: -len(".server.luau")]
    elif name.endswith(".client.luau"):
        cls, inst_name = "LocalScript", name[: -len(".client.luau")]
    else:
        cls, inst_name = "ModuleScript", name[: -len(".luau")]
    return item(cls, inst_name, [], path.read_text(encoding="utf-8"), indent)


def folder_item(name: str, path: Path, indent: int) -> str:
    children = []
    for child in sorted(path.iterdir()):
        if child.is_dir():
            children.append(folder_item(child.name, child, indent + 1))
        elif child.suffix == ".luau":
            children.append(script_item(child, indent + 1))
    return item("Folder", name, children, None, indent)


def build() -> str:
    services = [
        item("Workspace", "Workspace", []),
        item("ReplicatedStorage", "ReplicatedStorage", [folder_item("Shared", SRC / "shared", 2)]),
        item("ServerScriptService", "ServerScriptService", [folder_item("Server", SRC / "server", 2)]),
        item(
            "StarterPlayer",
            "StarterPlayer",
            [
                item("StarterPlayerScripts", "StarterPlayerScripts", [folder_item("Client", SRC / "client", 3)], None, 2),
                item("StarterCharacterScripts", "StarterCharacterScripts", [], None, 2),
            ],
        ),
    ]
    header = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        "\t<External>null</External>\n\t<External>nil</External>\n"
    )
    return header + "\n".join(services) + "\n</roblox>\n"


if __name__ == "__main__":
    OUTPUT.write_text(build(), encoding="utf-8")
    print(f"Hotovo: {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size // 1024} KB)")
