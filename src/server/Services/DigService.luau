--[[
	DigService – kopání. Klient pošle "kde chci kopat", server vše ověří
	(vzdálenost, cooldown, nástroj v ruce, místo v batohu) a teprve pak kope.
	Díky tomu se kopání nedá jednoduše hacknout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local QuestService = require(script.Parent.QuestService)
local ShopService = require(script.Parent.ShopService)
local Stats = require(script.Parent.Stats)
local TreasureService = require(script.Parent.TreasureService)
local WorldService = require(script.Parent.WorldService)

local DigService = {}

local function isFiniteVector(v: Vector3): boolean
	for _, n in { v.X, v.Y, v.Z } do
		if n ~= n or n == math.huge or n == -math.huge then
			return false
		end
	end
	return true
end

local function handleDig(player: Player, target)
	if typeof(target) ~= "Vector3" or not isFiniteVector(target) then
		return
	end
	if not WorldService.isReady() then
		return
	end
	local session = DataService.get(player)
	if not session then
		return
	end
	local data = session.Data

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Hráč musí držet svůj nástroj
	local held = character:FindFirstChildOfClass("Tool")
	if not held or held:GetAttribute("DigToolId") ~= data.EquippedTool then
		return
	end
	local tool = Config.ToolsById[data.EquippedTool]
	if not tool then
		return
	end

	-- Cooldown (s malou tolerancí na lag)
	local now = os.clock()
	local cooldown = tool.Cooldown / Stats.digSpeed(session)
	if now - session.LastDig < cooldown * 0.8 then
		return
	end

	-- Dosah
	if
		(target - root.Position).Magnitude > tool.Reach + 8
		or not WorldService.inBounds(target)
		or WorldService.isInLobby(target) -- v lobby se nekope (voda, dlažba)
	then
		return
	end

	-- Plný batoh
	local capacity = Stats.capacity(session)
	if data.Sand >= capacity then
		if session.Passes.AutoSell then
			ShopService.sell(player, true)
		else
			if now - session.LastFullNotice > 4 then
				session.LastFullNotice = now
				DataService.notify(player, "Your bag is full! Sell your sand at the camp 💰", "full")
			end
			return
		end
	end

	session.LastDig = now
	local removed = WorldService.digSphere(target, tool.Radius)
	if removed <= 0 then
		return
	end

	local amount = math.max(1, math.floor(removed + 0.5))
	local gained = math.min(amount, capacity - data.Sand)
	data.Sand += gained
	data.TotalSand += gained
	DataService.markDirty(player)
	QuestService.progress(player, "Dig", gained)
	Remotes.DigResult:FireClient(player, gained, target, data.Sand >= capacity)

	TreasureService.onDig(player, target, tool.Radius)

	if session.Passes.AutoSell and data.Sand >= capacity then
		ShopService.sell(player, true)
	end
end

function DigService.init()
	Remotes.Dig.OnServerEvent:Connect(handleDig)
end

return DigService
