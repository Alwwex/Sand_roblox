--[[
	DUNE DIGGERS – hlavní klientský skript
	Hlavní menu → hra. Propojuje UI, hudbu, kopání, efekty a zprávy ze serveru.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Audio = require(script.Parent:WaitForChild("Audio"))
local DigController = require(script.Parent:WaitForChild("DigController"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer
local state = nil
local settings = { Music = 0.5, Sfx = 0.8, LowGfx = false, Popups = true }
local lastMusicVolume = 0.5
local settingsLoaded = false
local saveScheduled = false
local digSoundToggle = false

---------------------------------------------------------------------
-- Nastavení (hlasitost, grafika) – ukládá se na server
---------------------------------------------------------------------

local function applySettings()
	Audio.setVolumes(settings.Music, settings.Sfx)
	Effects.lowGraphics = settings.LowGfx
	Effects.popups = settings.Popups
end

local function onSettingsChanged(newSettings)
	for key, value in newSettings do
		settings[key] = value
	end
	applySettings()
	if not saveScheduled then
		saveScheduled = true
		task.delay(1, function()
			saveScheduled = false
			Remotes.SaveSettings:FireServer(settings)
		end)
	end
end

local function toggleMusic(): boolean
	if settings.Music > 0 then
		lastMusicVolume = settings.Music
		onSettingsChanged({ Music = 0 })
	else
		onSettingsChanged({ Music = if lastMusicVolume > 0 then lastMusicVolume else 0.5 })
	end
	UI.applySettings(settings)
	return settings.Music > 0
end

---------------------------------------------------------------------
-- Start
---------------------------------------------------------------------

Audio.init()
UI.init({ sfx = Audio.sfx, settingsChanged = onSettingsChanged, toggleMusic = toggleMusic })
DigController.init()
applySettings()
Audio.setMenu(true)

UI.showMenu(function()
	Audio.setMenu(false)
	UI.setHudVisible(true)
	Audio.sfx("Open", 0.6)
end)

local function applyState(newState)
	if not newState then
		return
	end
	state = newState
	if not settingsLoaded and newState.Settings then
		settingsLoaded = true
		for key, value in newState.Settings do
			settings[key] = value
		end
		applySettings()
		UI.applySettings(settings)
	end
	UI.update(newState)
	DigController.setState(newState)
end

Remotes.DataSync.OnClientEvent:Connect(applyState)
task.spawn(function()
	applyState(Remotes.GetData:InvokeServer())
end)

-- hudba podle místa (lobby / poušť / bouře)
task.spawn(function()
	while true do
		Audio.refresh()
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- Zprávy ze serveru
---------------------------------------------------------------------

Remotes.Notify.OnClientEvent:Connect(function(message, kind)
	UI.toast(message, kind)
	if kind == "epic" then
		Audio.sfx("Rare", 0.6)
	elseif kind == "error" or kind == "full" then
		Audio.sfx("Error", 0.5)
	elseif type(kind) == "string" and kind:sub(1, 7) == "rarity:" then
		Audio.sfx("Chest", 0.6)
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
	digSoundToggle = not digSoundToggle
	Audio.sfx(if digSoundToggle then "Dig" else "Dig2", 0.55, 0.9 + math.random() * 0.25)
	if strength >= 2.3 then
		Effects.shake(0.25 * strength, 0.15)
	end
	if isFull and not (state and state.Passes.AutoSell) then
		Audio.sfx("Error", 0.4)
	end
end)

Remotes.Sold.OnClientEvent:Connect(function(coins, sand, isAuto)
	UI.bigPopup("+" .. Util.formatNumber(coins) .. " 💰", Color3.fromRGB(255, 215, 70))
	UI.flyCoins(math.clamp(math.floor(sand / 20), 4, 12))
	Audio.sfx("Sell", 0.8)
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
	UI.flyCoins(8)
	if rarity and rarity.Order >= 3 then
		Audio.sfx("Rare", 0.9)
		UI.flash(color, 0.45)
		Effects.shake(0.6, 0.3)
	else
		Audio.sfx("Chest", 0.8)
	end

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

Remotes.Reward.OnClientEvent:Connect(function(kind, coins)
	UI.bigPopup(
		(if kind == "Vip" then "👑 VIP " else "🎁 DAILY ") .. "+" .. Util.formatNumber(coins),
		Color3.fromRGB(150, 255, 150)
	)
	UI.flyCoins(10)
	UI.flash(Color3.fromRGB(255, 240, 170), 0.35)
	Audio.sfx("Rare", 0.8)
end)

Remotes.OpenWindow.OnClientEvent:Connect(function(name)
	UI.open(name)
end)

---------------------------------------------------------------------
-- Písečná bouře
---------------------------------------------------------------------

local function onStormPhase()
	local phase = workspace:GetAttribute("StormPhase") or "Calm"
	Effects.setStorm(phase)
	if phase == "Warning" then
		Audio.sfx("Storm", 0.9)
	end
	Audio.refresh()
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
