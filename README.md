# 🏜️ Dune Diggers – Roblox hra

Vykopej celou poušť – začínáš s holýma rukama, končíš s obřím bagrem.
Prodávej písek, kupuj lepší nástroje, hledej zakopané truhly, artefakty
a ztracené ruiny. Když hráči vykopou většinu pouště, přijde **písečná bouře**
a všechno znovu zasype – s novými poklady.

> Hra je **originální** (vlastní název, vzhled a herní prvky). Je inspirovaná
> žánrem „kopej a vylepšuj" z videa, ale nekopíruje cizí hru – to je důležité,
> aby ti ji Roblox nesmazal a abys ji mohl/a v klidu propagovat.

## Co hra obsahuje

| Funkce | Popis |
|---|---|
| ⛏️ Kopání do terénu | Skutečně deformovatelná poušť (Roblox Terrain), přesný výpočet vykopaného písku |
| 🛠️ 8 nástrojů | Holé ruce → lžíce → lopatka → lopata → vysavač → **Zlatá lopata (VIP)** → foukač → Titan bagr |
| 🎒 8 batohů | Od kapsy (30) po silo (600 000 písku) |
| 💰 Ekonomika | Prodej na zlaté ploše v táboře, rebirth (+50 % mincí navždy) |
| 🎁 Poklady | Truhly 5 rarit zakopané v různých hloubkách – hlouběji = vzácnější |
| 📜 Artefakty | 10 sběratelských artefaktů, každý dává trvalý bonus k mincím |
| 🏛️ Ztracené ruiny | Zasypaný chrám s mýtickou relikvií (oznámení celému serveru) |
| 🌪️ Písečná bouře | Server-wide event, znovu zasype poušť a přesune ruiny |
| 💎 6 gamepassů + 4 produkty | VIP, 2x Coins, Auto Sell, Treasure Radar, 3x Backpack, Fast Digger, balíčky mincí, Server Luck |
| 🎟️ Kódy | Pro TikTok/Instagram (`TIKTOK`, `INSTA`, …) |
| 👥 Skupina | Bonus +10 % pro členy tvé Roblox skupiny |
| 💾 Ukládání | DataStore se zámkem proti ztrátě dat, ochrana nákupů proti dvojímu připsání |
| 📱 Mobil/PC/konzole | UI se samo škáluje, kopání dotykem, myší i ovladačem |

## Rychlý start (5 minut)

1. Stáhni si **Roblox Studio**: <https://create.roblox.com>
2. Stáhni z tohoto repozitáře soubor **`DuneDiggers.rbxlx`**.
3. Otevři ho v Roblox Studiu (dvojklik nebo *File → Open from File*).
4. Zmáčkni **Play** (F5) a kopej 🎉

Celý podrobný návod (publikování, gamepassy, ukládání, nastavení hry):
👉 **[docs/NAVOD.md](docs/NAVOD.md)**

## Dokumentace

- 📘 [docs/NAVOD.md](docs/NAVOD.md) – krok za krokem od nuly po zveřejněnou hru
- 💎 [docs/GAMEPASSY.md](docs/GAMEPASSY.md) – gamepassy a produkty: texty, ceny, ikony, jak je vytvořit
- 📱 [docs/MARKETING.md](docs/MARKETING.md) – TikTok & Instagram: scénáře videí, plán na 30 dní, hashtagy
- 🎨 [marketing/README.md](marketing/README.md) – hotové grafiky: ikona, příspěvky na IG, story, thumbnail

## Struktura projektu

```
src/
  shared/              -> ReplicatedStorage/Shared
    Config.luau          ⭐ VŠECHNO NASTAVENÍ HRY (ceny, nástroje, gamepass ID, kódy)
    Remotes.luau         komunikace server <-> klient
    Util.luau            formátování čísel a času
  server/              -> ServerScriptService/Server
    Main.server.luau     spouští hru
    Services/
      WorldService       generování pouště, tábora, ruin + kopání do terénu
      DigService         ověření a zpracování kopání (proti hackům)
      TreasureService    truhly, artefakty, relikvie
      ShopService        prodej, obchod, rebirth, kódy, teleport
      MonetizationService gamepassy a developer produkty
      SandstormService   písečná bouře
      DataService        ukládání dat
      Stats              výpočty bonusů
      ToolFactory        modely nástrojů
  client/              -> StarterPlayer/StarterPlayerScripts/Client
    Main.client.luau     propojení UI, kopání a efektů
    UI.luau              celé uživatelské rozhraní
    DigController.luau   ovládání kopání
    Effects.luau         prach, čísla, bouře, zvuky
tools/build_place.py   sestaví DuneDiggers.rbxlx ze src/
tools/graphics/        generátor marketingových grafik (three.js)
marketing/graphics/    hotové grafiky pro Instagram/TikTok/Roblox
tests/                 automatické testy logiky mimo Roblox
default.project.json   pro Rojo (pokročilí)
```

## Pro pokročilé

- **Rojo**: `rojo serve` + Rojo plugin ve Studiu – kód pak upravuješ ve VS Code.
- **Nový place soubor** po úpravě kódu: `python3 tools/build_place.py`
- **Testy**: viz [tests/README.md](tests/README.md)
- **Lint**: `selene src` (konfigurace `selene.toml` + `roblox_lite.yml`), formát: `stylua src`
