--!nocheck
-- Smoke test klientské části (UI, efekty, kopání) – běží po serverovém testu.
print("\n== Klient ==")
local cPassed, cFailed = 0, 0
local function ccheck(name, condition, detail)
	if condition then
		cPassed += 1
		print("  ✔ " .. name)
	else
		cFailed += 1
		print("  ✘ " .. name .. (if detail then (" (" .. tostring(detail) .. ")") else ""))
	end
end

local Players = mock.services.Players
local localPlayer = mock.playerList[#mock.playerList]
mock.localPlayer = localPlayer
mock.dataOf(Players).LocalPlayer = localPlayer
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
localPlayer:LoadCharacter()
mock.advance(1)

runClient()
mock.advance(1)

local Remotes = require(tree.Shared.Remotes)
local DataService = require(tree.Services.DataService)
local UI = require(tree.Client.UI)
local Effects = require(tree.Client.Effects)

local gui = playerGui:FindFirstChild("DuneDiggersUI")
ccheck("UI vytvořeno", gui ~= nil)

local session = DataService.get(localPlayer)
local payload = DataService.buildPayload(session)
Remotes.DataSync.OnClientEvent:Fire(payload)
ccheck("UI přijalo data", UI.getState() ~= nil)

for _, name in { "Shop", "Shop:Backpack", "Store", "Rebirth", "Index", "Codes", "Top", "Settings" } do
	local ok, err = pcall(UI.open, name)
	ccheck("okno " .. name, ok, err)
	Remotes.DataSync.OnClientEvent:Fire(payload)
end
UI.close()

local ok, err = pcall(function()
	Remotes.Notify.OnClientEvent:Fire("Test", "rarity:Epic")
	Remotes.Notify.OnClientEvent:Fire("Test", "storm")
	for i = 1, 7 do
		UI.toast("toast " .. i, "info")
	end
	Remotes.DigResult.OnClientEvent:Fire(12, Vector3.new(0, 10, 0), false)
	Remotes.Sold.OnClientEvent:Fire(500, 500, false)
	Remotes.ChestOpened.OnClientEvent:Fire("Legendary", 9000, "SunStone", true, Vector3.new(5, 5, 5))
	Remotes.ChestOpened.OnClientEvent:Fire("Common", 60, "AncientCoin", false, Vector3.new(5, 5, 5))
	Remotes.ChestOpened.OnClientEvent:Fire("Rare", 300, nil, false, Vector3.new(5, 5, 5))
	Remotes.OpenWindow.OnClientEvent:Fire("Shop")
	Remotes.Reward.OnClientEvent:Fire("Daily", 400)
	UI.flyCoins(6)
	UI.applySettings({ Music = 0, Sfx = 0.5, LowGfx = true, Popups = false })
	Effects.setStorm("Warning")
	Effects.setStorm("Active")
	Effects.setStorm("Calm")
	mock.advance(6)
end)
ccheck("notifikace, efekty, bouře", ok, err)

-- vlastní hotbar (výběr nástrojů)
ccheck("výchozí Roblox hotbar vypnutý", mock.coreGui and mock.coreGui.Backpack == false)
local hotbar
for _, inst in gui:GetDescendants() do
	if inst.Name == "Hotbar" then
		hotbar = inst
	end
end
ccheck("hotbar existuje", hotbar ~= nil)
session.Data.OwnedTools = { Hands = true, Spoon = true, Shovel = true }
session.Data.EquippedTool = "Hands"
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
local slotCount = 0
for _, child in hotbar:GetChildren() do
	if child.ClassName == "Frame" then
		slotCount += 1
	end
end
ccheck("hotbar: 3 nástroje + zamčený slot", slotCount == 4, slotCount)
local UIS = mock.services.UserInputService
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Three, UserInputType = Enum.UserInputType.Keyboard }, false)
mock.advance(0.5)
ccheck("klávesa 3 vybere Shovel", session.Data.EquippedTool == "Shovel", session.Data.EquippedTool)
local held = localPlayer.Character:FindFirstChildOfClass("Tool")
ccheck("Shovel je v ruce", held and held:GetAttribute("DigToolId") == "Shovel")
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Three, UserInputType = Enum.UserInputType.Keyboard }, false)
ccheck("znovu 3 = schovat nástroj", localPlayer.Character:FindFirstChildOfClass("Tool") == nil)
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Three, UserInputType = Enum.UserInputType.Keyboard }, false)
ccheck("znovu 3 = vytáhnout nástroj", localPlayer.Character:FindFirstChildOfClass("Tool") ~= nil)
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.ButtonL1, UserInputType = Enum.UserInputType.Gamepad1 }, false)
mock.advance(0.5)
ccheck("LB přepne na předchozí (Spoon)", session.Data.EquippedTool == "Spoon", session.Data.EquippedTool)
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Two, UserInputType = Enum.UserInputType.Keyboard }, true)
ccheck("klávesa v chatu se ignoruje", session.Data.EquippedTool == "Spoon")

-- vajíčka, mazlíčci, úkoly
local function findButton(root, prefix)
	for _, inst in root:GetDescendants() do
		if inst.ClassName == "TextButton" and string.sub(inst.Text, 1, #prefix) == prefix then
			return inst
		end
	end
	return nil
end
session.Data.Coins = 100000
session.Data.Pets = {}
session.Data.EquippedPets = {}
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
for _, name in { "Egg", "Egg:OasisEgg", "Egg:SandEgg", "Pets", "Quests" } do
	local okOpen, errOpen = pcall(UI.open, name)
	ccheck("okno " .. name, okOpen, errOpen)
	Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
end
local petsWindow = gui:FindFirstChild("PetsWindow")
ccheck("prázdný inventář ukazuje nápovědu", petsWindow and findButton(petsWindow, "🥚 SEE EGGS") ~= nil)
UI.open("Egg:SandEgg")
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
local eggWindow = gui:FindFirstChild("EggWindow")
local hatchButton = eggWindow and findButton(eggWindow, "HATCH 3")
ccheck("tlačítko HATCH 3", hatchButton ~= nil)
local hatchedBefore = session.Data.Hatched
ok, err = pcall(function()
	hatchButton.Activated:Fire()
end)
ccheck("líhnutí z okna", ok and session.Data.Hatched == hatchedBefore + 3, err or session.Data.Hatched)
ccheck("animace líhnutí", gui:FindFirstChild("HatchFx") ~= nil)
ok, err = pcall(function()
	mock.advance(6)
end)
ccheck("animace doběhla a zmizela", ok and gui:FindFirstChild("HatchFx") == nil, err)
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
UI.open("Pets")
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
local cells = 0
for _, inst in petsWindow:GetDescendants() do
	if inst.ClassName == "Frame" and session.Data.Pets[inst.Name] then
		cells += 1
	end
end
ccheck("inventář ukazuje 3 mazlíčky", cells == 3, cells)
-- mazlíčci chodí za hráčem (klient je posouvá)
local RunService = mock.services.RunService
local myPets = workspace.Pets:FindFirstChild(tostring(localPlayer.UserId))
ok, err = pcall(function()
	for _ = 1, 30 do
		RunService.RenderStepped:Fire(1 / 30)
	end
end)
ccheck("PetFollow běží", ok, err)
local root = localPlayer.Character.HumanoidRootPart
local near = myPets and #myPets:GetChildren() == 3
for _, model in (myPets and myPets:GetChildren()) or {} do
	local distance = (model:GetPivot().Position - root.Position).Magnitude
	near = near and distance < 12
end
ccheck("mazlíčci jsou u hráče", near)
-- úkol připravený k vyzvednutí -> červená tečka a tlačítko CLAIM!
session.Data.Quests.List[1].Progress = session.Data.Quests.List[1].Target
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
local questDot
for _, inst in gui:GetDescendants() do
	if inst.Name == "Quests" and inst:FindFirstChild("Dot") then
		questDot = inst.Dot
	end
end
ccheck("červená tečka u QUESTS", questDot and questDot.Visible == true)
UI.open("Quests")
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
local claim = findButton(gui:FindFirstChild("QuestsWindow"), "CLAIM!")
local coinsBefore = session.Data.Coins
ok, err = pcall(function()
	claim.Activated:Fire()
end)
ccheck("vyzvednutí úkolu z okna", ok and session.Data.Coins > coinsBefore, err)
UI.close()

-- tlačítka v obchodě: projdeme všechna TextButton a "klikneme"
local clicked = 0
ok, err = pcall(function()
	for _, inst in gui:GetDescendants() do
		if inst.ClassName == "TextButton" and inst.Text ~= "⛺ CAMP" then
			inst.Activated:Fire()
			clicked += 1
		end
	end
	mock.advance(1)
end)
ccheck(("kliknutí na %d tlačítek"):format(clicked), ok and clicked > 20, err)

-- kopání z klienta: nástroj v ruce -> Activated -> FireServer
local before = session.Data.Sand
ok, err = pcall(function()
	local character = localPlayer.Character
	local tool = character:FindFirstChildOfClass("Tool")
	character.ChildAdded:Fire(tool)
	tool.Activated:Fire()
	mock.advance(2)
	tool.Deactivated:Fire()
end)
ccheck("kopání z klienta nespadne", ok, err)

print(("\nKLIENT: %d OK, %d CHYB"):format(cPassed, cFailed))
if cFailed > 0 then
	error("KLIENTSKÉ TESTY SELHALY")
end
