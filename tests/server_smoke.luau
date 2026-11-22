--!nocheck
-- Smoke test serverové logiky (spouští tests/run_tests.py).
-- Proměnné mock, tree, runMain doplní runner.

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
		print("  ✔ " .. name)
	else
		failed += 1
		print("  ✘ " .. name .. (if detail then (" (" .. tostring(detail) .. ")") else ""))
	end
end

-- Hráč je na serveru ještě před startem (jako ve Studiu)
local player = mock.newPlayer(101, "Tester")

print("== Start serveru ==")
runMain()
mock.advance(3)

local Config = require(tree.Shared.Config)
local Util = require(tree.Shared.Util)
local Remotes = require(tree.Shared.Remotes)
local DataService = require(tree.Services.DataService)
local WorldService = require(tree.Services.WorldService)
local TreasureService = require(tree.Services.TreasureService)
local SandstormService = require(tree.Services.SandstormService)

print("== Util ==")
check("formatNumber 0", Util.formatNumber(0) == "0", Util.formatNumber(0))
check("formatNumber 999", Util.formatNumber(999) == "999", Util.formatNumber(999))
check("formatNumber 12345", Util.formatNumber(12345) == "12,345", Util.formatNumber(12345))
check("formatNumber 150000", Util.formatNumber(150000) == "150K", Util.formatNumber(150000))
check("formatNumber 1520000", Util.formatNumber(1520000) == "1.52M", Util.formatNumber(1520000))
check("formatNumber 1000000", Util.formatNumber(1000000) == "1M", Util.formatNumber(1000000))
check("formatNumber -1234", Util.formatNumber(-1234) == "-1,234", Util.formatNumber(-1234))
check("formatTime 125", Util.formatTime(125) == "2:05", Util.formatTime(125))

print("== Svět ==")
check("svět je připravený", WorldService.isReady())
local cleared0 = WorldService.getClearedFraction()
check("poušť je na začátku plná", cleared0 == 0, cleared0)
local voxelCount = 0
for _ in mock.voxels do
	voxelCount += 1
end
check("terén má voxely", voxelCount > 100000, voxelCount)
local minH, maxH = math.huge, -math.huge
for x = -250, 250, 10 do
	for z = -250, 250, 10 do
		local h = WorldService.heightAt(x, z)
		minH = math.min(minH, h)
		maxH = math.max(maxH, h)
	end
end
check("výšky dun v rozsahu", minH >= Config.World.MinSand and maxH <= Config.World.MaxSand, minH .. ".." .. maxH)
print(("     (výška písku %.1f – %.1f)"):format(minH, maxH))

local treasures = workspace:FindFirstChild("Treasures")
local chestCount = #treasures:GetChildren()
check("truhly jsou zakopané", chestCount >= Config.Treasure.StartChests, chestCount)

print("== Hráč ==")
local session = DataService.get(player)
check("data hráče načtena", session ~= nil)
check("hráč má postavu", player.Character ~= nil)
local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
check("hráč drží Bare Hands", held and held:GetAttribute("DigToolId") == "Hands", held)

print("== Lobby ==")
local lobby = WorldService.Lobby
check("lobby postavena", lobby ~= nil and lobby.SellPad ~= nil and #lobby.Spawns == 4)
check("voda v oáze", (mock.waterFilled or 0) >= 1)
check("žebříčkové tabule", lobby.Boards and lobby.Boards.Coins ~= nil and lobby.Boards.Rebirths ~= nil)
check("gamepass stánky", lobby.PassStands and lobby.PassStands.VIP ~= nil)
local partCount = 0
for _, d in lobby.Model:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
check("počet partů v lobby rozumný", partCount > 300 and partCount < 2500, partCount)
print(("     (lobby má %d partů)"):format(partCount))

print("== Kopání ==")
local root = player.Character.HumanoidRootPart
local digSpot = Vector3.new(0, WorldService.heightAt(0, 90), 90)
root.Position = digSpot + Vector3.new(0, 3, 0)
Remotes.Dig.OnServerEvent:Fire(player, digSpot)
check("kopnutí přidalo písek", session.Data.Sand > 0, session.Data.Sand)
local afterFirst = session.Data.Sand
Remotes.Dig.OnServerEvent:Fire(player, digSpot)
check("cooldown blokuje spam", session.Data.Sand == afterFirst, session.Data.Sand)
mock.advance(0.5)
Remotes.Dig.OnServerEvent:Fire(player, digSpot + Vector3.new(2, 0, 0))
check("po cooldownu se kope dál", session.Data.Sand > afterFirst, session.Data.Sand)
check("vykopaná poušť > 0 %", WorldService.getClearedFraction() > 0)
Remotes.Dig.OnServerEvent:Fire(player, Vector3.new(200, 20, 200))
mock.advance(0.5)
local beforeFar = session.Data.Sand
Remotes.Dig.OnServerEvent:Fire(player, Vector3.new(200, 20, 200))
check("moc daleko = nekope", session.Data.Sand == beforeFar)
Remotes.Dig.OnServerEvent:Fire(player, "hack")
Remotes.Dig.OnServerEvent:Fire(player, Vector3.new(0 / 0, 0, 0))
check("nesmyslný vstup nespadne", true)
mock.advance(0.5)
local beforeLobby = session.Data.Sand
root.Position = Vector3.new(0, 34, 20)
Remotes.Dig.OnServerEvent:Fire(player, Vector3.new(0, 30, 24))
check("v lobby se nekope", session.Data.Sand == beforeLobby)
root.Position = digSpot + Vector3.new(0, 3, 0)

-- naplnit batoh
for i = 1, 40 do
	mock.advance(0.5)
	Remotes.Dig.OnServerEvent:Fire(player, digSpot + Vector3.new((i % 5) * 2, -(i // 5), 0))
end
check("batoh nepřeteče", session.Data.Sand <= 30, session.Data.Sand)
check("batoh je plný", session.Data.Sand == 30, session.Data.Sand)

print("== Prodej ==")
local sellPad = WorldService.SellPad
local coinsBefore = session.Data.Coins
sellPad.Touched:Fire(root)
check("prodej dal mince", session.Data.Coins == coinsBefore + 30, session.Data.Coins)
check("batoh je prázdný", session.Data.Sand == 0)

print("== Obchod ==")
local ok, msg = Remotes.BuyItem.OnServerInvoke(player, "Tool", "Excavator")
check("nelze koupit bez peněz", not ok, msg)
session.Data.Coins = 10000000
ok, msg = Remotes.BuyItem.OnServerInvoke(player, "Tool", "Spoon")
check("koupě Spoon", ok, msg)
held = player.Character:FindFirstChildOfClass("Tool")
check("drží Spoon", held and held:GetAttribute("DigToolId") == "Spoon")
ok = Remotes.BuyItem.OnServerInvoke(player, "Tool", "GoldenShovel")
check("VIP nástroj nejde koupit za mince", not ok)
ok = Remotes.BuyItem.OnServerInvoke(player, "Backpack", "Silo")
check("koupě Silo", ok)
ok = Remotes.BuyItem.OnServerInvoke(player, "Tool", "Excavator")
check("koupě Excavator", ok)
ok = Remotes.EquipItem.OnServerInvoke(player, "Tool", "Spoon")
check("equip Spoon", ok and session.Data.EquippedTool == "Spoon")
ok = Remotes.EquipItem.OnServerInvoke(player, "Tool", "Excavator")
check("equip Excavator", ok and session.Data.EquippedTool == "Excavator")
ok = Remotes.EquipItem.OnServerInvoke(player, "Tool", "Blaster")
check("nevlastněný nástroj nejde nasadit", not ok)

print("== Kódy ==")
local coins = session.Data.Coins
ok, msg = Remotes.RedeemCode.OnServerInvoke(player, " tikTok ")
check("kód TIKTOK", ok and session.Data.Coins == coins + 500, msg)
ok = Remotes.RedeemCode.OnServerInvoke(player, "TIKTOK")
check("kód jen jednou", not ok)
ok = Remotes.RedeemCode.OnServerInvoke(player, "NEEXISTUJE")
check("neplatný kód", not ok)

print("== Poklady ==")
local targetChest, targetInfo
for _, chest in treasures:GetChildren() do
	if not chest:GetAttribute("IsRelic") then
		targetChest = chest
		break
	end
end
local chestPos = targetChest.PrimaryPart.Position
root.Position = chestPos + Vector3.new(0, 2, 0)
for i = 1, 30 do
	mock.advance(0.5)
	Remotes.Dig.OnServerEvent:Fire(player, chestPos + Vector3.new(0, 4 + (30 - i) * 0.5, 0))
	if targetChest:GetAttribute("Exposed") then
		break
	end
end
check("truhla se odkryla kopáním", targetChest:GetAttribute("Exposed") == true)
local prompt = targetChest.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
check("prompt je aktivní", prompt and prompt.Enabled == true)
coins = session.Data.Coins
prompt.Triggered:Fire(player)
check("truhla dala mince", session.Data.Coins > coins, session.Data.Coins - coins)
check("počítadlo truhel", session.Data.ChestsOpened == 1)
local before2 = session.Data.Coins
prompt.Triggered:Fire(player)
check("truhla nejde otevřít 2x", session.Data.Coins == before2)
mock.advance(5)
check("otevřená truhla zmizí", targetChest.Parent == nil)

-- artefakty: otevřít hodně truhel naráz
local function openRelic()
	local ruinsCenter, relicCFrame = WorldService.getRuins()
	for _, chest in treasures:GetChildren() do
		if chest:GetAttribute("IsRelic") then
			return chest, relicCFrame
		end
	end
end
local relic = openRelic()
check("relikvie v ruinách existuje", relic ~= nil)

print("== Gamepassy & produkty ==")
local Marketplace = mock.services.MarketplaceService
Config.GamePasses.VIP.Id = 123
Config.GamePasses.AutoSell.Id = 124
Remotes.EquipItem.OnServerInvoke(player, "Tool", "Spoon")
Marketplace.PromptGamePassPurchaseFinished:Fire(player, 123, true)
check("VIP aktivní", session.Passes.VIP == true)
check("VIP dostal Golden Shovel", session.Data.EquippedTool == "GoldenShovel", session.Data.EquippedTool)
ok = Remotes.EquipItem.OnServerInvoke(player, "Tool", "GoldenShovel")
check("Golden Shovel jde nasadit", ok)
Marketplace.PromptGamePassPurchaseFinished:Fire(player, 124, true)
check("AutoSell aktivní", session.Passes.AutoSell == true)

Config.Products.CoinsSmall.Id = 555
coins = session.Data.Coins
local decision = Marketplace.ProcessReceipt({ PlayerId = 101, ProductId = 555, PurchaseId = "p1" })
check("produkt připsán", decision == Enum.ProductPurchaseDecision.PurchaseGranted and session.Data.Coins > coins)
local coins2 = session.Data.Coins
decision = Marketplace.ProcessReceipt({ PlayerId = 101, ProductId = 555, PurchaseId = "p1" })
check(
	"stejná účtenka se nepřipíše 2x",
	decision == Enum.ProductPurchaseDecision.PurchaseGranted and session.Data.Coins == coins2
)
decision = Marketplace.ProcessReceipt({ PlayerId = 999, ProductId = 555, PurchaseId = "p2" })
check("neznámý hráč = NotProcessedYet", decision == Enum.ProductPurchaseDecision.NotProcessedYet)
Config.Products.ServerLuck.Id = 556
Marketplace.ProcessReceipt({ PlayerId = 101, ProductId = 556, PurchaseId = "p3" })
check("Server Luck aktivní", (workspace:GetAttribute("ServerLuckUntil") or 0) > os.time())

-- AutoSell: plný batoh se sám prodá
session.Data.Sand = 0
Remotes.EquipItem.OnServerInvoke(player, "Backpack", "Pocket")
Remotes.EquipItem.OnServerInvoke(player, "Tool", "Excavator")
local sellCoins = session.Data.Coins
root.Position = Vector3.new(100, WorldService.surfaceHeight(100, 100) + 3, 100)
for i = 1, 6 do
	mock.advance(0.5)
	Remotes.Dig.OnServerEvent:Fire(player, Vector3.new(100 + i * 3, WorldService.surfaceHeight(100 + i * 3, 100), 100))
end
check("AutoSell prodává", session.Data.Coins > sellCoins)

print("== Rebirth ==")
session.Data.Coins = 1e9
ok, msg = Remotes.Rebirth.OnServerInvoke(player)
check("rebirth", ok and session.Data.Rebirths == 1, msg)
check("rebirth resetoval mince", session.Data.Coins == 0)
check("VIP si nechal Golden Shovel", session.Data.EquippedTool == "GoldenShovel", session.Data.EquippedTool)
ok = Remotes.Rebirth.OnServerInvoke(player)
check("rebirth bez peněz nejde", not ok)

print("== Písečná bouře ==")
SandstormService.forceStorm()
mock.advance(2)
check(
	"varování před bouří",
	workspace:GetAttribute("StormPhase") == "Warning",
	workspace:GetAttribute("StormPhase")
)
mock.advance(Config.Sandstorm.WarningTime + 2)
check("bouře probíhá / proběhla", workspace:GetAttribute("StormPhase") ~= "Warning")
mock.advance(Config.Sandstorm.MinStormTime + 5)
check("po bouři klid", workspace:GetAttribute("StormPhase") == "Calm", workspace:GetAttribute("StormPhase"))
check("po bouři je poušť plná", WorldService.getClearedFraction() < 0.01, WorldService.getClearedFraction())
check("po bouři nové truhly", #treasures:GetChildren() >= Config.Treasure.StartChests)
check("svět je zase připravený", WorldService.isReady())

print("== Odměny ==")
coins = session.Data.Coins
ok, msg = Remotes.ClaimDaily.OnServerInvoke(player)
check("denní odměna", ok and session.Data.Coins > coins, msg)
ok = Remotes.ClaimDaily.OnServerInvoke(player)
check("denní odměna jen jednou", not ok)
check("celkové mince rostou", session.Data.TotalCoins >= session.Data.Coins)
Remotes.SaveSettings.OnServerEvent:Fire(player, { Music = 0.2, Sfx = 5, Hack = true, LowGfx = "x" })
check(
	"nastavení uloženo a ořezáno",
	session.Data.Settings.Music == 0.2
		and session.Data.Settings.Sfx == 1
		and session.Data.Settings.Hack == nil
		and session.Data.Settings.LowGfx == false
)

print("== Ukládání ==")
mock.services.Players.PlayerRemoving:Fire(player)
local stored = mock.stores["DuneDiggers_PlayerData_v1"]["Player_101"]
check("data uložena", stored ~= nil and stored.Rebirths == 1)
check("zámek uvolněn", stored and stored.Lock == nil)
mock.advance(1)
check("žebříček uložen", mock.ordered["LB_Coins_v1"] and (mock.ordered["LB_Coins_v1"]["101"] or 0) > 0)
check("session odstraněna", DataService.get(player) == nil)

-- znovu připojení – data se načtou
local player2 = mock.newPlayer(101, "Tester")
mock.services.Players.PlayerAdded:Fire(player2)
mock.advance(2)
local session2 = DataService.get(player2)
check("po návratu data načtena", session2 and session2.Data.Rebirths == 1)
check("po návratu účtenky zachovány", session2 and session2.Data.Receipts["p1"] ~= nil)
mock.advance(100)
local lbJson = mock.lastJson
check("žebříček obnoven", lbJson and lbJson.Coins and lbJson.Coins[1] and lbJson.Coins[1].Value > 0)

print(("\nVÝSLEDEK: %d OK, %d CHYB"):format(passed, failed))
if failed > 0 then
	error("TESTY SELHALY")
end
