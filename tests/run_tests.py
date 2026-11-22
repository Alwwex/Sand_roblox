#!/usr/bin/env python3
"""
Spustí smoke test serverové logiky mimo Roblox.

Potřebuje Luau runner (binárka, která spustí .luau soubor), cestu předej
přes proměnnou prostředí LUAU_RUNNER. Viz tests/README.md.

    LUAU_RUNNER=/cesta/k/luaurun python3 tests/run_tests.py
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

SHARED = ["Config", "Remotes", "Util", "ToolFactory"]
CLIENT = ["UIKit", "Audio", "Effects", "Hotbar", "Hud", "Windows", "MainMenu", "DigController", "UI"]
SERVICES = [
    "Build",
    "LobbyBuilder",
    "Stats",
    "DataService",
    "WorldService",
    "TreasureService",
    "ShopService",
    "DigService",
    "MonetizationService",
    "SandstormService",
    "RewardService",
    "LeaderboardService",
]


def wrap(name: str, path: Path) -> str:
    body = path.read_text(encoding="utf-8")
    return f'mock.defineModule("{name}", function(script)\n{body}\nend)\n'


def build(preview: bool = False) -> str:
    parts = []
    mock_src = (ROOT / "tests" / "mock_roblox.luau").read_text(encoding="utf-8")
    parts.append("local mock = (function()\n" + mock_src + "\nend)()\n")
    for name in SHARED:
        parts.append(wrap(name, SRC / "shared" / f"{name}.luau"))
    for name in SERVICES:
        parts.append(wrap(name, SRC / "server" / "Services" / f"{name}.luau"))

    for name in CLIENT:
        parts.append(wrap(name, SRC / "client" / f"{name}.luau"))

    main_src = (SRC / "server" / "Main.server.luau").read_text(encoding="utf-8")
    client_src = (SRC / "client" / "Main.client.luau").read_text(encoding="utf-8")
    parts.append(
        """
local tree = {}
do
    local RS = mock.services.ReplicatedStorage
    local shared = Instance.new("Folder"); shared.Name = "Shared"; shared.Parent = RS
    tree.Shared = shared
"""
        + "".join(f'    mock.moduleScript("{n}", shared)\n' for n in SHARED)
        + """
    local serverFolder = Instance.new("Folder"); serverFolder.Name = "Server"
    local services = Instance.new("Folder"); services.Name = "Services"; services.Parent = serverFolder
    tree.Services = services
"""
        + "".join(f'    mock.moduleScript("{n}", services)\n' for n in SERVICES)
        + """
    local mainScript = Instance.new("Script"); mainScript.Name = "Main"; mainScript.Parent = serverFolder
    tree.Main = mainScript

    local clientFolder = Instance.new("Folder"); clientFolder.Name = "Client"
    tree.Client = clientFolder
"""
        + "".join(f'    mock.moduleScript("{n}", clientFolder)\n' for n in CLIENT)
        + """
    local clientMain = Instance.new("LocalScript"); clientMain.Name = "Main"; clientMain.Parent = clientFolder
    tree.ClientMain = clientMain
end

local function runMain()
    task.spawn(function(script)
"""
        + main_src
        + """
    end, tree.Main)
end

local function runClient()
    task.spawn(function(script)
"""
        + client_src
        + """
    end, tree.ClientMain)
end
"""
    )
    parts.append((ROOT / "tests" / "server_smoke.luau").read_text(encoding="utf-8"))
    if preview:
        parts.append((ROOT / "tests" / "preview_export.luau").read_text(encoding="utf-8"))
    else:
        parts.append((ROOT / "tests" / "client_smoke.luau").read_text(encoding="utf-8"))
    return "\n".join(parts)


def main() -> int:
    runner = os.environ.get("LUAU_RUNNER")
    if not runner:
        print("Nastav LUAU_RUNNER na cestu k Luau runneru (viz tests/README.md).")
        return 2
    preview_dir = None
    if "--preview" in sys.argv:
        preview_dir = Path(sys.argv[sys.argv.index("--preview") + 1])
        preview_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        bundle = Path(tmp) / "bundle.luau"
        bundle.write_text(build(preview_dir is not None), encoding="utf-8")
        if preview_dir is None:
            result = subprocess.run([runner, str(bundle)])
            return result.returncode
        # náhled: JSONy z výstupu uložíme do souborů
        result = subprocess.run([runner, str(bundle)], capture_output=True, text=True)
        count = 0
        for line in result.stdout.splitlines():
            if line.startswith("@@JSON "):
                _, name, payload = line.split(" ", 2)
                (preview_dir / f"{name}.json").write_text(payload, encoding="utf-8")
                count += 1
        print(f"Náhled: {count} JSON souborů -> {preview_dir}")
        if result.returncode != 0:
            print(result.stdout[-3000:], result.stderr[-3000:])
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
