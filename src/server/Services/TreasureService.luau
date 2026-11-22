--[[
	TreasureService – zakopané truhly, artefakty a relikvie v ruinách.

	Truhly jsou zakopané v písku. Když hráč odkope písek nad truhlou,
	truhla se "odkryje" (rozzáří se) a jde otevřít (ProximityPrompt).
	Hlubší truhly mají větší šanci na vzácnost.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Stats = require(script.Parent.Stats)
local WorldService = require(script.Parent.WorldService)

local T = Config.Treasure
local W = Config.World

local TreasureService = {}

local rng = Random.new()
local folder: Folder? = nil
local chests = {} -- [Model] = info

---------------------------------------------------------------------
-- Model truhly
---------------------------------------------------------------------

local function chestPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildChest(rarityName: string, cframe: CFrame, isRelic: boolean)
	local rarity = Config.Rarities[rarityName]
	local model = Instance.new("Model")
	model.Name = rarityName .. "Chest"

	local scale = if isRelic then 1.6 else 1
	local bodyColor = rarity.Color
	local material = if rarity.Order >= 4
		then Enum.Material.Metal
		elseif rarity.Order == 1 then Enum.Material.WoodPlanks
		else Enum.Material.SmoothPlastic
	local gold = Color3.fromRGB(255, 205, 70)

	local base = chestPart(model, "Base", Vector3.new(3, 1.8, 2) * scale, cframe, bodyColor, material)
	local hinge = cframe * CFrame.new(0, 1.6 * scale, 1 * scale)
	local lidOffset = CFrame.new(0, -0.35 * scale, -1 * scale)
	local lid = chestPart(
		model,
		"Lid",
		Vector3.new(3, 0.7, 2) * scale,
		hinge * lidOffset,
		bodyColor:Lerp(Color3.new(1, 1, 1), 0.12),
		material
	)
	chestPart(
		model,
		"Trim",
		Vector3.new(3.1, 0.25, 2.1) * scale,
		cframe * CFrame.new(0, 0.9 * scale, 0),
		gold,
		Enum.Material.Metal
	)
	local lock = chestPart(
		model,
		"Lock",
		Vector3.new(0.5, 0.6, 0.2) * scale,
		cframe * CFrame.new(0, 0.9 * scale, -1.05 * scale),
		gold,
		Enum.Material.Neon
	)
	lock.CanCollide = false

	model.PrimaryPart = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = (if isRelic then "Ancient Relic" else rarityName .. " Chest")
	prompt.HoldDuration = if isRelic then 1.5 else 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = base

	model:SetAttribute("Rarity", rarityName)
	model:SetAttribute("Exposed", false)
	model:SetAttribute("IsRelic", isRelic)

	return model, prompt, lid, hinge, lidOffset
end

---------------------------------------------------------------------
-- Rarita
---------------------------------------------------------------------

local function rollRarity(depthFactor: number): string
	local luck = Stats.serverLuck()
	local weights = {}
	local total = 0
	for _, name in Config.RarityOrder do
		local rarity = Config.Rarities[name]
		local weight = rarity.Weight
		if weight > 0 and rarity.Order > 1 then
			weight *= luck * (1 + depthFactor * T.DepthLuck)
		end
		weights[name] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for _, name in Config.RarityOrder do
		roll -= weights[name]
		if roll <= 0 and weights[name] > 0 then
			return name
		end
	end
	return "Common"
end

local function rollArtifact(rarityName: string): string?
	-- Vybere artefakt dané rarity (nebo nižší, když žádný není)
	local order = Config.Rarities[rarityName].Order
	for o = order, 1, -1 do
		local pool = {}
		for _, artifact in Config.Artifacts do
			if Config.Rarities[artifact.Rarity].Order == o then
				table.insert(pool, artifact.Id)
			end
		end
		if #pool > 0 then
			return pool[rng:NextInteger(1, #pool)]
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Odkrytí a otevření
---------------------------------------------------------------------

local function expose(model: Model, info, finder: Player?)
	if info.Exposed then
		return
	end
	info.Exposed = true
	model:SetAttribute("Exposed", true)
	info.Prompt.Enabled = true

	local rarity = Config.Rarities[info.Rarity]
	local base = model.PrimaryPart :: BasePart

	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 12
	light.Brightness = 2
	light.Parent = base

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(rarity.Color)
	sparkle.LightEmission = 1
	sparkle.Rate = 6 + rarity.Order * 4
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.Size = NumberSequence.new(0.5)
	sparkle.Parent = base

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(7, 1.6)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Parent = base
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = if info.IsRelic then "✨ ANCIENT RELIC ✨" else string.upper(info.Rarity)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = rarity.Color
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(40, 25, 10)
	stroke.Parent = label

	if info.IsRelic then
		DataService.notifyAll(
			("🏛️ %s uncovered the LOST RUINS! An Ancient Relic awaits..."):format(
				if finder then finder.DisplayName else "Someone"
			),
			"epic"
		)
	elseif finder and rarity.Order >= 2 then
		DataService.notify(
			finder,
			("You uncovered a %s chest!"):format(string.upper(info.Rarity)),
			"rarity:" .. info.Rarity
		)
	end
end

local function openChest(model: Model, info, player: Player)
	if info.Opened or not info.Exposed then
		return
	end
	local session = DataService.get(player)
	if not session then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - (model.PrimaryPart :: BasePart).Position).Magnitude > 16 then
		return
	end

	info.Opened = true
	info.Prompt.Enabled = false

	local data = session.Data
	local rarity = Config.Rarities[info.Rarity]
	local tool = Config.ToolsById[data.EquippedTool]
	local toolTier = if tool then tool.Index else 1
	local coins = rarity.Coins * (1 + (toolTier - 1) * T.ToolTierBonus) * Stats.coinMultiplier(session)
	if session.Passes.TreasureRadar then
		coins *= Config.PassEffects.TreasureRadarCoins
	end

	local artifactId = nil
	local isNew = false
	if rng:NextNumber() <= rarity.ArtifactChance then
		artifactId = rollArtifact(info.Rarity)
		if artifactId then
			local count = data.Artifacts[artifactId] or 0
			isNew = count == 0
			data.Artifacts[artifactId] = count + 1
			if not isNew then
				-- duplikát = bonusové mince
				coins += rarity.Coins * 2 * Stats.coinMultiplier(session)
			end
		end
	end

	coins = math.floor(coins)
	DataService.addCoins(player, coins)
	data.ChestsOpened += 1
	DataService.markDirty(player)

	local position = (model.PrimaryPart :: BasePart).Position
	Remotes.ChestOpened:FireClient(player, info.Rarity, coins, artifactId, isNew, position)

	if info.IsRelic or rarity.Order >= 4 then
		local artifact = artifactId and Config.ArtifactsById[artifactId]
		local suffix = if artifact then (" and found %s %s!"):format(artifact.Icon, artifact.Name) else "!"
		DataService.notifyAll(
			("%s opened a %s chest%s (+%s coins)"):format(
				player.DisplayName,
				string.upper(info.Rarity),
				suffix,
				Util.formatNumber(coins)
			),
			"rarity:" .. info.Rarity
		)
	end

	-- Animace otevření víka, pak zmizí
	local openCFrame = info.Hinge * CFrame.Angles(math.rad(75), 0, 0) * info.LidOffset
	TweenService
		:Create(info.Lid, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = openCFrame })
		:Play()
	task.delay(4, function()
		chests[model] = nil
		model:Destroy()
	end)
end

---------------------------------------------------------------------
-- Spawnování
---------------------------------------------------------------------

local function spawnChest(position: Vector3, rarityName: string, isRelic: boolean, surfaceY: number)
	local cframe = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model, prompt, lid, hinge, lidOffset = buildChest(rarityName, cframe, isRelic)
	local info = {
		Rarity = rarityName,
		IsRelic = isRelic,
		Exposed = false,
		Opened = false,
		Prompt = prompt,
		Lid = lid,
		Hinge = hinge,
		LidOffset = lidOffset,
		Top = position + Vector3.new(0, if isRelic then 1.8 else 1.2, 0),
		SurfaceY = surfaceY,
	}
	chests[model] = info
	prompt.Triggered:Connect(function(player)
		openChest(model, info, player)
	end)
	model.Parent = folder
	return model
end

local function randomDesertPoint(): (number, number)
	local half = W.Size / 2 - 10
	local campZone = W.CampHalf + 14
	for _ = 1, 30 do
		local x = rng:NextNumber(-half, half)
		local z = rng:NextNumber(-half, half)
		if math.max(math.abs(x), math.abs(z)) > campZone then
			return x, z
		end
	end
	return half * 0.8, half * 0.8
end

-- useHeightmap = true při generování světa (rychlejší, terén je čerstvý)
local function spawnRandomChest(useHeightmap: boolean): boolean
	for _ = 1, 10 do
		local x, z = randomDesertPoint()
		local surface = if useHeightmap then WorldService.heightAt(x, z) else WorldService.surfaceHeight(x, z)
		if surface >= 8 then
			local y = rng:NextNumber(2, surface - 4)
			local depthFactor = math.clamp(1 - y / 40, 0, 1)
			local rarity = rollRarity(depthFactor)
			spawnChest(Vector3.new(x, y, z), rarity, false, surface)
			return true
		end
	end
	return false
end

local function countChests(): number
	local count = 0
	for _, info in chests do
		if not info.Opened then
			count += 1
		end
	end
	return count
end

---------------------------------------------------------------------
-- Veřejné API
---------------------------------------------------------------------

-- Volá DigService po každém kopnutí
function TreasureService.onDig(player: Player, position: Vector3, radius: number)
	for model, info in chests do
		if not info.Exposed and not info.Opened then
			if (info.Top - position).Magnitude <= radius + 8 then
				if WorldService.coverAt(info.Top) <= T.ExposeThreshold then
					expose(model, info, player)
				end
			end
		end
	end
end

function TreasureService.clearAll()
	for model in chests do
		model:Destroy()
	end
	table.clear(chests)
end

function TreasureService.populate()
	TreasureService.clearAll()

	-- Relikvie v ruinách + pár vzácných truhel kolem
	local ruinsCenter, relicCFrame = WorldService.getRuins()
	if ruinsCenter and relicCFrame then
		spawnChest(relicCFrame.Position, "Mythic", true, W.RuinsBuryHeight)
		for _, degrees in { 30, 150, 270 } do
			local angle = math.rad(degrees) + rng:NextNumber(-0.2, 0.2)
			local offset = Vector3.new(math.cos(angle) * 9, 2, math.sin(angle) * 9)
			local rarity = if rng:NextNumber() < 0.35 then "Legendary" else "Epic"
			spawnChest(ruinsCenter + offset, rarity, false, W.RuinsBuryHeight)
		end
	end

	for _ = 1, T.StartChests do
		spawnRandomChest(true)
	end
end

function TreasureService.init()
	local treasureFolder = Instance.new("Folder")
	treasureFolder.Name = "Treasures"
	treasureFolder.Parent = workspace
	folder = treasureFolder

	-- Doplňování truhel
	task.spawn(function()
		while true do
			task.wait(T.RespawnInterval)
			if WorldService.isReady() and countChests() < T.MaxChests then
				spawnRandomChest(false)
			end
		end
	end)
end

return TreasureService
