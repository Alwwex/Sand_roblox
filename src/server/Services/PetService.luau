--[[
	PetService – vajíčka a mazlíčci.

	- Vajíčka se kupují za mince u stánků v Hatchery (lobby) nebo v okně Egg.
	- Šance na mazlíčky jsou vidět v UI (Config.Eggs).
	- Nasazení mazlíčci dávají bonus k mincím a chodí za hráčem
	  (server je vytvoří ve workspace.Pets, klient je plynule posouvá).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetFactory = require(ReplicatedStorage.Shared.PetFactory)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)
local Stats = require(script.Parent.Stats)
local WorldService = require(script.Parent.WorldService)

local PetService = {}

local rng = Random.new()
local petsFolder: Folder? = nil

local function countPets(data): number
	local n = 0
	for _ in data.Pets do
		n += 1
	end
	return n
end

local function petValue(data, uid: string): number
	local pet = Config.PetsById[data.Pets[uid] or ""]
	return if pet then pet.Coins else 0
end

local function rollPet(egg): string
	local total = 0
	for _, entry in egg.Pets do
		total += entry[2]
	end
	local roll = rng:NextNumber() * total
	for _, entry in egg.Pets do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return egg.Pets[1][1]
end

-- Vytvoří modely nasazených mazlíčků (klient je pak posouvá za hráčem)
function PetService.refreshModels(player: Player)
	local session = DataService.get(player)
	if not session or not petsFolder then
		return
	end
	local folder = petsFolder:FindFirstChild(tostring(player.UserId))
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder.Parent = petsFolder
	end
	folder:ClearAllChildren()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for index, uid in session.Data.EquippedPets do
		local petId = session.Data.Pets[uid]
		if petId then
			local model = PetFactory.build(petId)
			model.Name = string.format("%02d_%s", index, uid)
			if root then
				model:PivotTo(root.CFrame * CFrame.new((index - 2) * 3, -2.5, 4))
			end
			model.Parent = folder
		end
	end
end

local function equipBest(session)
	local data = session.Data
	local uids = {}
	for uid in data.Pets do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		return petValue(data, a) > petValue(data, b)
	end)
	local slots = Stats.petSlots(session)
	data.EquippedPets = {}
	for i = 1, math.min(slots, #uids) do
		table.insert(data.EquippedPets, uids[i])
	end
end

function PetService.hatch(player: Player, eggId: string, count: number)
	local session = DataService.get(player)
	local egg = type(eggId) == "string" and Config.EggsById[eggId]
	if not session or not egg then
		return false, "Unknown egg"
	end
	count = if count == 3 then 3 else 1
	local data = session.Data
	local cost = egg.Price * count
	if data.Coins < cost then
		return false, ("You need %s more coins"):format(Util.formatNumber(cost - data.Coins))
	end
	if countPets(data) + count > Config.MaxPets then
		return false, "Your pet inventory is full! Delete some pets first."
	end
	data.Coins -= cost
	local results = {}
	for _ = 1, count do
		data.PetCounter += 1
		local uid = "p" .. data.PetCounter
		local petId = rollPet(egg)
		local isNew = true
		for _, owned in data.Pets do
			if owned == petId then
				isNew = false
			end
		end
		data.Pets[uid] = petId
		data.Hatched += 1
		table.insert(results, { Uid = uid, PetId = petId, New = isNew })
		-- volný slot? rovnou nasadit
		if #data.EquippedPets < Stats.petSlots(session) then
			table.insert(data.EquippedPets, uid)
		end
	end
	QuestService.progress(player, "Hatch", count)
	DataService.markDirty(player)
	PetService.refreshModels(player)
	-- vzácný mazlíček = oznámení pro celý server
	for _, result in results do
		local pet = Config.PetsById[result.PetId]
		local rarity = Config.Rarities[pet.Rarity]
		if rarity.Order >= 4 then
			DataService.notifyAll(
				("%s hatched a %s %s! 🥚"):format(player.DisplayName, string.upper(pet.Rarity), pet.Name),
				"rarity:" .. pet.Rarity
			)
		end
	end
	return true, "Hatched!", results
end

function PetService.init()
	local folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	petsFolder = folder

	Remotes.HatchEgg.OnServerInvoke = function(player, eggId, count)
		return PetService.hatch(player, eggId, count)
	end

	Remotes.EquipPet.OnServerInvoke = function(player, uid, equip)
		local session = DataService.get(player)
		if not session or type(uid) ~= "string" or not session.Data.Pets[uid] then
			return false, "Unknown pet"
		end
		local data = session.Data
		local index = table.find(data.EquippedPets, uid)
		if equip == false or (equip == nil and index) then
			if index then
				table.remove(data.EquippedPets, index)
			end
		else
			if index then
				return true, "Already equipped"
			end
			if #data.EquippedPets >= Stats.petSlots(session) then
				return false, ("You can equip %d pets (VIP +1)"):format(Stats.petSlots(session))
			end
			table.insert(data.EquippedPets, uid)
		end
		DataService.markDirty(player)
		PetService.refreshModels(player)
		return true, ""
	end

	Remotes.EquipBestPets.OnServerInvoke = function(player)
		local session = DataService.get(player)
		if not session then
			return false, "Not ready"
		end
		equipBest(session)
		DataService.markDirty(player)
		PetService.refreshModels(player)
		return true, "Equipped your best pets!"
	end

	Remotes.DeletePet.OnServerInvoke = function(player, uid)
		local session = DataService.get(player)
		if not session or type(uid) ~= "string" or not session.Data.Pets[uid] then
			return false, "Unknown pet"
		end
		local data = session.Data
		if table.find(data.EquippedPets, uid) then
			return false, "Unequip the pet first"
		end
		data.Pets[uid] = nil
		DataService.markDirty(player)
		return true, "Pet deleted"
	end

	-- Stánky s vajíčky v lobby otevřou okno vajíčka
	local lobby = WorldService.Lobby or {}
	for eggId, standPart in lobby.EggStands or {} do
		local egg = Config.EggsById[eggId]
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = egg.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = standPart
		prompt.Triggered:Connect(function(player)
			Remotes.OpenWindow:FireClient(player, "Egg:" .. eggId)
		end)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			PetService.refreshModels(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local f = petsFolder and petsFolder:FindFirstChild(tostring(player.UserId))
		if f then
			f:Destroy()
		end
	end)
end

return PetService
