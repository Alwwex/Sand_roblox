--[[
	ShopService – prodej písku, obchod s nástroji/batohy, rebirth, kódy,
	teleport do tábora a výdej nástroje do ruky.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Stats = require(script.Parent.Stats)
local ToolFactory = require(ReplicatedStorage.Shared.ToolFactory)
local WorldService = require(script.Parent.WorldService)

local ShopService = {}

---------------------------------------------------------------------
-- Nástroj v ruce
---------------------------------------------------------------------

function ShopService.giveTool(player: Player)
	local session = DataService.get(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not session or not character or not backpack then
		return
	end

	-- Pojistka: když hráč přišel o gamepass nástroj, vrátíme ho k nejlepšímu vlastněnému
	if not Stats.ownsTool(session, session.Data.EquippedTool) then
		session.Data.EquippedTool = "Hands"
		for _, tool in Config.Tools do
			if Stats.ownsTool(session, tool.Id) then
				session.Data.EquippedTool = tool.Id
			end
		end
	end

	for _, container in { backpack, character } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("DigToolId") then
				child:Destroy()
			end
		end
	end

	local tool = ToolFactory.create(session.Data.EquippedTool)
	tool.Parent = backpack
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
end

---------------------------------------------------------------------
-- Prodej
---------------------------------------------------------------------

function ShopService.sell(player: Player, isAuto: boolean?): number
	local session = DataService.get(player)
	if not session then
		return 0
	end
	local data = session.Data
	if data.Sand <= 0 then
		return 0
	end
	local sand = data.Sand
	local coins = math.floor(sand * Config.Economy.CoinsPerSand * Stats.coinMultiplier(session))
	data.Sand = 0
	DataService.addCoins(player, coins)
	DataService.markDirty(player)
	Remotes.Sold:FireClient(player, coins, sand, isAuto == true)
	return coins
end

---------------------------------------------------------------------
-- Nákupy za mince
---------------------------------------------------------------------

local function buyItem(player: Player, category: string, id: string)
	local session = DataService.get(player)
	if not session or type(category) ~= "string" or type(id) ~= "string" then
		return false, "Not ready yet"
	end
	local data = session.Data

	if category == "Tool" then
		local tool = Config.ToolsById[id]
		if not tool then
			return false, "Unknown tool"
		end
		if tool.Pass then
			return false, "This tool comes with the " .. Config.GamePasses[tool.Pass].Name .. " gamepass"
		end
		if data.OwnedTools[id] then
			return false, "You already own this"
		end
		if data.Coins < tool.Price then
			return false, ("You need %s more coins"):format(Util.formatNumber(tool.Price - data.Coins))
		end
		data.Coins -= tool.Price
		data.OwnedTools[id] = true
		data.EquippedTool = id
		DataService.markDirty(player)
		ShopService.giveTool(player)
		return true, ("Bought %s!"):format(tool.Name)
	elseif category == "Backpack" then
		local backpack = Config.BackpacksById[id]
		if not backpack then
			return false, "Unknown backpack"
		end
		if data.OwnedBackpacks[id] then
			return false, "You already own this"
		end
		if data.Coins < backpack.Price then
			return false, ("You need %s more coins"):format(Util.formatNumber(backpack.Price - data.Coins))
		end
		data.Coins -= backpack.Price
		data.OwnedBackpacks[id] = true
		data.EquippedBackpack = id
		DataService.markDirty(player)
		return true, ("Bought %s!"):format(backpack.Name)
	end
	return false, "Unknown item"
end

local function equipItem(player: Player, category: string, id: string)
	local session = DataService.get(player)
	if not session or type(category) ~= "string" or type(id) ~= "string" then
		return false, "Not ready yet"
	end
	local data = session.Data

	if category == "Tool" then
		if not Stats.ownsTool(session, id) then
			return false, "You don't own this tool"
		end
		data.EquippedTool = id
		DataService.markDirty(player)
		ShopService.giveTool(player)
		return true, "Equipped " .. Config.ToolsById[id].Name
	elseif category == "Backpack" then
		if not data.OwnedBackpacks[id] or not Config.BackpacksById[id] then
			return false, "You don't own this backpack"
		end
		data.EquippedBackpack = id
		DataService.markDirty(player)
		return true, "Equipped " .. Config.BackpacksById[id].Name
	end
	return false, "Unknown item"
end

local function rebirth(player: Player)
	local session = DataService.get(player)
	if not session then
		return false, "Not ready yet"
	end
	local data = session.Data
	local cost = Stats.rebirthCost(data)
	if data.Coins < cost then
		return false, ("You need %s coins to rebirth"):format(Util.formatNumber(cost))
	end
	data.Rebirths += 1
	data.Coins = 0
	data.Sand = 0
	data.OwnedTools = { Hands = true }
	data.OwnedBackpacks = { Pocket = true }
	data.EquippedBackpack = "Pocket"
	-- Nasadíme nejlepší nástroj, který hráči zůstal (např. Golden Shovel z VIP)
	data.EquippedTool = "Hands"
	for _, tool in Config.Tools do
		if Stats.ownsTool(session, tool.Id) then
			data.EquippedTool = tool.Id
		end
	end
	DataService.markDirty(player)
	ShopService.giveTool(player)
	DataService.notifyAll(("♻️ %s reached Rebirth %d!"):format(player.DisplayName, data.Rebirths), "epic")
	return true,
		("Rebirth %d! Coins x%s forever"):format(
			data.Rebirths,
			string.format("%.1f", 1 + data.Rebirths * Config.Rebirth.MultiplierPerRebirth)
		)
end

local function redeemCode(player: Player, rawCode: string)
	local session = DataService.get(player)
	if not session or type(rawCode) ~= "string" or #rawCode > 40 then
		return false, "Invalid code"
	end
	local code = rawCode:upper():gsub("%s", "")
	local reward = Config.Codes[code]
	if not reward then
		return false, "Invalid code"
	end
	local data = session.Data
	if data.Codes[code] then
		return false, "Code already redeemed"
	end
	data.Codes[code] = true
	local coins = 0
	if reward.Coins then
		coins = reward.Coins * (data.Rebirths + 1)
		DataService.addCoins(player, coins)
	end
	DataService.markDirty(player)
	return true, ("Code redeemed! +%s coins"):format(Util.formatNumber(coins))
end

function ShopService.init()
	Remotes.BuyItem.OnServerInvoke = buyItem
	Remotes.EquipItem.OnServerInvoke = equipItem
	Remotes.Rebirth.OnServerInvoke = rebirth
	Remotes.RedeemCode.OnServerInvoke = redeemCode

	Remotes.TeleportCamp.OnServerEvent:Connect(function(player)
		local session = DataService.get(player)
		local character = player.Character
		if not session or not character then
			return
		end
		local now = os.clock()
		if now - session.LastCampTeleport < Config.CampTeleportCooldown then
			DataService.notify(
				player,
				("Wait %ds before teleporting again"):format(
					math.ceil(Config.CampTeleportCooldown - (now - session.LastCampTeleport))
				),
				"error"
			)
			return
		end
		session.LastCampTeleport = now
		WorldService.teleportToCamp(player)
	end)

	-- Výkupna písku (šlápnutí na zlatou plochu)
	local sellPad = WorldService.SellPad
	if sellPad then
		sellPad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			local session = DataService.get(player)
			if not session then
				return
			end
			local now = os.clock()
			if now - session.LastSellTouch < 0.75 then
				return
			end
			session.LastSellTouch = now
			ShopService.sell(player, false)
		end)
	end

	-- Prompty v táboře otevřou okna v UI
	local function addPrompt(part: BasePart?, actionText: string, window: string)
		if not part then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = ""
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			Remotes.OpenWindow:FireClient(player, window)
		end)
	end
	local lobby = WorldService.Lobby or {}
	addPrompt(lobby.ToolCounter, "Tool Shop", "Shop")
	addPrompt(lobby.BackpackCounter, "Backpacks", "Shop:Backpack")
	addPrompt(lobby.RebirthAltar, "Rebirth", "Rebirth")
end

return ShopService
