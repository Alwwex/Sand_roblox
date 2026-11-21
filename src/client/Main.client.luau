--[[
	DUNE DIGGERS – hlavní klientský skript
	Propojuje UI, kopání, efekty a zprávy ze serveru.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local DigController = require(script.Parent:WaitForChild("DigController"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer
local state = nil

UI.init()
DigController.init()

local function applyState(newState)
	if not newState then
		return
	end
	state = newState
	UI.update(newState)
	DigController.setState(newState)
end

Remotes.DataSync.OnClientEvent:Connect(applyState)
task.spawn(function()
	applyState(Remotes.GetData:InvokeServer())
end)

---------------------------------------------------------------------
-- Zprávy ze serveru
---------------------------------------------------------------------

Remotes.Notify.OnClientEvent:Connect(function(message, kind)
	UI.toast(message, kind)
	if kind == "epic" or (type(kind) == "string" and kind:sub(1, 7) == "rarity:") then
		Effects.playSound("Chest", 0.5, 0.9)
	end
end)

Remotes.DigResult.OnClientEvent:Connect(function(amount, position, isFull)
	local tool = state and Config.ToolsById[state.EquippedTool]
	local strength = if tool then tool.Radius / 2.6 else 1
	Effects.digBurst(position, strength)
	Effects.popup(
		position,
		"+" .. Util.formatNumber(amount),
		Color3.fromRGB(255, 225, 140),
		math.min(1.4, 0.8 + strength * 0.15)
	)
	Effects.playSound("Dig", 0.35, 0.9 + math.random() * 0.3)
	if isFull and not (state and state.Passes.AutoSell) then
		Effects.playSound("Click", 0.4, 0.6)
	end
end)

Remotes.Sold.OnClientEvent:Connect(function(coins, sand, isAuto)
	UI.bigPopup("+" .. Util.formatNumber(coins) .. " 💰", Color3.fromRGB(255, 215, 70))
	Effects.playSound("Sell", 0.6, 1)
	if not isAuto then
		UI.toast(("Sold %s sand for %s coins!"):format(Util.formatNumber(sand), Util.formatNumber(coins)), "success")
	end
end)

Remotes.ChestOpened.OnClientEvent:Connect(function(rarityName, coins, artifactId, isNew, position)
	local rarity = Config.Rarities[rarityName]
	local color = if rarity then rarity.Color else Color3.fromRGB(255, 215, 70)
	Effects.chestBurst(position, color)
	Effects.popup(
		position + Vector3.new(0, 2, 0),
		"+" .. Util.formatNumber(coins) .. " 💰",
		Color3.fromRGB(255, 215, 70),
		1.5
	)
	Effects.playSound("Chest", 0.7, 1.1)

	local artifact = artifactId and Config.ArtifactsById[artifactId]
	if artifact then
		if isNew then
			UI.bigPopup(artifact.Icon .. " NEW ARTIFACT!", Config.Rarities[artifact.Rarity].Color)
			UI.toast(
				("%s %s found! +%d%% coins forever"):format(
					artifact.Icon,
					artifact.Name,
					math.floor(artifact.Bonus * 100 + 0.5)
				),
				"rarity:" .. artifact.Rarity
			)
		else
			UI.toast(("%s Duplicate %s → bonus coins!"):format(artifact.Icon, artifact.Name), "info")
		end
	end
end)

Remotes.OpenWindow.OnClientEvent:Connect(function(name)
	UI.open(name)
end)

---------------------------------------------------------------------
-- Písečná bouře
---------------------------------------------------------------------

local function onStormPhase()
	Effects.setStorm(workspace:GetAttribute("StormPhase") or "Calm")
end
workspace:GetAttributeChangedSignal("StormPhase"):Connect(onStormPhase)
onStormPhase()

---------------------------------------------------------------------
-- Treasure Radar (gamepass): zvýrazní nejbližší zakopané truhly
---------------------------------------------------------------------

local RADAR_RANGE = 140
local RADAR_MAX = 8
local radarHighlights = {} -- [Model] = Highlight

task.spawn(function()
	local treasures = workspace:WaitForChild("Treasures")
	while true do
		task.wait(0.5)
		local hasRadar = state and state.Passes.TreasureRadar
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		local wanted = {}
		if hasRadar and root then
			local candidates = {}
			for _, chest in treasures:GetChildren() do
				if chest:IsA("Model") and chest.PrimaryPart and not chest:GetAttribute("Exposed") then
					local distance = (chest.PrimaryPart.Position - root.Position).Magnitude
					if distance <= RADAR_RANGE then
						table.insert(candidates, { Chest = chest, Distance = distance })
					end
				end
			end
			table.sort(candidates, function(a, b)
				return a.Distance < b.Distance
			end)
			for i = 1, math.min(RADAR_MAX, #candidates) do
				wanted[candidates[i].Chest] = true
			end
		end

		for chest, highlight in radarHighlights do
			if not wanted[chest] or not chest.Parent then
				highlight:Destroy()
				radarHighlights[chest] = nil
			end
		end
		for chest in wanted do
			if not radarHighlights[chest] then
				local rarity = Config.Rarities[chest:GetAttribute("Rarity")]
				local highlight = Instance.new("Highlight")
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.FillColor = if rarity then rarity.Color else Color3.new(1, 1, 1)
				highlight.FillTransparency = 0.5
				highlight.OutlineColor = Color3.new(1, 1, 1)
				highlight.Adornee = chest
				highlight.Parent = chest
				radarHighlights[chest] = highlight
			end
		end
	end
end)

---------------------------------------------------------------------
-- VIP štítek v chatu
---------------------------------------------------------------------

pcall(function()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local sender = Players:GetPlayerByUserId(source.UserId)
			if sender and sender:GetAttribute("VIP") then
				properties.PrefixText = "<font color='#FFD23C'>[👑 VIP]</font> " .. message.PrefixText
			end
		end
		return properties
	end
end)
