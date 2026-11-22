--[[
	DUNE DIGGERS – hlavní konfigurace hry
	=====================================
	Tady upravuješ skoro všechno: ceny, nástroje, batohy, gamepassy, kódy...
	Po změně stačí hru znovu spustit (Play) nebo publikovat.

	!!! DŮLEŽITÉ !!!
	Až vytvoříš gamepassy a developer produkty na create.roblox.com,
	vlož jejich ID do sekcí GamePasses a Products níže (místo 0).
	Návod: docs/NAVOD.md a docs/GAMEPASSY.md
]]

local Config = {}

Config.GameName = "Dune Diggers"
Config.Version = "1.2"
Config.Changelog = {
	"🏝️ NEW lobby: Oasis Town",
	"🏆 Global leaderboards + #1 statue",
	"🎵 Original music & sounds",
	"🎁 Daily rewards & VIP lounge",
	"✨ Brand new UI & main menu",
	"🎒 Custom item selector (keys 1-9)",
	"🥚 NEW: Eggs & pets that follow you!",
	"📋 NEW: Daily quests",
	"🏊 Fixed swimming in the oasis",
	"🧱 Fixed see-through sand",
}

---------------------------------------------------------------------
-- SVĚT (poušť)
---------------------------------------------------------------------
Config.World = {
	Size = 640, -- velikost pouště (čtverec, ve studs). Musí být dělitelné 64.
	BaseSandHeight = 26, -- průměrná hloubka písku
	DuneHeight = 18, -- jak vysoké jsou duny
	DuneScale = 150, -- jak široké jsou duny (větší = širší a plynulejší)
	MinSand = 6, -- minimální hloubka písku
	MaxSand = 60, -- maximální hloubka písku (max 64)

	CampHalf = 60, -- polovina šířky lobby (Oasis Town) uprostřed mapy
	CampTop = 30, -- výška lobby (horní plocha)

	RuinsRadius = 22, -- velikost zasypaných ruin
	RuinsBuryHeight = 24, -- jak hluboko jsou ruiny zasypané (výška písku nad nimi)
	RuinsMinDistance = 150, -- vzdálenost ruin od středu
	RuinsMaxDistance = 240,
}

-- Kolik "písku" dostaneš za 1 plný voxel terénu (4x4x4 studs)
Config.SandPerVoxel = 10

---------------------------------------------------------------------
-- EKONOMIKA
---------------------------------------------------------------------
Config.Economy = {
	CoinsPerSand = 1, -- kolik mincí za 1 písek při prodeji
	StartingCoins = 0,
}

Config.Rebirth = {
	BaseCost = 250000, -- cena prvního rebirthu
	CostGrowth = 2.5, -- každý další rebirth je X-krát dražší
	MultiplierPerRebirth = 0.5, -- +50 % mincí za každý rebirth
}

Config.CampTeleportCooldown = 10 -- sekundy mezi teleporty do lobby
Config.RespawnTime = 3

-- Kamera (nedovolí kameře zajet do písku/zdí)
Config.Camera = {
	MaxZoom = 70,
	MinZoom = 0.5,
}

---------------------------------------------------------------------
-- DENNÍ ODMĚNY
---------------------------------------------------------------------
Config.Daily = {
	Coins = 400, -- denní truhla v lobby (× počet rebirthů + 1)
	VipCoins = 2500, -- VIP truhla ve VIP salonku (× počet rebirthů + 1)
	CooldownHours = 20, -- jak často jde odměnu vybrat
}

---------------------------------------------------------------------
-- ŽEBŘÍČKY (globální, přes všechny servery)
---------------------------------------------------------------------
Config.Leaderboard = {
	RefreshSeconds = 90, -- jak často se tabule obnovují
	Size = 10, -- kolik hráčů se zobrazuje
	Version = "v1", -- změnou se žebříčky vynulují
}

---------------------------------------------------------------------
-- NÁSTROJE
-- Radius = jak velkou díru udělá, Cooldown = sekundy mezi kopnutími,
-- Reach = jak daleko dosáhne. Pass = nástroj jen pro majitele gamepassu.
---------------------------------------------------------------------
Config.Tools = {
	{
		Id = "Hands",
		Icon = "✋",
		Name = "Bare Hands",
		Price = 0,
		Radius = 2.6,
		Cooldown = 0.45,
		Reach = 10,
		Swing = true,
	},
	{
		Id = "Spoon",
		Icon = "🥄",
		Name = "Rusty Spoon",
		Price = 40,
		Radius = 3.0,
		Cooldown = 0.4,
		Reach = 11,
		Swing = true,
	},
	{
		Id = "Trowel",
		Icon = "🔨",
		Name = "Garden Trowel",
		Price = 300,
		Radius = 3.5,
		Cooldown = 0.4,
		Reach = 12,
		Swing = true,
	},
	{
		Id = "Shovel",
		Icon = "⛏️",
		Name = "Big Shovel",
		Price = 1500,
		Radius = 4.2,
		Cooldown = 0.38,
		Reach = 14,
		Swing = true,
	},
	{
		Id = "Vacuum",
		Icon = "🌀",
		Name = "Sand Vacuum",
		Price = 9000,
		Radius = 4.6,
		Cooldown = 0.15,
		Reach = 18,
		Swing = false,
	},
	{
		Id = "GoldenShovel",
		Icon = "👑",
		Name = "Golden Shovel",
		Price = 0,
		Pass = "VIP",
		Radius = 5.2,
		Cooldown = 0.3,
		Reach = 20,
		Swing = true,
	},
	{
		Id = "Blaster",
		Icon = "💨",
		Name = "Dune Blaster",
		Price = 50000,
		Radius = 6.2,
		Cooldown = 0.2,
		Reach = 24,
		Swing = false,
	},
	{
		Id = "Excavator",
		Icon = "🚜",
		Name = "Titan Excavator",
		Price = 350000,
		Radius = 9.5,
		Cooldown = 0.35,
		Reach = 32,
		Swing = true,
	},
}

---------------------------------------------------------------------
-- BATOHY (kolik písku uneseš)
---------------------------------------------------------------------
Config.Backpacks = {
	{ Id = "Pocket", Icon = "👖", Name = "Pocket", Price = 0, Capacity = 30 },
	{ Id = "Bucket", Icon = "🪣", Name = "Bucket", Price = 75, Capacity = 150 },
	{ Id = "Sack", Icon = "💼", Name = "Sand Sack", Price = 450, Capacity = 600 },
	{ Id = "Wheelbarrow", Icon = "🛒", Name = "Wheelbarrow", Price = 2500, Capacity = 2500 },
	{ Id = "Crate", Icon = "📦", Name = "Cargo Crate", Price = 14000, Capacity = 10000 },
	{ Id = "Cart", Icon = "🚃", Name = "Mine Cart", Price = 70000, Capacity = 40000 },
	{ Id = "Container", Icon = "🚛", Name = "Container", Price = 300000, Capacity = 150000 },
	{ Id = "Silo", Icon = "🏭", Name = "Sand Silo", Price = 1500000, Capacity = 600000 },
}

---------------------------------------------------------------------
-- POKLADY
---------------------------------------------------------------------
Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(176, 122, 74), Coins = 60, ArtifactChance = 0.15, Weight = 60 },
	Rare = { Order = 2, Color = Color3.fromRGB(70, 160, 255), Coins = 300, ArtifactChance = 0.3, Weight = 26 },
	Epic = { Order = 3, Color = Color3.fromRGB(175, 85, 255), Coins = 1500, ArtifactChance = 0.45, Weight = 10 },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 196, 40), Coins = 8000, ArtifactChance = 0.7, Weight = 4 },
	Mythic = { Order = 5, Color = Color3.fromRGB(255, 60, 90), Coins = 40000, ArtifactChance = 1, Weight = 0 },
}
Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

Config.Treasure = {
	StartChests = 45, -- kolik truhel je zakopaných na začátku
	MaxChests = 60, -- maximum truhel najednou
	RespawnInterval = 15, -- každých X sekund přibude nová truhla (pokud je jich málo)
	DepthLuck = 2.5, -- hlubší truhly = lepší šance na vzácné
	ExposeThreshold = 0.3, -- jak moc musí být truhla odkrytá, aby šla otevřít
	ToolTierBonus = 0.5, -- lepší nástroj = víc mincí z truhel
}

-- Artefakty: každý unikátní artefakt dává NAVŽDY bonus k mincím (Bonus = 0.05 => +5 %)
Config.Artifacts = {
	{ Id = "AncientCoin", Name = "Ancient Coin", Rarity = "Common", Bonus = 0.02, Icon = "🪙" },
	{ Id = "PotteryShard", Name = "Pottery Shard", Rarity = "Common", Bonus = 0.02, Icon = "🏺" },
	{ Id = "CamelBell", Name = "Camel Bell", Rarity = "Common", Bonus = 0.02, Icon = "🔔" },
	{ Id = "BronzeBeetle", Name = "Bronze Beetle", Rarity = "Rare", Bonus = 0.05, Icon = "🐞" },
	{ Id = "FossilTooth", Name = "Fossil Tooth", Rarity = "Rare", Bonus = 0.05, Icon = "🦷" },
	{ Id = "DesertRose", Name = "Desert Rose", Rarity = "Epic", Bonus = 0.1, Icon = "🌹" },
	{ Id = "OasisCompass", Name = "Oasis Compass", Rarity = "Epic", Bonus = 0.1, Icon = "🧭" },
	{ Id = "SunStone", Name = "Sun Stone", Rarity = "Legendary", Bonus = 0.25, Icon = "☀️" },
	{ Id = "GoldenMask", Name = "Golden Mask", Rarity = "Legendary", Bonus = 0.25, Icon = "🎭" },
	{ Id = "HeartOfDunes", Name = "Heart of the Dunes", Rarity = "Mythic", Bonus = 1, Icon = "💎" },
}

---------------------------------------------------------------------
-- MAZLÍČCI A VAJÍČKA (Hatchery v lobby)
-- Coins = bonus k mincím (0.1 = +10 %). Mazlíčci chodí za hráčem.
---------------------------------------------------------------------
Config.Pets = {
	{ Id = "SandBunny", Name = "Sand Bunny", Rarity = "Common", Coins = 0.05 },
	{ Id = "DesertMouse", Name = "Desert Mouse", Rarity = "Common", Coins = 0.06 },
	{ Id = "ScarabBug", Name = "Scarab Bug", Rarity = "Rare", Coins = 0.12 },
	{ Id = "FennecFox", Name = "Fennec Fox", Rarity = "Epic", Coins = 0.25 },
	{ Id = "LilyFrog", Name = "Lily Frog", Rarity = "Common", Coins = 0.1 },
	{ Id = "OasisTurtle", Name = "Oasis Turtle", Rarity = "Rare", Coins = 0.2 },
	{ Id = "PalmParrot", Name = "Palm Parrot", Rarity = "Epic", Coins = 0.4 },
	{ Id = "WaterSpirit", Name = "Water Spirit", Rarity = "Legendary", Coins = 0.8 },
	{ Id = "MummyCat", Name = "Mummy Cat", Rarity = "Rare", Coins = 0.5 },
	{ Id = "GoldenScarab", Name = "Golden Scarab", Rarity = "Epic", Coins = 0.9 },
	{ Id = "SphinxCat", Name = "Sphinx Cat", Rarity = "Legendary", Coins = 1.6 },
	{ Id = "SunDragon", Name = "Sun Dragon", Rarity = "Mythic", Coins = 4 },
}

-- Pets = { {Id mazlíčka, váha}, ... } – šance se v UI zobrazují v %
Config.Eggs = {
	{
		Id = "SandEgg",
		Name = "Sand Egg",
		Price = 400,
		Pets = { { "SandBunny", 45 }, { "DesertMouse", 35 }, { "ScarabBug", 17 }, { "FennecFox", 3 } },
	},
	{
		Id = "OasisEgg",
		Name = "Oasis Egg",
		Price = 15000,
		Pets = { { "LilyFrog", 45 }, { "OasisTurtle", 35 }, { "PalmParrot", 17 }, { "WaterSpirit", 3 } },
	},
	{
		Id = "PharaohEgg",
		Name = "Pharaoh Egg",
		Price = 300000,
		Pets = { { "MummyCat", 50 }, { "GoldenScarab", 33 }, { "SphinxCat", 15 }, { "SunDragon", 2 } },
	},
}

Config.PetSlots = 3 -- kolik mazlíčků může chodit s hráčem (VIP +1)
Config.MaxPets = 60 -- maximum v inventáři

---------------------------------------------------------------------
-- DENNÍ ÚKOLY (3 náhodné každý den)
-- Targets = cíl podle pokroku hráče (začátečník / střední / pokročilý)
---------------------------------------------------------------------
Config.Quests = {
	{ Id = "Dig", Text = "Dig %s sand", Icon = "⛏️", Targets = { 300, 3000, 30000 }, Reward = 250 },
	{ Id = "Chests", Text = "Open %s chests", Icon = "🎁", Targets = { 2, 4, 6 }, Reward = 400 },
	{ Id = "Sell", Text = "Sell sand %s times", Icon = "💰", Targets = { 3, 6, 10 }, Reward = 200 },
	{ Id = "Hatch", Text = "Hatch %s eggs", Icon = "🥚", Targets = { 1, 3, 5 }, Reward = 350 },
	{ Id = "Coins", Text = "Earn %s coins", Icon = "🪙", Targets = { 1500, 20000, 200000 }, Reward = 500 },
}

---------------------------------------------------------------------
-- PÍSEČNÁ BOUŘE (znovu zasype poušť)
---------------------------------------------------------------------
Config.Sandstorm = {
	Interval = 30 * 60, -- bouře přijde nejpozději po X sekundách
	ClearedThreshold = 0.75, -- ...nebo když hráči vykopou 75 % pouště
	WarningTime = 20, -- varování před bouří (sekundy)
	MinStormTime = 10, -- jak dlouho bouře minimálně trvá
}

---------------------------------------------------------------------
-- GAMEPASSY  (Id = číslo z create.roblox.com, Price = jen orientační)
---------------------------------------------------------------------
Config.GamePasses = {
	VIP = {
		Id = 0,
		Name = "VIP",
		Price = 399,
		Icon = "👑",
		Description = "+25% coins, Golden Shovel, VIP chat tag & golden name",
	},
	DoubleCoins = {
		Id = 0,
		Name = "2x Coins",
		Price = 249,
		Icon = "💰",
		Description = "Every sale gives you double coins. Forever.",
	},
	AutoSell = {
		Id = 0,
		Name = "Auto Sell",
		Price = 199,
		Icon = "⚡",
		Description = "Sells your sand automatically when your bag is full. No walking!",
	},
	BigBackpack = {
		Id = 0,
		Name = "3x Backpack",
		Price = 149,
		Icon = "🎒",
		Description = "Carry 3x more sand in every backpack.",
	},
	FastDig = {
		Id = 0,
		Name = "Fast Digger",
		Price = 149,
		Icon = "⛏️",
		Description = "Dig 50% faster with every tool.",
	},
	TreasureRadar = {
		Id = 0,
		Name = "Treasure Radar",
		Price = 299,
		Icon = "📡",
		Description = "See buried chests through the sand + 1.5x chest coins.",
	},
}
-- Pořadí v obchodě
Config.GamePassOrder = { "VIP", "DoubleCoins", "AutoSell", "TreasureRadar", "BigBackpack", "FastDig" }

Config.VIP = { CoinBonus = 1.25 }
Config.PassEffects = {
	DoubleCoins = 2,
	BigBackpack = 3,
	FastDig = 1.5,
	TreasureRadarCoins = 1.5,
}

---------------------------------------------------------------------
-- DEVELOPER PRODUKTY (dají se koupit opakovaně)
-- Coins se násobí (počet rebirthů + 1), aby balíčky měly smysl i později.
---------------------------------------------------------------------
Config.Products = {
	CoinsSmall = { Id = 0, Name = "Coin Pouch", Price = 49, Icon = "💰", Coins = 5000 },
	CoinsMedium = { Id = 0, Name = "Coin Chest", Price = 179, Icon = "💰", Coins = 30000 },
	CoinsLarge = { Id = 0, Name = "Coin Vault", Price = 499, Icon = "🏦", Coins = 150000 },
	ServerLuck = { Id = 0, Name = "Server Luck x2 (15 min)", Price = 99, Icon = "🍀", LuckMinutes = 15 },
}
Config.ProductOrder = { "ServerLuck", "CoinsSmall", "CoinsMedium", "CoinsLarge" }

---------------------------------------------------------------------
-- ROBLOX SKUPINA (bonus za členství – skvělé pro marketing)
---------------------------------------------------------------------
Config.Group = {
	Id = 0, -- ID tvé Roblox skupiny (0 = vypnuto)
	CoinBonus = 0.1, -- +10 % mincí pro členy skupiny
}

---------------------------------------------------------------------
-- KÓDY (dávej je do TikTok/Instagram videí!)
-- Psaní velkými/malými písmeny nevadí.
---------------------------------------------------------------------
Config.Codes = {
	RELEASE = { Coins = 250 },
	TIKTOK = { Coins = 500 },
	INSTA = { Coins = 500 },
	DIGDEEP = { Coins = 1000 },
}

---------------------------------------------------------------------
-- HUDBA A ZVUKY
-- Originální hudba a zvuky jsou ve složce assets/audio/ v projektu.
-- Nahraj je na Roblox (create.roblox.com > Development Items > Audio)
-- a vlož sem jejich ID ve tvaru "rbxassetid://123456789".
-- Návod: docs/NAVOD.md, sekce "Hudba a zvuky".
---------------------------------------------------------------------
Config.Music = {
	Lobby = "", -- assets/audio/music_oasis.ogg   (menu a lobby)
	Desert = "", -- assets/audio/music_desert.ogg (kopání v poušti)
	Storm = "", -- assets/audio/music_storm.ogg   (písečná bouře)
	Ambience = "", -- assets/audio/ambience_wind.ogg (vítr v poušti)
	Volume = 0.5,
}

-- Všechny zvukové efekty jsou v JEDNOM souboru assets/audio/sfx_pack.ogg
-- (stačí jedno nahrání). Tady jsou jejich časy v sekundách – neměnit.
Config.SfxPack = ""
Config.SfxRegions = {
	Dig = { 0.0, 0.32 },
	Dig2 = { 0.5, 0.82 },
	Coin = { 1.0, 1.35 },
	Sell = { 1.5, 2.4 },
	Click = { 2.5, 2.62 },
	Open = { 3.0, 3.25 },
	Error = { 3.5, 3.85 },
	Chest = { 4.0, 5.2 },
	Rare = { 5.5, 7.0 },
	Rebirth = { 7.5, 9.3 },
	Storm = { 9.5, 11.5 },
	Buy = { 12.0, 12.7 },
}

-- Záložní zvuky (vestavěné v Robloxu), když SfxPack ještě není nahraný
Config.Sounds = {
	Dig = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Chest = "rbxasset://sounds/electronicpingshort.wav",
}

---------------------------------------------------------------------
-- TESTOVÁNÍ
---------------------------------------------------------------------
Config.Testing = {
	GiveAllPassesInStudio = false, -- true = ve Studiu máš všechny gamepassy (na testování)
	StudioStartCoins = 0, -- kolik mincí dostaneš ve Studiu na začátku (např. 1000000 na testování)
}

---------------------------------------------------------------------
-- Pomocné tabulky (neupravovat)
---------------------------------------------------------------------
Config.ToolsById = {}
for index, tool in Config.Tools do
	tool.Index = index
	Config.ToolsById[tool.Id] = tool
end

Config.BackpacksById = {}
for index, backpack in Config.Backpacks do
	backpack.Index = index
	Config.BackpacksById[backpack.Id] = backpack
end

Config.PetsById = {}
for index, pet in Config.Pets do
	pet.Index = index
	Config.PetsById[pet.Id] = pet
end

Config.EggsById = {}
for index, egg in Config.Eggs do
	egg.Index = index
	Config.EggsById[egg.Id] = egg
end

Config.QuestsById = {}
for _, quest in Config.Quests do
	Config.QuestsById[quest.Id] = quest
end

Config.ArtifactsById = {}
for index, artifact in Config.Artifacts do
	artifact.Index = index
	Config.ArtifactsById[artifact.Id] = artifact
end

return Config
