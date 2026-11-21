--[[
	DUNE DIGGERS – hlavní serverový skript
	Spouští všechny služby ve správném pořadí.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
require(ReplicatedStorage.Shared.Remotes) -- vytvoří RemoteEventy

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local WorldService = require(Services.WorldService)
local TreasureService = require(Services.TreasureService)
local ShopService = require(Services.ShopService)
local DigService = require(Services.DigService)
local MonetizationService = require(Services.MonetizationService)
local SandstormService = require(Services.SandstormService)

-- Postavy spawnujeme až když je svět hotový
Players.CharacterAutoLoads = false

DataService.init()
MonetizationService.init()

print("[Dune Diggers] Generuji poušť...")
local started = os.clock()
WorldService.init()
TreasureService.init()
TreasureService.populate()
ShopService.init()
DigService.init()
WorldService.setReady(true)
SandstormService.start()
print(("[Dune Diggers] Svět hotový za %.1f s"):format(os.clock() - started))

---------------------------------------------------------------------
-- Hráči
---------------------------------------------------------------------

local function spawnCharacter(player: Player)
	if player.Parent and DataService.get(player) then
		player:LoadCharacter()
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- CharacterAdded přijde dřív, než je postava ve Workspace – počkáme
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	player:WaitForChild("Backpack", 10)
	task.wait()
	if player.Character ~= character then
		return
	end
	ShopService.giveTool(player)

	-- VIP: zlaté jméno nad hlavou
	if player:GetAttribute("VIP") then
		humanoid.DisplayName = "👑 " .. player.DisplayName
	end

	humanoid.Died:Connect(function()
		task.delay(Config.RespawnTime, function()
			if player.Character == character then
				spawnCharacter(player)
			end
		end)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	local session = DataService.loadPlayer(player)
	if not session then
		return
	end
	MonetizationService.loadPasses(player)
	DataService.syncNow(player)

	while not WorldService.isReady() and player.Parent do
		task.wait(0.5)
	end
	spawnCharacter(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
