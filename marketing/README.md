# 🎨 Grafiky pro Instagram, TikTok a Roblox

Hotové grafiky jsou ve složce **[`graphics/`](graphics/)** a můžeš je rovnou nahrát.

- 👀 **[00_nahled_instagram.jpg](graphics/00_nahled_instagram.jpg)** – jak bude vypadat profil, příspěvek a story
- 🗂️ **[00_prehled.jpg](graphics/00_prehled.jpg)** – všechny grafiky na jednom obrázku

## Inspirace: co dělají velké Roblox hry na Instagramu

Úspěšné Roblox hry (velké simulátory a „tycoony“) mají na IG pár formátů,
které fungují pořád dokola. Tahle sada je používá, ale s vlastním obsahem:

| Formát | Proč funguje | Naše grafika |
|---|---|---|
| **3D render + obří komiksový nápis** | Na první pohled vypadá jako hra, čte se i na malém náhledu | všechny |
| **Teaser / „sneak peek“** | Tajemství = komentáře a sdílení („co to je?“) | 02 Teaser |
| **Progres / tier list** | Hráč vidí, kam se může dostat | 03 Nástroje |
| **Kódy** | Hlavní důvod, proč lidi účet sledují | 04 Kód |
| **Vzácnost („only 1%“)** | FOMO, lidi to chtějí najít | 05 Relikvie |
| **Event s odpočtem** | Lidé přijdou do hry v konkrétní čas | 06 Bouře |
| **„Který bys vybral?“** | Nejlevnější cesta k desítkám komentářů | 07 Anketa |
| **Jednotný styl a barvy** | Profil vypadá jako značka, ne jako náhodné screenshoty | celá sada |

Barvy značky: písková oranžová `#E7A24E`, zlatá `#FFC928`, tyrkysová `#47E6FF`
(tajemství a ruiny), mýtická růžová `#FF3C6A`, tmavě hnědé obrysy `#3D1D08`.
Písmo nadpisů je **Luckiest Guy**, ostatní texty **Fredoka** (obě zdarma na Google Fonts).

## Co je co a kdy to postnout

| Soubor | Formát | Kam | Kdy (viz plán v [docs/MARKETING.md](../docs/MARKETING.md#6-plán-na-30-dní)) |
|---|---|---|---|
| `01_roblox_ikona.png` | 1024×1024 | Ikona hry na Robloxu, profilovka IG/TikTok | hned |
| `02_post_teaser.jpg` | 1080×1350 (4:5) | IG příspěvek | týden před spuštěním |
| `03_post_nastroje.jpg` | 4:5 | IG příspěvek | před spuštěním (*„which tool should I add?“*) |
| `04_post_kod.jpg` | 4:5 | IG příspěvek + highlight „CODES“ | v den spuštění / s každým novým kódem |
| `05_post_relikvie.jpg` | 4:5 | IG příspěvek | 1. týden po spuštění |
| `06_post_bourka.jpg` | 4:5 | IG příspěvek + story | před eventem / updatem |
| `07_post_anketa.jpg` | 4:5 | IG příspěvek | kdykoliv, když potřebuješ komentáře |
| `08_story_out_now.jpg` | 1080×1920 (9:16) | IG/TikTok story – přidej **anketu** a **odkaz** (sticker) do volného místa dole | den spuštění |
| `09_thumbnail_16x9.jpg` | 1920×1080 | Thumbnail hry na Robloxu, YouTube | hned |

> 💡 Instagram teď v profilu ukazuje příspěvky ořízlé na **3:4**. Grafiky 4:5 mají
> důležité věci uprostřed, takže se nic podstatného neuřízne.

### Popisky k příspěvkům (zkopíruj)

- **Teaser:** `What's under the desert? 👀 Something ancient is buried deep below the dunes... Who digs it up first? 🏜️⛏️ #roblox #robloxgame #dunediggers`
- **Nástroje:** `From a rusty spoon to a TITAN EXCAVATOR 😳 Which one are you rocking? #roblox #robloxsimulator`
- **Kód:** `FREE CODE 🎁 Type TIKTOK in the CODES menu for +500 coins! ⏳ Limited time #roblox #robloxcodes`
- **Relikvie:** `Only 1% of diggers find the Heart of the Dunes 💎 Have you? #roblox #rare`
- **Bouře:** `🌪️ SANDSTORM INCOMING! The desert gets buried again... with NEW treasure. #roblox #event`
- **Anketa:** `1 or 2? 👇 Comment your pick! #roblox #wouldyourather`

## Úprava grafik (nový kód, jiný text)

Grafiky nejsou jen obrázky – generuje je kód ve složce [`tools/graphics/`](../tools/graphics/)
(3D scéna v three.js + texty, vyfocené prohlížečem). Takže můžeš třeba
vyrobit nový „FREE CODE“ příspěvek s jiným kódem:

1. Nainstaluj [Node.js](https://nodejs.org) (verze 18+).
2. V terminálu:
   ```bash
   cd tools/graphics
   npm install
   npx playwright install chromium
   ```
3. Uprav text v `scenes.js` (např. v sekci `4) KÓD` přepiš `TIKTOK` a `+500 COINS`).
4. Vyrenderuj:
   ```bash
   node render.js ../../marketing/graphics/raw code
   ```
   (bez `code` na konci se vyrenderují všechny grafiky; výsledky jsou ve `marketing/graphics/raw/`).

Bez programování to jde i v **Canvě**: nahraj grafiku jako pozadí, přidej text
písmem *Luckiest Guy* s tmavým obrysem.
