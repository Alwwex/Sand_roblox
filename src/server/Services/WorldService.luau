--[[
	WorldService – generuje poušť, tábor, ruiny a řeší kopání do terénu.

	Poušť je z Roblox Terrain (materiál Sand). Kopání = Terrain:FillBall(..., Air).
	Množství vykopaného písku se počítá přesně přes ReadVoxels (před/po).
	Pod pískem je skalní dno (Part) – to vykopat nejde.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

local W = Config.World
local Terrain = workspace.Terrain
local SAND = Enum.Material.Sand
local AIR = Enum.Material.Air
local VOXEL = 4
local CHUNK = 64
local THIN_SAND = 0.3 -- voxely s menším zaplněním po kopání mažeme (průsvitné slupky)

local WorldService = {}

local rng = Random.new()
local seed = 0
local ready = false
local totalSand = 0
local remainingSand = 0
local ruinsCenter: Vector3? = nil
local relicCFrame: CFrame? = nil
local ruinsModel: Model? = nil
local mapFolder: Folder? = nil
local spawnCFrames = { CFrame.new(0, W.CampTop + 4, 20) }
local maxY = math.ceil(W.MaxSand / VOXEL) * VOXEL

WorldService.Lobby = nil :: any -- kotvy z LobbyBuilderu (prodej, obchody, žebříčky...)
WorldService.SellPad = nil :: BasePart?

---------------------------------------------------------------------
-- Pomocné funkce
---------------------------------------------------------------------

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local makePart = Build.part
local cylinder = Build.cylinder

---------------------------------------------------------------------
-- Výšková mapa pouště
---------------------------------------------------------------------

local function rawHeight(x: number, z: number): number
	local s = W.DuneScale
	local n1 = math.noise(x / s, z / s, seed)
	local n2 = math.noise(x / (s * 0.45), z / (s * 0.45), seed + 17.31)
	local n3 = math.noise(x / (s * 0.16), z / (s * 0.16), seed + 41.77)
	local ridge = 1 - math.abs(n2) * 2.2
	return W.BaseSandHeight + n1 * W.DuneHeight * 1.4 + ridge * W.DuneHeight * 0.35 + n3 * 2.5
end

function WorldService.heightAt(x: number, z: number): number
	local h = rawHeight(x, z)

	-- Kopec nad ruinami (aby byly celé zasypané)
	if ruinsCenter then
		local d = Vector2.new(x - ruinsCenter.X, z - ruinsCenter.Z).Magnitude
		local blend = smoothstep((d - W.RuinsRadius) / 30)
		h = math.max(h, lerp(W.RuinsBuryHeight, h, blend))
	end

	-- Kolem tábora je písek zarovnaný s táborem
	local campDistance = math.max(math.abs(x), math.abs(z)) - W.CampHalf
	if campDistance < 48 then
		h = lerp(W.CampTop - 1, h, smoothstep(campDistance / 48))
	end

	return math.clamp(h, W.MinSand, W.MaxSand)
end

---------------------------------------------------------------------
-- Generování terénu
---------------------------------------------------------------------

local function generateTerrain()
	local half = W.Size / 2
	local nx, ny, nz = CHUNK / VOXEL, maxY / VOXEL, CHUNK / VOXEL
	local sum = 0

	for cx = -half, half - CHUNK, CHUNK do
		for cz = -half, half - CHUNK, CHUNK do
			local region = Region3.new(Vector3.new(cx, 0, cz), Vector3.new(cx + CHUNK, maxY, cz + CHUNK))
			local materials = table.create(nx)
			local occupancy = table.create(nx)

			for ix = 1, nx do
				local matX = table.create(ny)
				local occX = table.create(ny)
				for iy = 1, ny do
					matX[iy] = table.create(nz)
					occX[iy] = table.create(nz)
				end

				local wx = cx + (ix - 0.5) * VOXEL
				for iz = 1, nz do
					local wz = cz + (iz - 0.5) * VOXEL
					local h = WorldService.heightAt(wx, wz)
					-- Uvnitř skalního tábora žádný písek (byl by schovaný a nešel by "vidět")
					if math.max(math.abs(wx), math.abs(wz)) < W.CampHalf then
						h = 0
					end
					for iy = 1, ny do
						local bottom = (iy - 1) * VOXEL
						local occ = math.clamp((h - bottom) / VOXEL, 0, 1)
						if occ > 0.02 then
							matX[iy][iz] = SAND
							occX[iy][iz] = occ
							sum += occ
						else
							matX[iy][iz] = AIR
							occX[iy][iz] = 0
						end
					end
				end

				materials[ix] = matX
				occupancy[ix] = occX
			end

			Terrain:WriteVoxels(region, VOXEL, materials, occupancy)
			task.wait()
		end
	end

	totalSand = sum * Config.SandPerVoxel
	remainingSand = totalSand
end

---------------------------------------------------------------------
-- Statické části mapy: dno, okraje, tábor
---------------------------------------------------------------------

local function buildBoundaries(parent: Instance)
	local size = W.Size
	local half = size / 2
	local rockColor = Color3.fromRGB(196, 128, 82)

	makePart({
		Name = "Bedrock",
		Size = Vector3.new(size + 120, 4, size + 120),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Sandstone,
		Color = Color3.fromRGB(205, 150, 98),
		Parent = parent,
	})

	-- Útesy kolem pouště
	local wallHeight = 110
	local walls = {
		{ Vector3.new(0, wallHeight / 2 - 4, -half - 20), Vector3.new(size + 120, wallHeight, 40) },
		{ Vector3.new(0, wallHeight / 2 - 4, half + 20), Vector3.new(size + 120, wallHeight, 40) },
		{ Vector3.new(-half - 20, wallHeight / 2 - 4, 0), Vector3.new(40, wallHeight, size + 120) },
		{ Vector3.new(half + 20, wallHeight / 2 - 4, 0), Vector3.new(40, wallHeight, size + 120) },
	}
	for i, wall in walls do
		makePart({
			Name = "Cliff" .. i,
			Size = wall[2],
			Position = wall[1],
			Material = Enum.Material.Sandstone,
			Color = rockColor,
			Parent = parent,
		})
	end

	-- Náhodné balvany na útesech (vypadá to přirozeněji)
	local boulderRng = Random.new(1234)
	for _ = 1, 70 do
		local side = boulderRng:NextInteger(1, 4)
		local along = boulderRng:NextNumber(-half, half)
		local out = half + boulderRng:NextNumber(-2, 10)
		local position
		if side == 1 then
			position = Vector3.new(along, 0, -out)
		elseif side == 2 then
			position = Vector3.new(along, 0, out)
		elseif side == 3 then
			position = Vector3.new(-out, 0, along)
		else
			position = Vector3.new(out, 0, along)
		end
		local s = boulderRng:NextNumber(14, 36)
		position += Vector3.new(0, wallHeight - 4 - boulderRng:NextNumber(0, 30), 0)
		makePart({
			Name = "Boulder",
			Size = Vector3.new(s, s * boulderRng:NextNumber(0.6, 1.2), s * boulderRng:NextNumber(0.7, 1.3)),
			CFrame = CFrame.new(position) * CFrame.Angles(
				boulderRng:NextNumber(-0.4, 0.4),
				boulderRng:NextNumber(0, 6.28),
				boulderRng:NextNumber(-0.4, 0.4)
			),
			Material = Enum.Material.Sandstone,
			Color = rockColor:Lerp(Color3.fromRGB(150, 95, 60), boulderRng:NextNumber(0, 0.6)),
			Parent = parent,
		})
	end
end

---------------------------------------------------------------------
-- Zasypané ruiny
---------------------------------------------------------------------

local function buildRuins(parent: Instance, center: Vector3)
	if ruinsModel then
		ruinsModel:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "LostRuins"
	local stone = Color3.fromRGB(214, 180, 130)
	local darkStone = Color3.fromRGB(170, 130, 90)
	local r = W.RuinsRadius

	makePart({
		Name = "Floor",
		Size = Vector3.new(r * 2, 1, r * 2),
		Position = center + Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Limestone,
		Color = darkStone,
		Parent = model,
	})

	-- Kruh sloupů (některé jsou rozbité)
	local pillarCount = 10
	local ringRadius = r - 4
	local pillarTops = {}
	for i = 1, pillarCount do
		local angle = (i / pillarCount) * math.pi * 2
		local broken = rng:NextNumber() < 0.3
		local height = if broken then rng:NextNumber(5, 10) else 16
		local base = center + Vector3.new(math.cos(angle) * ringRadius, 1, math.sin(angle) * ringRadius)
		cylinder({
			Name = "Pillar",
			Height = height,
			Diameter = 3.2,
			Position = base + Vector3.new(0, height / 2, 0),
			Material = Enum.Material.Limestone,
			Color = stone,
			Parent = model,
		})
		makePart({
			Name = "PillarCap",
			Size = Vector3.new(4.2, 1, 4.2),
			Position = base + Vector3.new(0, height + 0.5, 0),
			Material = Enum.Material.Limestone,
			Color = darkStone,
			Parent = model,
		})
		pillarTops[i] = if broken then nil else base + Vector3.new(0, height + 1.5, 0)
	end

	-- Trámy mezi celými sloupy
	for i = 1, pillarCount do
		local a = pillarTops[i]
		local b = pillarTops[(i % pillarCount) + 1]
		if a and b then
			local mid = (a + b) / 2
			makePart({
				Name = "Lintel",
				Size = Vector3.new(2.5, 1.6, (a - b).Magnitude + 3),
				CFrame = CFrame.lookAt(mid, b),
				Material = Enum.Material.Limestone,
				Color = stone,
				Parent = model,
			})
		end
	end

	-- Oltář uprostřed se zářícími runami
	makePart({
		Name = "AltarStep",
		Size = Vector3.new(12, 1.5, 12),
		Position = center + Vector3.new(0, 1.75, 0),
		Material = Enum.Material.Limestone,
		Color = darkStone,
		Parent = model,
	})
	local altar = makePart({
		Name = "Altar",
		Size = Vector3.new(7, 3, 7),
		Position = center + Vector3.new(0, 4, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(235, 210, 160),
		Parent = model,
	})
	for _, offset in
		{ Vector3.new(0, 0, -3.55), Vector3.new(0, 0, 3.55), Vector3.new(-3.55, 0, 0), Vector3.new(3.55, 0, 0) }
	do
		local isX = offset.X ~= 0
		makePart({
			Name = "Rune",
			Size = if isX then Vector3.new(0.2, 0.6, 5) else Vector3.new(5, 0.6, 0.2),
			Position = altar.Position + offset,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(80, 220, 255),
			CanCollide = false,
			Parent = model,
		})
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(80, 220, 255)
	glow.Range = 20
	glow.Brightness = 2
	glow.Parent = altar

	-- Velká hlava sochy napůl zasypaná vedle oltáře
	local head = makePart({
		Name = "StatueHead",
		Size = Vector3.new(7, 8, 7),
		Position = center + Vector3.new(-9, 5, -9),
		Material = Enum.Material.Limestone,
		Color = stone,
		Parent = model,
	})
	makePart({
		Name = "StatueHeaddress",
		Size = Vector3.new(9, 3, 8),
		Position = head.Position + Vector3.new(0, 4.5, 0.5),
		Material = Enum.Material.Limestone,
		Color = Color3.fromRGB(60, 120, 200),
		Parent = model,
	})
	for _, x in { -1.6, 1.6 } do
		makePart({
			Name = "Eye",
			Size = Vector3.new(1.2, 0.6, 0.3),
			Position = head.Position + Vector3.new(x, 1, -3.6),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 60),
			CanCollide = false,
			Parent = model,
		})
	end

	model.Parent = parent
	ruinsModel = model
	relicCFrame = CFrame.new(altar.Position + Vector3.new(0, 3, 0))
end

---------------------------------------------------------------------
-- Osvětlení – teplá pouštní atmosféra
---------------------------------------------------------------------

function WorldService.setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 90, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 128, 105)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.1

	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("Sky")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("BloomEffect")
		then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(232, 205, 165)
	atmosphere.Decay = Color3.fromRGB(205, 150, 100)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 16
	sky.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Saturation = 0.15
	colorCorrection.Contrast = 0.08
	colorCorrection.TintColor = Color3.fromRGB(255, 246, 232)
	colorCorrection.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	Terrain:SetMaterialColor(SAND, Color3.fromRGB(228, 192, 130))
end

---------------------------------------------------------------------
-- Veřejné API
---------------------------------------------------------------------

function WorldService.isReady(): boolean
	return ready
end

function WorldService.setReady(value: boolean)
	ready = value
	workspace:SetAttribute("WorldReady", value)
end

function WorldService.getSpawnCFrame(): CFrame
	local base = spawnCFrames[rng:NextInteger(1, #spawnCFrames)]
	return base + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
end

-- Je bod uvnitř lobby (tam se kopat nesmí)?
function WorldService.isInLobby(position: Vector3): boolean
	return math.max(math.abs(position.X), math.abs(position.Z)) < W.CampHalf + 1 and position.Y > W.CampTop - 8
end

-- Bezpečný teleport do tábora (při zapnutém StreamingEnabled nejdřív načte okolí)
function WorldService.teleportToCamp(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local target = WorldService.getSpawnCFrame()
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 5)
	end)
	if player.Character == character then
		character:PivotTo(target)
	end
end

function WorldService.getRuins(): (Vector3?, CFrame?)
	return ruinsCenter, relicCFrame
end

function WorldService.getMapFolder(): Folder
	return mapFolder :: Folder
end

function WorldService.getClearedFraction(): number
	if totalSand <= 0 then
		return 0
	end
	return math.clamp(1 - remainingSand / totalSand, 0, 1)
end

function WorldService.inBounds(position: Vector3): boolean
	local half = W.Size / 2
	return math.abs(position.X) <= half
		and math.abs(position.Z) <= half
		and position.Y >= -4
		and position.Y <= maxY + 20
end

-- Aktuální výška povrchu (raycast jen do terénu)
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { Terrain }

function WorldService.surfaceHeight(x: number, z: number): number
	local result = workspace:Raycast(Vector3.new(x, maxY + 50, z), Vector3.new(0, -(maxY + 60), 0), terrainParams)
	if result then
		return result.Position.Y
	end
	return 0
end

local function sumSand(region: Region3): number
	local materials, occupancies = Terrain:ReadVoxels(region, VOXEL)
	local size = materials.Size
	local total = 0
	for x = 1, size.X do
		local matX, occX = materials[x], occupancies[x]
		for y = 1, size.Y do
			local matY, occY = matX[y], occX[y]
			for z = 1, size.Z do
				if matY[z] == SAND then
					total += occY[z]
				end
			end
		end
	end
	return total
end

-- Vykope kouli písku. Vrací množství písku (už přepočtené přes SandPerVoxel).
-- Po vykopání se "uhladí" tenké zbytky písku: smooth terrain z nich jinak dělá
-- průsvitné slupky a díry, přes které jde vidět.
function WorldService.digSphere(center: Vector3, radius: number): number
	local padding = Vector3.one * (radius + VOXEL)
	local region = Region3.new(center - padding, center + padding):ExpandToGrid(VOXEL)
	local before = sumSand(region)
	if before <= 0 then
		return 0
	end
	Terrain:FillBall(center, radius, AIR)

	local materials, occupancies = Terrain:ReadVoxels(region, VOXEL)
	local size = materials.Size
	local minCorner = region.CFrame.Position - region.Size / 2
	local snapRadius = radius + VOXEL
	local after = 0
	local changed = false
	for x = 1, size.X do
		local matX, occX = materials[x], occupancies[x]
		local wx = minCorner.X + (x - 0.5) * VOXEL
		for y = 1, size.Y do
			local matY, occY = matX[y], occX[y]
			local wy = minCorner.Y + (y - 0.5) * VOXEL
			for z = 1, size.Z do
				if matY[z] == SAND then
					local occ = occY[z]
					if occ < THIN_SAND then
						local wz = minCorner.Z + (z - 0.5) * VOXEL
						if (Vector3.new(wx, wy, wz) - center).Magnitude <= snapRadius then
							matY[z] = AIR
							occY[z] = 0
							occ = 0
							changed = true
						end
					end
					after += occ
				end
			end
		end
	end
	if changed then
		Terrain:WriteVoxels(region, VOXEL, materials, occupancies)
	end

	local removed = math.max(0, before - after) * Config.SandPerVoxel
	remainingSand = math.max(0, remainingSand - removed)
	return removed
end

-- Kolik písku je nad daným bodem (0 = odkryté, 1 = plně zasypané)
function WorldService.coverAt(position: Vector3): number
	local min = position + Vector3.new(-3, 0.5, -3)
	local max = position + Vector3.new(3, 6, 3)
	local region = Region3.new(min, max):ExpandToGrid(VOXEL)
	local materials, occupancies = Terrain:ReadVoxels(region, VOXEL)
	local size = materials.Size
	local total, count = 0, 0
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				count += 1
				if materials[x][y][z] == SAND then
					total += occupancies[x][y][z]
				end
			end
		end
	end
	if count == 0 then
		return 0
	end
	return total / count
end

local function pickRuinsCenter()
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(W.RuinsMinDistance, W.RuinsMaxDistance)
	local maxDistance = W.Size / 2 - W.RuinsRadius - 12
	distance = math.min(distance, maxDistance)
	return Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

-- (Znovu)vygeneruje poušť a ruiny
function WorldService.regenerate()
	seed = rng:NextNumber(1, 10000)
	ruinsCenter = pickRuinsCenter()
	buildRuins(mapFolder :: Folder, ruinsCenter :: Vector3)
	generateTerrain()
	LobbyBuilder.fillWater()
end

function WorldService.init()
	WorldService.setReady(false)
	WorldService.setupLighting()

	local folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace
	mapFolder = folder

	Terrain:Clear()
	buildBoundaries(folder)
	local lobby = LobbyBuilder.build(folder)
	WorldService.Lobby = lobby
	WorldService.SellPad = lobby.SellPad
	spawnCFrames = lobby.Spawns
	WorldService.regenerate()
end

return WorldService
