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
