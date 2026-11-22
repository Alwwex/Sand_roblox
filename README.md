# 🏜️ Dune Diggers – Roblox hra

Vykopej celou poušť – začínáš s holýma rukama, končíš s obřím bagrem.
Prodávej písek, kupuj lepší nástroje, hledej zakopané truhly, artefakty
a ztracené ruiny. Když hráči vykopou většinu pouště, přijde **písečná bouře**
a všechno znovu zasype – s novými poklady.

> Hra je **originální** (vlastní název, vzhled a herní prvky). Je inspirovaná
> žánrem „kopej a vylepšuj" z videa, ale nekopíruje cizí hru – to je důležité,
> aby ti ji Roblox nesmazal a abys ji mohl/a v klidu propagovat.

## 🆕 Verze 1.3 – opravdové 3D modely

![Mazlíčci – hladké 3D modely](docs/preview/20_modely_mazlicci.jpg)

| | |
|---|---|
| ![Mazlíčci 2](docs/preview/21_modely_mazlicci2.jpg) | ![Vajíčka](docs/preview/22_modely_vajicka.jpg) |
| ![Nástroje](docs/preview/23_modely_nastroje.jpg) | ![Velké nástroje](docs/preview/24_modely_nastroje2.jpg) |

- ✨ Mazlíčci, vajíčka a nástroje jsou teď **hladké 3D meshe** (jako ve velkých Roblox hrách), ne modely z kostiček:
  tvary se slévají jako modelína, barvy jsou „namalované" na povrch (bříška, tvářičky, pusinky, pruhy).
- 📦 Všechno je v jednom souboru `assets/models/DuneDiggersModels.glb` – **jednou ho importuj** do Studia
  (2 minuty, návod v [NAVOD.md, krok 6.6](docs/NAVOD.md#66-hezké-3d-modely-import--2-minuty)).
- 🛟 Když modely importované nejsou, hra normálně jede se staršími modely z kostiček.
- 🛠️ Modely jsou popsané kódem (`tools/models/`) – dají se upravit a znovu vygenerovat.

## Verze 1.2 – vajíčka, mazlíčci a úkoly

| | |
|---|---|
| ![Mazlíčci a vajíčka](docs/preview/12_mazlicci.jpg) | ![Líhnutí](docs/preview/13_lihnuti.jpg) |
| ![Okno vajíček](docs/preview/14_vajicka.jpg) | ![Moji mazlíčci](docs/preview/15_moji_mazlicci.jpg) |
| ![Denní úkoly](docs/preview/16_ukoly.jpg) | ![Egg Hatchery v lobby](docs/preview/17_hatchery.jpg) |

- 🥚 **Vajíčka a mazlíčci**: 3 vajíčka (Sand, Oasis, Pharaoh), **12 roztomilých mazlíčků** v 5 raritách
  (až po mýtického **Sun Dragona** 🐉). Mazlíčci **chodí (nebo létají) za tebou** a dávají **bonus k mincím**.
  Líhnutí s animací (třesení, záblesk, konfety, „NEW!"), líhnutí po 1 nebo po 3, šance jsou vidět předem.
- 🐾 **Okno MY PETS**: nasazení/sundání, **EQUIP BEST**, mazání, 3 místa (VIP 4)
- 📋 **Denní úkoly**: každý den 3 nové (kopej, otevři truhly, prodej, vylíhni, vydělej) – obtížnost podle pokroku hráče
- 🏛️ **EGG HATCHERY** v lobby – 3 podstavce s točícími se vajíčky
- 🛠️ **Nové 3D modely nástrojů** (lžíce, lopatka, lopata, zlatá lopata, vysavač s hadicí, foukač s vrtulí, bagr se zuby),
  **NPC jsou skutečné Roblox avatary** (mávají), socha v oáze je zlatý avatar, truhly mají kování a drahokamy
- 🏪 **Sand Buyer** stojí za pultem a už nepřekáží na prodejní ploše
- 🏊 **Opravené plavání** v oáze (hlubší voda, schody, nižší okraj)
- 🎛️ Hlavní menu: tip už nepřekrývá tlačítka (vše se samo přizpůsobí výšce obrazovky)

![Nové modely nástrojů](docs/preview/18_nastroje.jpg)

## Verze 1.1

| | |
|---|---|
| ![Hlavní menu](docs/preview/03_menu.jpg) | ![HUD](docs/preview/04_hud.jpg) |
| ![Obchod s 3D náhledy](docs/preview/05_shop.jpg) | ![Store](docs/preview/06_store.jpg) |
| ![Žebříček](docs/preview/07_zebricek.jpg) | ![Lobby Oasis Town](docs/preview/01_lobby_shora.jpg) |

- 🏝️ **Nová velká lobby „Oasis Town"** (120×120): oáza s vodou a zlatou sochou, trh s obchodníky,
  prodejní pavilon, rebirth chrám, brány s rampami, VIP salonek, denní truhla, tabule „How to play"
- 🏆 **Globální žebříčky** (mince, písek, rebirthy) na tabulích v lobby i v UI + **socha hráče č. 1**
- 🎵 **Originální hudba a zvuky** – 3 hudební smyčky (lobby, poušť, bouře), vítr a 12 efektů
- ✨ **Úplně nové UI**: hlavní menu s průletem kamery, 3D tlačítka, animované mince,
  obchod s **otáčejícími se 3D náhledy nástrojů**, okna se rozmazaným pozadím, nastavení (hlasitost, low graphics)
- 🎁 **Denní odměny** a **VIP truhla**
- 🎒 **Vlastní výběr nástrojů** místo Roblox hotbaru: 3D náhledy, klávesy 1–9, LB/RB na ovladači,
  zamčený slot s cenou dalšího nástroje
- 🧱 **Opraveno „vidění skrz písek"** (po kopání se mažou tenké průsvitné zbytky terénu, kamera nesmí do zdí)
- 📸 Náhledy výše jsou vyrenderované přímo z kódu hry (viz `tests/preview_export.luau`) – ve hře to vypadá velmi podobně.

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
| 🏝️ Lobby Oasis Town | Velké město s obchody, NPC, oázou, VIP salonkem a žebříčky |
| 🏆 Žebříčky | Globální (OrderedDataStore) + socha nejlepšího hráče |
| 🎵 Hudba | Originální, mění se podle místa (lobby / poušť / bouře) |
| 🎁 Denní odměny | Denní truhla pro všechny, VIP truhla pro VIP |
| 🥚 Vajíčka & mazlíčci | 3 vajíčka, 12 mazlíčků, 5 rarit, bonus k mincím, mazlíčci chodí za hráčem |
| 📋 Denní úkoly | 3 úkoly denně s odměnou, obtížnost podle pokroku |
| 📱 Mobil/PC/konzole | UI se samo škáluje, kopání dotykem, myší i ovladačem |

## Rychlý start (5 minut)

1. Stáhni si **Roblox Studio**: <https://create.roblox.com>
2. Stáhni z tohoto repozitáře soubor **`DuneDiggers.rbxlx`**.
3. Otevři ho v Roblox Studiu (dvojklik nebo *File → Open from File*).
4. Zmáčkni **Play** (F5) a kopej 🎉
5. Pro hezké hladké 3D modely mazlíčků a nástrojů importuj jednou `assets/models/DuneDiggersModels.glb`
   (*File → Import 3D*, model přesuň do ReplicatedStorage a přejmenuj na `DuneMeshes` – [návod 6.6](docs/NAVOD.md#66-hezké-3d-modely-import--2-minuty)).

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
    Config.luau          ⭐ VŠECHNO NASTAVENÍ HRY (ceny, nástroje, gamepass ID, kódy, hudba)
    Remotes.luau         komunikace server <-> klient
    Util.luau            formátování čísel a času
    ToolFactory.luau     modely nástrojů (do ruky, do lobby i do náhledů v obchodě)
    PetFactory.luau      modely mazlíčků a vajíček
    MeshLibrary.luau     načítá hladké 3D modely (ReplicatedStorage > DuneMeshes)
  server/              -> ServerScriptService/Server
    Main.server.luau     spouští hru
    Services/
      WorldService       generování pouště a ruin + kopání do terénu
      LobbyBuilder       lobby Oasis Town (stavby, NPC, oáza, VIP salonek…)
      Build              pomocné funkce pro stavění z partů
      LeaderboardService globální žebříčky + socha hráče č. 1
      RewardService      denní odměny, VIP salonek, gamepass stánky
      PetService         vajíčka, líhnutí, mazlíčci
      QuestService       denní úkoly
      DigService         ověření a zpracování kopání (proti hackům)
      TreasureService    truhly, artefakty, relikvie
      ShopService        prodej, obchod, rebirth, kódy, teleport
      MonetizationService gamepassy a developer produkty
      SandstormService   písečná bouře
      DataService        ukládání dat
      Stats              výpočty bonusů
  client/              -> StarterPlayer/StarterPlayerScripts/Client
    Main.client.luau     hlavní menu -> hra, propojení všeho
    UI.luau              vstup do UI (HUD + okna + menu)
    UIKit.luau           stavebnice UI (3D tlačítka, panely, posuvníky…)
    Hud.luau             mince, menu, banner pouště, batoh, notifikace
    Hotbar.luau          vlastní výběr nástrojů (místo Roblox hotbaru)
    Windows.luau         okna: Shop, Store, Rebirth, Index, Codes, Top, Settings, Egg, Pets, Quests
    HatchFx.luau         animace líhnutí vajíčka
    PetFollow.luau       mazlíčci chodí za hráči
    MainMenu.luau        úvodní obrazovka s průletem kamery
    Audio.luau           hudba, ambience, zvukové efekty
    DigController.luau   ovládání kopání
    Effects.luau         prach, čísla, bouře, třesení kamery
assets/audio/          originální hudba a zvuky (nahraj na Roblox, viz návod 6.5)
assets/models/         hladké 3D modely (.glb) – importuj do Studia, viz návod 6.6
tools/models/          generátor 3D modelů (Python, SDF "modelína")
tools/build_place.py   sestaví DuneDiggers.rbxlx ze src/
tools/audio/           generátor hudby a zvuků (Python)
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
