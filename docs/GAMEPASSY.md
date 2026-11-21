# 💎 Gamepassy a developer produkty

Všechno je už **naprogramované** – stačí vytvořit passy/produkty na Robloxu
a vložit jejich ID do `ReplicatedStorage/Shared/Config`
(postup: [NAVOD.md → krok 6](NAVOD.md#6-gamepassy-a-developer-produkty)).

Texty jsou anglicky, protože většina hráčů Robloxu mluví anglicky
(Roblox je pak sám přeloží do dalších jazyků).

---

## Gamepassy (platí navždy)

| # | Pass | Doporučená cena | Co dělá ve hře | Klíč v Configu |
|---|---|---|---|---|
| 1 | 👑 **VIP** | **399 R$** | +25 % mincí, **Zlatá lopata** (exkluzivní nástroj), 👑 u jména, `[👑 VIP]` v chatu | `VIP` |
| 2 | 💰 **2x Coins** | **249 R$** | Každý prodej dává dvojnásobek mincí | `DoubleCoins` |
| 3 | ⚡ **Auto Sell** | **199 R$** | Plný batoh se prodá sám, kdekoliv – nemusíš běhat do tábora | `AutoSell` |
| 4 | 📡 **Treasure Radar** | **299 R$** | Vidíš zakopané truhly skrz písek + 1,5× mince z truhel | `TreasureRadar` |
| 5 | 🎒 **3x Backpack** | **149 R$** | Každý batoh unese 3× víc písku | `BigBackpack` |
| 6 | ⛏️ **Fast Digger** | **149 R$** | Kopeš o 50 % rychleji všemi nástroji | `FastDig` |

### Texty ke zkopírování

**VIP**
> Name: `VIP 👑`
> Description: `Become a VIP digger! +25% coins on everything, the exclusive GOLDEN SHOVEL, a crown next to your name and a VIP chat tag. Thank you for supporting the game!`

**2x Coins**
> Name: `2x Coins 💰`
> Description: `Double coins every time you sell your sand. Works forever and stacks with rebirths and artifacts!`

**Auto Sell**
> Name: `Auto Sell ⚡`
> Description: `Never walk back to camp again! Your sand is sold automatically the moment your bag is full – anywhere in the desert.`

**Treasure Radar**
> Name: `Treasure Radar 📡`
> Description: `See buried treasure chests glowing through the sand and get 1.5x coins from every chest you open!`

**3x Backpack**
> Name: `3x Backpack 🎒`
> Description: `Carry 3x more sand in every backpack. Dig longer, sell bigger!`

**Fast Digger**
> Name: `Fast Digger ⛏️`
> Description: `Dig 50% faster with every tool – from your bare hands to the Titan Excavator!`

---

## Developer produkty (dají se koupit opakovaně)

| Produkt | Cena | Co dá | Klíč v Configu |
|---|---|---|---|
| 🍀 **Server Luck x2 (15 min)** | **99 R$** | 15 minut 2× vyšší šance na vzácné truhly **pro celý server** + oznámení všem hráčům | `ServerLuck` |
| 💰 **Coin Pouch** | **49 R$** | 5 000 mincí × (rebirthy + 1) | `CoinsSmall` |
| 💰 **Coin Chest** | **179 R$** | 30 000 mincí × (rebirthy + 1) | `CoinsMedium` |
| 🏦 **Coin Vault** | **499 R$** | 150 000 mincí × (rebirthy + 1) | `CoinsLarge` |

> Mince se násobí počtem rebirthů, aby balíček dával smysl i pokročilým hráčům.

**Texty:**
- Server Luck: `Doubles the chance of rare chests for EVERYONE in the server for 15 minutes! Everyone will see that you activated it.`
- Coin Pouch: `A small pouch of coins. Gives more after every rebirth!`
- Coin Chest: `A chest full of coins. Gives more after every rebirth!`
- Coin Vault: `A whole vault of coins! Gives more after every rebirth!`

---

## Proč tyhle ceny?

- **Levný vstup (149 R$)** – 3x Backpack a Fast Digger jsou „první nákup“. Kdo jednou koupí, koupí častěji znovu.
- **Kotva (399 R$)** – VIP je nejdražší a nejviditelnější (korunka u jména, zlatá lopata). Ostatní passy pak vedle něj působí levně.
- **Auto Sell** řeší největší „otravnost“ hry (běhání do tábora) → bývá nejprodávanější.
- **Server Luck** je sociální – ostatní hráči vidí oznámení a jméno kupujícího. Lidé rádi kupují věci, které „vidí celý server“, a ostatním se to líbí.
- Ceny si můžeš kdykoliv změnit na Creator Hubu (*Sales*) – **kód se měnit nemusí**, hra si skutečnou cenu načte sama.

💡 **Tip:** Po prvních ~2 týdnech se podívej do *Creator Hub → Monetization → Analytics*, co se prodává, a ceny uprav. Pro developer produkty má Roblox i nástroj **Price Optimization**, který ceny automaticky testuje.

---

## Ikony (512×512)

Styl: jasné barvy, tlustý tmavý obrys, jedna věc uprostřed, žádný malý text.
Prompty pro AI generátor obrázků (např. v Canvě, Bing Image Creator…):

| Pass | Prompt |
|---|---|
| VIP | `cartoon game icon, shiny golden shovel with a royal crown on top, sparkles, desert sand background, bold dark outline, vibrant colors, roblox style, square` |
| 2x Coins | `cartoon game icon, big stack of gold coins with a huge "2X" in bold yellow letters, sparkles, bold outline, vibrant, roblox style, square` |
| Auto Sell | `cartoon game icon, sand bag turning into gold coins with a lightning bolt, motion lines, bold outline, vibrant, roblox style, square` |
| Treasure Radar | `cartoon game icon, green glowing radar screen showing a treasure chest buried under sand, bold outline, vibrant, roblox style, square` |
| 3x Backpack | `cartoon game icon, huge overflowing backpack full of sand with "3X" label, bold outline, vibrant, roblox style, square` |
| Fast Digger | `cartoon game icon, pickaxe-shovel with speed lines and fire, sand flying, bold outline, vibrant, roblox style, square` |
| Server Luck | `cartoon game icon, glowing four-leaf clover over a treasure chest, green sparkles, bold outline, vibrant, roblox style, square` |
| Coins | `cartoon game icon, open treasure chest overflowing with gold coins, bold outline, vibrant, roblox style, square` |

---

## Kolik to vydělá?

- Z každého prodeje dostaneš **cca 70 % Robuxů** (zbytek si nechává Roblox).
  Příklad: VIP za 399 R$ → cca **279 R$** pro tebe.
- Dostáváš i **Premium Payouts** – Roblox ti platí za čas, který ve hře stráví hráči s Roblox Premium.
- Robuxy jde vyměnit za skutečné peníze přes **DevEx**
  (podmínky: minimálně 30 000 vydělaných Robuxů, věk 13+, ověřený účet;
  kurz je zhruba 0,35–0,38 centu za 1 Robux – aktuální hodnotu ověř na stránce DevEx).

---

## Pravidla, na která pozor ⚠️

- **Nepiš nepravdivé popisy** („unlimited coins“, „free robux“) – Roblox to trestá.
- **Náhodné odměny:** truhly se platit nedají, ale Server Luck zvyšuje šanci na vzácné truhly. Proto hra ukazuje **šance na rarity** v okně 📜 INDEX – nech to tam.
- **Nevracej peníze mimo Roblox** a neprodávej věci za skutečné peníze mimo Roblox (např. přes PayPal) – je to proti pravidlům.
- Gamepass, který jednou prodáš, musí **dál fungovat**. Když ho zrušíš, dej hráčům náhradu.
