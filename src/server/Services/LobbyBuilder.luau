--[[
	LobbyBuilder – postaví lobby „Oasis Town" uprostřed pouště.

	Rozložení (sever = +Z, východ = +X):
	  střed ....... oáza s vodou a zlatou sochou kopáče, spawny kolem
	  západ ....... trh: TOOL SHOP, SELL STATION (pavilon), BACKPACKS
	  východ ...... REBIRTH chrám, žebříčky (3 tabule), socha hráče č. 1
	  jih ......... GAMEPASS stánky, VIP LOUNGE (jen pro VIP)
	  sever ....... DAILY REWARD truhla, HOW TO PLAY tabule
	  okraje ...... hradby se 4 branami a rampami dolů do pouště

	Vrací tabulku "kotev" (pozice a party), které používají ostatní služby.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ToolFactory = require(ReplicatedStorage.Shared.ToolFactory)
local Build = require(script.Parent.Build)

local W = Config.World
local HALF = W.CampHalf
local TOP = W.CampTop
local FLOOR = TOP + 0.4
local POOL = 12 -- polovina šířky jezírka

local SAND_LIGHT = Color3.fromRGB(236, 204, 150)
local SAND_DARK = Color3.fromRGB(214, 170, 112)
local STONE = Color3.fromRGB(205, 150, 98)
local WOOD = Color3.fromRGB(150, 100, 58)
local GOLD = Color3.fromRGB(255, 200, 60)
local CYAN = Color3.fromRGB(80, 220, 255)

local LobbyBuilder = {}

local P = Build.part

---------------------------------------------------------------------
-- Základna, dlažba, hradby, brány
---------------------------------------------------------------------

local function buildBase(lobby: Model)
	-- Plošina je z 4 bloků + dno, aby uprostřed zůstala jáma na vodu
	local blocks = {
		{ Vector3.new(0, TOP / 2, (HALF + POOL) / 2), Vector3.new(HALF * 2, TOP, HALF - POOL) },
		{ Vector3.new(0, TOP / 2, -(HALF + POOL) / 2), Vector3.new(HALF * 2, TOP, HALF - POOL) },
		{ Vector3.new((HALF + POOL) / 2, TOP / 2, 0), Vector3.new(HALF - POOL, TOP, POOL * 2) },
		{ Vector3.new(-(HALF + POOL) / 2, TOP / 2, 0), Vector3.new(HALF - POOL, TOP, POOL * 2) },
		{ Vector3.new(0, 12, 0), Vector3.new(POOL * 2, 24, POOL * 2) },
	}
	for i, b in blocks do
		P({
			Name = "Plateau" .. i,
			Position = b[1],
			Size = b[2],
			Material = Enum.Material.Sandstone,
			Color = STONE,
			Parent = lobby,
		})
	end

	-- Dlažba 8x8 ve dvou odstínech
	local floor = Build.model("Floor", lobby)
	for ix = -7, 6 do
		for iz = -7, 6 do
			local x = ix * 8 + 4
			local z = iz * 8 + 4
			if math.abs(x) > POOL + 2 or math.abs(z) > POOL + 2 then
				local light = (ix + iz) % 2 == 0
				P({
					Name = "Tile",
					Size = Vector3.new(7.9, 0.4, 7.9),
					Position = Vector3.new(x, TOP + 0.2, z),
					Material = if light then Enum.Material.Limestone else Enum.Material.Sandstone,
					Color = if light then SAND_LIGHT else SAND_DARK,
					Parent = floor,
				})
			end
		end
	end
	-- okraj dlažby kolem jezírka
	for _, d in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		local alongX = d[1] == 0
		P({
			Name = "PoolEdge",
			Size = if alongX then Vector3.new(POOL * 2 + 8, 0.4, 2) else Vector3.new(2, 0.4, POOL * 2 + 4),
			Position = Vector3.new(d[1] * (POOL + 1), TOP + 0.2, d[2] * (POOL + 1)),
			Material = Enum.Material.Limestone,
			Color = SAND_LIGHT,
			Parent = floor,
		})
	end
end

local function buildWalls(lobby: Model)
	local walls = Build.model("Walls", lobby)
	local gate = 8
	local wallH = 4
	for _, side in { "N", "S", "E", "W" } do
		for _, sign in { -1, 1 } do
			local length = HALF - gate
			local mid = sign * (gate + length / 2)
			local position, size
			if side == "N" or side == "S" then
				position = Vector3.new(mid, FLOOR + wallH / 2, if side == "N" then HALF - 1 else -HALF + 1)
				size = Vector3.new(length, wallH, 2)
			else
				position = Vector3.new(if side == "E" then HALF - 1 else -HALF + 1, FLOOR + wallH / 2, mid)
				size = Vector3.new(2, wallH, length)
			end
			P({
				Name = "Wall",
				Position = position,
				Size = size,
				Material = Enum.Material.Sandstone,
				Color = STONE,
				Parent = walls,
			})
			-- cimbuří
			for t = 1, math.floor(length / 4) do
				local offset = -length / 2 + (t - 0.5) * 4
				local merlon = position
					+ (if side == "N" or side == "S" then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset))
				P({
					Name = "Merlon",
					Size = Vector3.new(2, 1.6, 2),
					Position = merlon + Vector3.new(0, wallH / 2 + 0.8, 0),
					Material = Enum.Material.Sandstone,
					Color = STONE:Lerp(Color3.new(1, 1, 1), 0.08),
					Parent = walls,
				})
			end
		end
	end
end

local function buildGates(lobby: Model)
	local gates = Build.model("Gates", lobby)
	local dirs = {
		{ Vector3.new(0, 0, 1), "N" },
		{ Vector3.new(0, 0, -1), "S" },
		{ Vector3.new(1, 0, 0), "E" },
		{ Vector3.new(-1, 0, 0), "W" },
	}
	for _, info in dirs do
		local dir = info[1]
		local side = Vector3.new(dir.Z, 0, -dir.X)
		local edge = dir * (HALF - 1)
		for _, s in { -1, 1 } do
			local base = edge + side * (s * 9.5)
			P({
				Name = "GatePillar",
				Size = Vector3.new(3.2, 15, 3.2),
				Position = Vector3.new(base.X, FLOOR + 7.5, base.Z),
				Material = Enum.Material.Sandstone,
				Color = STONE:Lerp(Color3.new(0, 0, 0), 0.06),
				Parent = gates,
			})
			P({
				Name = "GateCap",
				Size = Vector3.new(4, 1.2, 4),
				Position = Vector3.new(base.X, FLOOR + 15.6, base.Z),
				Material = Enum.Material.Sandstone,
				Color = GOLD,
				Parent = gates,
			})
		end
		local lintelPos = Vector3.new(edge.X, FLOOR + 14, edge.Z)
		local lintel = P({
			Name = "GateLintel",
			Size = Vector3.new(22, 3, 3.4),
			CFrame = CFrame.lookAt(lintelPos, lintelPos + dir),
			Material = Enum.Material.Sandstone,
			Color = STONE,
			Parent = gates,
		})
		-- Cedule: zvenku OASIS TOWN, zevnitř TO THE DESERT
		local signPart = P({
			Name = "GateSign",
			Size = Vector3.new(16, 2.6, 3.6),
			CFrame = lintel.CFrame,
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(120, 78, 42),
			Parent = gates,
		})
		Build.sign(signPart, "OASIS TOWN", Color3.fromRGB(255, 214, 110), { Enum.NormalId.Front })
		Build.sign(signPart, "TO THE DESERT", Color3.fromRGB(120, 235, 255), { Enum.NormalId.Back })
		for _, s in { -1, 1 } do
			local bannerBase = edge - dir * 2.5 + side * (s * 9.5)
			Build.banner(
				gates,
				Vector3.new(bannerBase.X, FLOOR, bannerBase.Z),
				if s < 0 then Color3.fromRGB(220, 70, 50) else Color3.fromRGB(40, 110, 200),
				-dir
			)
		end

		-- Rampa dolů do pouště (odkryje se, až hráči vykopou písek u hradeb)
		local run = TOP * 1.7
		local topPoint = dir * HALF + Vector3.new(0, TOP, 0)
		local bottomPoint = dir * (HALF + run)
		local mid = (topPoint + bottomPoint) / 2
		local ramp = P({
			Name = "Ramp",
			Size = Vector3.new(14, 1.5, (topPoint - bottomPoint).Magnitude + 2),
			CFrame = CFrame.lookAt(mid, topPoint),
			Material = Enum.Material.WoodPlanks,
			Color = WOOD,
			Parent = gates,
		})
		for _, s in { -1, 1 } do
			P({
				Name = "RampRail",
				Size = Vector3.new(0.6, 1.2, ramp.Size.Z),
				CFrame = ramp.CFrame * CFrame.new(s * 6.8, 1.3, 0),
				Material = Enum.Material.Wood,
				Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.2),
				Parent = gates,
			})
		end
	end
end

---------------------------------------------------------------------
-- Oáza uprostřed
---------------------------------------------------------------------

local function buildOasis(lobby: Model)
	local oasis = Build.model("Oasis", lobby)
	-- obruba
	for _, d in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		local alongX = d[1] == 0
		P({
			Name = "Rim",
			Size = if alongX then Vector3.new(POOL * 2 + 4, 1.4, 2) else Vector3.new(2, 1.4, POOL * 2),
			Position = Vector3.new(d[1] * (POOL + 1), FLOOR + 0.5, d[2] * (POOL + 1)),
			Material = Enum.Material.Limestone,
			Color = Color3.fromRGB(240, 220, 180),
			Parent = oasis,
		})
	end
	-- ostrůvek se zlatou sochou kopáče
	Build.cylinder({
		Name = "StatueIsland",
		Height = 9.5,
		Diameter = 8,
		Position = Vector3.new(0, 24 + 4.75, 0),
		Material = Enum.Material.Limestone,
		Color = Color3.fromRGB(235, 212, 170),
		Parent = oasis,
	})
	Build.cylinder({
		Name = "StatueBase",
		Height = 1.2,
		Diameter = 6,
		Position = Vector3.new(0, 34.1, 0),
		Material = Enum.Material.Metal,
		Color = GOLD,
		Parent = oasis,
	})
	local statue = Build.npc(oasis, CFrame.new(0, 34.7, 0) * CFrame.Angles(0, math.rad(180), 0), {
		Skin = GOLD,
		Shirt = GOLD,
		Pants = GOLD,
		Hat = GOLD,
		Material = Enum.Material.Metal,
	}, nil)
	statue.Name = "GoldenDigger"
	local shovel = ToolFactory.createModel("GoldenShovel")
	shovel:PivotTo(CFrame.new(2.2, 38, -0.6) * CFrame.Angles(math.rad(-160), 0, math.rad(10)))
	shovel.Parent = statue
	Build.sparkles(statue.PrimaryPart :: BasePart, GOLD, 4)
	-- lekníny
	for i = 1, 6 do
		local angle = i * 1.05
		local r = 7 + (i % 2) * 2.5
		Build.cylinder({
			Name = "LilyPad",
			Height = 0.15,
			Diameter = 1.8,
			Position = Vector3.new(math.cos(angle) * r, TOP + 0.05, math.sin(angle) * r),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(70, 160, 70),
			CanCollide = false,
			Parent = oasis,
		})
	end
	-- palmy v rozích jezírka
	for _, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		Build.palm(oasis, Vector3.new(c[1] * (POOL + 3), FLOOR, c[2] * (POOL + 3)), c[1] * 0.12, 7)
	end
end

---------------------------------------------------------------------
-- Stánky na trhu
---------------------------------------------------------------------

local function displayTool(parent: Instance, toolId: string, cframe: CFrame)
	local model = ToolFactory.createModel(toolId)
	model:PivotTo(cframe)
	model.Parent = parent
	return model
end

local function buildStall(
	parent: Instance,
	center: Vector3,
	facing: Vector3,
	roofA: Color3,
	roofB: Color3,
	title: string,
	npcName: string,
	npcColors
)
	local stall = Build.model(title, parent)
	local frame = CFrame.lookAt(center, center + facing)
	local w, h = 16, 9
	-- podlaha a sloupy
	P({
		Name = "StallFloor",
		Size = Vector3.new(w + 2, 0.5, 10),
		CFrame = frame * CFrame.new(0, 0.25, 0.5),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD,
		Parent = stall,
	})
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -3.5, 4.5 } do
			local postH = if z < 0 then h - 1.5 else h + 1
			P({
				Name = "Post",
				Size = Vector3.new(0.8, postH, 0.8),
				CFrame = frame * CFrame.new(x, postH / 2, z),
				Material = Enum.Material.Wood,
				Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.25),
				Parent = stall,
			})
		end
	end
	-- zadní stěna s regály
	P({
		Name = "BackWall",
		Size = Vector3.new(w, h, 0.6),
		CFrame = frame * CFrame.new(0, h / 2, 4.6),
		Material = Enum.Material.WoodPlanks,
		Color = WOOD:Lerp(Color3.new(1, 1, 1), 0.1),
		Parent = stall,
	})
	for _, y in { 3.2, 6 } do
		P({
			Name = "Shelf",
			Size = Vector3.new(w - 1, 0.3, 1.6),
			CFrame = frame * CFrame.new(0, y, 3.6),
			Material = Enum.Material.Wood,
			Color = WOOD,
			Parent = stall,
		})
	end
	-- pruhovaná markýza
	local strips = 8
	for i = 1, strips do
		local x = -w / 2 + (i - 0.5) * (w / strips)
		P({
			Name = "Awning",
			Size = Vector3.new(w / strips + 0.02, 0.25, 10.5),
			CFrame = frame * CFrame.new(x, h - 0.2, 0.3) * CFrame.Angles(math.rad(-14), 0, 0),
			Material = Enum.Material.Fabric,
			Color = if i % 2 == 0 then roofA else roofB,
			CanCollide = false,
			Parent = stall,
		})
	end
	-- pult
	local counter = P({
		Name = "Counter",
		Size = Vector3.new(w - 2, 3.4, 2.4),
		CFrame = frame * CFrame.new(0, 1.7, -2.6),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(176, 120, 66),
		Parent = stall,
	})
	P({
		Name = "CounterTop",
		Size = Vector3.new(w - 1.4, 0.3, 2.8),
		CFrame = frame * CFrame.new(0, 3.55, -2.6),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(120, 78, 42),
		Parent = stall,
	})
	Build.npc(stall, frame * CFrame.new(0, 0.5, 0.8), npcColors, npcName)
	Build.billboard(counter, title, Color3.fromRGB(255, 236, 170), Vector2.new(14, 3), h + 1.5)
	return stall, counter, frame
end

local function buildMarket(lobby: Model, anchors)
	local market = Build.model("Market", lobby)

	-- TOOL SHOP
	local tools, toolCounter, toolFrame = buildStall(
		market,
		Vector3.new(-45, FLOOR, -26),
		Vector3.new(1, 0, 0),
		Color3.fromRGB(225, 60, 50),
		Color3.fromRGB(255, 245, 230),
		"TOOL SHOP",
		"Tool Trader",
		{ Shirt = Color3.fromRGB(200, 70, 50), Hat = Color3.fromRGB(90, 60, 35), Beard = Color3.fromRGB(80, 50, 30) }
	)
	displayTool(tools, "Spoon", toolFrame * CFrame.new(-5, 4.1, -2.6) * CFrame.Angles(math.rad(-90), 0, math.rad(20)))
	displayTool(
		tools,
		"Shovel",
		toolFrame * CFrame.new(5.5, 4.2, -2.6) * CFrame.Angles(math.rad(-90), 0, math.rad(-70))
	)
	displayTool(tools, "Vacuum", toolFrame * CFrame.new(-4, 7, 3.4) * CFrame.Angles(0, math.rad(180), 0))
	displayTool(tools, "Trowel", toolFrame * CFrame.new(4, 6.8, 3.4) * CFrame.Angles(0, math.rad(180), 0))
	anchors.ToolCounter = toolCounter

	-- BACKPACKS
	local bags, bagCounter, bagFrame = buildStall(
		market,
		Vector3.new(-45, FLOOR, 28),
		Vector3.new(1, 0, 0),
		Color3.fromRGB(40, 110, 210),
		Color3.fromRGB(255, 245, 230),
		"BACKPACKS",
		"Bag Seller",
		{ Shirt = Color3.fromRGB(50, 110, 200), Hat = Color3.fromRGB(240, 240, 240) }
	)
	for i, x in { -5, -1.5, 2, 5.5 } do
		Build.ellipsoid({
			Name = "Sack",
			Size = Vector3.new(2.2, 2.6 + i * 0.2, 2),
			CFrame = bagFrame * CFrame.new(x, 4.1 + 1.3, -2.6),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(214, 186, 130):Lerp(Color3.fromRGB(170, 130, 80), i / 4),
			Parent = bags,
		})
	end
	Build.crate(bags, (bagFrame * CFrame.new(-7, 0.5, -5.5)).Position, 2.5, 0.3)
	Build.crate(bags, (bagFrame * CFrame.new(-6.4, 3, -5.4)).Position, 2, 0.8)
	anchors.BackpackCounter = bagCounter

	-- SELL STATION (pavilon se zlatou plochou)
	local sell = Build.model("SellStation", market)
	local c = Vector3.new(-38, FLOOR, 0)
	P({
		Name = "SellFloor",
		Size = Vector3.new(24, 0.6, 24),
		Position = c + Vector3.new(0, 0.3, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(245, 228, 190),
		Parent = sell,
	})
	for _, x in { -10, 10 } do
		for _, z in { -10, 10 } do
			Build.cylinder({
				Name = "Column",
				Height = 13,
				Diameter = 2.2,
				Position = c + Vector3.new(x, 7.1, z),
				Material = Enum.Material.Marble,
				Color = Color3.fromRGB(250, 238, 210),
				Parent = sell,
			})
			P({
				Name = "ColumnCap",
				Size = Vector3.new(3, 0.8, 3),
				Position = c + Vector3.new(x, 13.9, z),
				Material = Enum.Material.Metal,
				Color = GOLD,
				Parent = sell,
			})
		end
	end
	P({
		Name = "Roof1",
		Size = Vector3.new(26, 1, 26),
		Position = c + Vector3.new(0, 14.8, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(250, 238, 210),
		Parent = sell,
	})
	P({
		Name = "Roof2",
		Size = Vector3.new(20, 1, 20),
		Position = c + Vector3.new(0, 15.8, 0),
		Material = Enum.Material.Sandstone,
		Color = Color3.fromRGB(230, 120, 60),
		Parent = sell,
	})
	P({
		Name = "Roof3",
		Size = Vector3.new(13, 1, 13),
		Position = c + Vector3.new(0, 16.8, 0),
		Material = Enum.Material.Sandstone,
		Color = Color3.fromRGB(230, 120, 60),
		Parent = sell,
	})
	local finial = Build.ellipsoid({
		Name = "Finial",
		Size = Vector3.new(3, 3, 3),
		Position = c + Vector3.new(0, 18.6, 0),
		Material = Enum.Material.Metal,
		Color = GOLD,
		Parent = sell,
	})
	Build.light(finial, GOLD, 18, 1)
	local pad = P({
		Name = "SellPad",
		Size = Vector3.new(14, 0.5, 14),
		Position = c + Vector3.new(0, 0.85, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 196, 60),
		Parent = sell,
	})
	Build.sparkles(pad, Color3.fromRGB(255, 220, 90), 10)
	Build.billboard(pad, "SELL SAND", Color3.fromRGB(255, 225, 90), Vector2.new(16, 4), 22)
	Build.npc(sell, CFrame.new(c + Vector3.new(-9.5, 0.6, 0)) * CFrame.Angles(0, math.rad(-90), 0), {
		Shirt = Color3.fromRGB(240, 190, 60),
		Hat = Color3.fromRGB(150, 40, 40),
		Beard = Color3.fromRGB(230, 230, 230),
	}, "Sand Buyer")
	for i = 1, 5 do
		Build.ellipsoid({
			Name = "CoinPile",
			Size = Vector3.new(2.4 - i * 0.2, 1.2, 2.4 - i * 0.2),
			Position = c + Vector3.new(-9 + (i % 2) * 2, 0.9 + i * 0.25, -8 + i * 0.6),
			Material = Enum.Material.Metal,
			Color = GOLD,
			CanCollide = false,
			Parent = sell,
		})
	end
	anchors.SellPad = pad

	-- dekorace mezi stánky
	Build.carpet(market, Vector3.new(-33, FLOOR, -26), Vector2.new(8, 12), Color3.fromRGB(170, 40, 50))
	Build.carpet(market, Vector3.new(-33, FLOOR, 28), Vector2.new(8, 12), Color3.fromRGB(40, 70, 160))
	Build.barrel(market, Vector3.new(-52, FLOOR, -15))
	Build.barrel(market, Vector3.new(-54.5, FLOOR, -13))
	Build.crate(market, Vector3.new(-53, FLOOR, 15), 3, 0.2)
	Build.crate(market, Vector3.new(-53, FLOOR + 3, 15.4), 2.2, 0.9)
	Build.pot(market, Vector3.new(-34, FLOOR, -15))
	Build.pot(market, Vector3.new(-34, FLOOR, 15), Color3.fromRGB(80, 140, 170))
end

---------------------------------------------------------------------
-- Rebirth chrám, žebříčky, socha
---------------------------------------------------------------------

local function buildTemple(lobby: Model, anchors)
	local temple = Build.model("RebirthTemple", lobby)
	local c = Vector3.new(42, FLOOR, 34)
	for i, s in { 24, 20, 16 } do
		P({
			Name = "Step",
			Size = Vector3.new(s, 1, s),
			Position = c + Vector3.new(0, i - 0.5, 0),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(240, 232, 215),
			Parent = temple,
		})
	end
	for _, x in { -6, 6 } do
		for _, z in { -6, 6 } do
			Build.cylinder({
				Name = "Column",
				Height = 12,
				Diameter = 2.2,
				Position = c + Vector3.new(x, 9, z),
				Material = Enum.Material.Marble,
				Color = Color3.fromRGB(245, 240, 230),
				Parent = temple,
			})
		end
	end
	P({
		Name = "Roof",
		Size = Vector3.new(18, 1.2, 18),
		Position = c + Vector3.new(0, 15.6, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(240, 232, 215),
		Parent = temple,
	})
	P({
		Name = "RoofTrim",
		Size = Vector3.new(18.4, 0.5, 18.4),
		Position = c + Vector3.new(0, 15, 0),
		Material = Enum.Material.Neon,
		Color = CYAN,
		Parent = temple,
	})
	P({
		Name = "Roof2",
		Size = Vector3.new(12, 1.2, 12),
		Position = c + Vector3.new(0, 16.8, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(240, 232, 215),
		Parent = temple,
	})
	local crystal = P({
		Name = "Crystal",
		Size = Vector3.new(2.5, 2.5, 2.5),
		CFrame = CFrame.new(c + Vector3.new(0, 19.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = CYAN,
		Parent = temple,
	})
	Build.light(crystal, CYAN, 22, 1.5)
	local obelisk = P({
		Name = "Obelisk",
		Size = Vector3.new(3, 9, 3),
		Position = c + Vector3.new(0, 7.5, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(255, 215, 120),
		Parent = temple,
	})
	P({
		Name = "ObeliskTip",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(c + Vector3.new(0, 12.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = CYAN,
		Parent = temple,
	})
	Build.sparkles(obelisk, CYAN, 8)
	Build.billboard(obelisk, "REBIRTH", Color3.fromRGB(150, 235, 255), Vector2.new(12, 3), 14)
	anchors.RebirthAltar = obelisk
end

local function buildLeaderboards(lobby: Model, anchors)
	local boards = Build.model("Leaderboards", lobby)
	anchors.Boards = {}
	local list = {
		{ "Coins", Vector3.new(54, FLOOR, -24), Color3.fromRGB(255, 196, 40) },
		{ "Sand", Vector3.new(54, FLOOR, -6), Color3.fromRGB(240, 170, 80) },
		{ "Rebirths", Vector3.new(54, FLOOR, 12), Color3.fromRGB(80, 220, 255) },
	}
	for _, info in list do
		local base = info[2]
		local center = base + Vector3.new(0, 11, 0)
		local frame = CFrame.lookAt(center, center + Vector3.new(-1, 0, 0))
		local board = P({
			Name = "Board" .. info[1],
			Size = Vector3.new(14, 18, 1),
			CFrame = frame,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(45, 28, 15),
			Parent = boards,
		})
		P({
			Name = "BoardFrame",
			Size = Vector3.new(15, 19, 0.8),
			CFrame = frame * CFrame.new(0, 0, 0.3),
			Material = Enum.Material.Wood,
			Color = WOOD,
			Parent = boards,
		})
		P({
			Name = "BoardTop",
			Size = Vector3.new(16, 1.2, 2),
			CFrame = frame * CFrame.new(0, 10, 0),
			Material = Enum.Material.Metal,
			Color = info[3],
			Parent = boards,
		})
		for _, s in { -1, 1 } do
			P({
				Name = "BoardLeg",
				Size = Vector3.new(1, 3, 1),
				CFrame = frame * CFrame.new(s * 6, -10, 0.3),
				Material = Enum.Material.Wood,
				Color = WOOD,
				Parent = boards,
			})
		end
		Build.light(board, info[3], 14, 0.6)
		anchors.Boards[info[1]] = board
	end

	-- Podstavec pro sochu hráče č. 1
	local pedestalPos = Vector3.new(42, FLOOR, -44)
	Build.cylinder({
		Name = "Pedestal",
		Height = 3,
		Diameter = 8,
		Position = pedestalPos + Vector3.new(0, 1.5, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(245, 235, 215),
		Parent = boards,
	})
	local ring = Build.cylinder({
		Name = "PedestalRing",
		Height = 0.4,
		Diameter = 8.4,
		Position = pedestalPos + Vector3.new(0, 3, 0),
		Material = Enum.Material.Neon,
		Color = GOLD,
		Parent = boards,
	})
	Build.sparkles(ring, GOLD, 6)
	local plaque = P({
		Name = "Plaque",
		Size = Vector3.new(8, 2, 0.4),
		CFrame = CFrame.lookAt(pedestalPos + Vector3.new(-3, 1.6, 3), pedestalPos + Vector3.new(-30, 1.6, 30)),
		Material = Enum.Material.Metal,
		Color = GOLD,
		Parent = boards,
	})
	Build.sign(plaque, "#1 RICHEST", Color3.fromRGB(70, 40, 10), { Enum.NormalId.Front })
	anchors.StatueCFrame = CFrame.lookAt(pedestalPos + Vector3.new(0, 3.2, 0), Vector3.new(0, FLOOR + 3.2, 0))
	anchors.StatueParent = boards
end

---------------------------------------------------------------------
-- Gamepass stánky a VIP salonek
---------------------------------------------------------------------

local function buildPassPlaza(lobby: Model, anchors)
	local plaza = Build.model("GamepassPlaza", lobby)
	anchors.PassStands = {}
	local colors = {
		VIP = GOLD,
		DoubleCoins = Color3.fromRGB(255, 170, 40),
		AutoSell = Color3.fromRGB(255, 230, 60),
		TreasureRadar = Color3.fromRGB(80, 230, 140),
		BigBackpack = Color3.fromRGB(80, 160, 255),
		FastDig = Color3.fromRGB(255, 90, 90),
	}
	local count = #Config.GamePassOrder
	for i, key in Config.GamePassOrder do
		local pass = Config.GamePasses[key]
		local x = -26 + (i - 1) * (52 / (count - 1))
		local base = Vector3.new(x, FLOOR, -44 + math.abs(i - (count + 1) / 2) * 1.5)
		local color = colors[key] or GOLD
		Build.cylinder({
			Name = "Stand",
			Height = 3,
			Diameter = 5,
			Position = base + Vector3.new(0, 1.5, 0),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(245, 235, 215),
			Parent = plaza,
		})
		Build.cylinder({
			Name = "StandRing",
			Height = 0.3,
			Diameter = 5.3,
			Position = base + Vector3.new(0, 3, 0),
			Material = Enum.Material.Neon,
			Color = color,
			Parent = plaza,
		})
		local orb = Build.ellipsoid({
			Name = "Orb_" .. key,
			Size = Vector3.new(2.6, 2.6, 2.6),
			Position = base + Vector3.new(0, 5.5, 0),
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = 0.35,
			CanCollide = false,
			Parent = plaza,
		})
		Build.light(orb, color, 10, 0.8)
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromScale(6, 5)
		billboard.StudsOffset = Vector3.new(0, 3.6, 0)
		billboard.MaxDistance = 90
		billboard.LightInfluence = 0
		billboard.Parent = orb
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 0.5)
		icon.BackgroundTransparency = 1
		icon.Text = pass.Icon
		icon.TextScaled = true
		icon.Parent = billboard
		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromScale(0, 0.5)
		name.Size = UDim2.fromScale(1, 0.3)
		name.BackgroundTransparency = 1
		name.Text = pass.Name
		name.Font = Enum.Font.LuckiestGuy
		name.TextScaled = true
		name.TextColor3 = color
		name.Parent = billboard
		Build.stroke(name, 3)
		local price = Instance.new("TextLabel")
		price.Name = "Price"
		price.Position = UDim2.fromScale(0.15, 0.8)
		price.Size = UDim2.fromScale(0.7, 0.2)
		price.BackgroundTransparency = 1
		price.Text = "R$ " .. pass.Price
		price.Font = Enum.Font.FredokaOne
		price.TextScaled = true
		price.TextColor3 = Color3.new(1, 1, 1)
		price.Parent = billboard
		Build.stroke(price, 2.5)
		anchors.PassStands[key] = orb
	end
	local arch = P({
		Name = "PassSign",
		Size = Vector3.new(24, 3, 0.6),
		CFrame = CFrame.lookAt(Vector3.new(0, FLOOR + 13, -52), Vector3.new(0, FLOOR + 13, 0)),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(110, 60, 160),
		Parent = plaza,
	})
	Build.sign(arch, "GAMEPASSES", Color3.fromRGB(255, 225, 110), { Enum.NormalId.Front })
	for _, s in { -1, 1 } do
		P({
			Name = "PassSignPost",
			Size = Vector3.new(1, 13, 1),
			Position = Vector3.new(s * 11, FLOOR + 6.5, -52.3),
			Material = Enum.Material.Wood,
			Color = WOOD,
			Parent = plaza,
		})
	end
end

local function simpleChest(parent: Instance, cframe: CFrame, color: Color3, name: string)
	local chest = Build.model(name, parent)
	local base = P({
		Name = "Base",
		Size = Vector3.new(4, 2.4, 2.8),
		CFrame = cframe * CFrame.new(0, 1.2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = color,
		Parent = chest,
	})
	P({
		Name = "Lid",
		Size = Vector3.new(4, 1, 2.8),
		CFrame = cframe * CFrame.new(0, 2.9, 0),
		Material = Enum.Material.WoodPlanks,
		Color = color:Lerp(Color3.new(1, 1, 1), 0.12),
		Parent = chest,
	})
	P({
		Name = "Band",
		Size = Vector3.new(4.1, 0.35, 2.9),
		CFrame = cframe * CFrame.new(0, 2.4, 0),
		Material = Enum.Material.Metal,
		Color = GOLD,
		Parent = chest,
	})
	P({
		Name = "Lock",
		Size = Vector3.new(0.7, 0.8, 0.3),
		CFrame = cframe * CFrame.new(0, 2.3, -1.5),
		Material = Enum.Material.Neon,
		Color = GOLD,
		Parent = chest,
	})
	chest.PrimaryPart = base
	return chest, base
end

local function buildVipLounge(lobby: Model, anchors)
	local vip = Build.model("VipLounge", lobby)
	local minX, maxX, minZ, maxZ = -HALF + 2, -34, -HALF + 2, -38
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local sx, sz = maxX - minX, maxZ - minZ
	P({
		Name = "VipFloor",
		Size = Vector3.new(sx, 0.3, sz),
		Position = Vector3.new(cx, FLOOR + 0.15, cz),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(255, 226, 140),
		Parent = vip,
	})
	Build.carpet(vip, Vector3.new(cx, FLOOR + 0.3, cz + 2), Vector2.new(6, sz - 4), Color3.fromRGB(190, 30, 50))
	-- zlatý plot s průchodem na severní straně
	local doorX = cx
	local fence = function(a: Vector3, b: Vector3)
		local mid = (a + b) / 2
		P({
			Name = "VipFence",
			Size = Vector3.new(0.6, 3.5, (a - b).Magnitude),
			CFrame = CFrame.lookAt(mid, b),
			Material = Enum.Material.Metal,
			Color = GOLD,
			Parent = vip,
		})
	end
	local y = FLOOR + 1.75
	fence(Vector3.new(maxX, y, minZ), Vector3.new(maxX, y, maxZ))
	fence(Vector3.new(minX + 0.5, y, maxZ), Vector3.new(doorX - 3.5, y, maxZ))
	fence(Vector3.new(doorX + 3.5, y, maxZ), Vector3.new(maxX, y, maxZ))
	for _, x in { doorX - 3.5, doorX + 3.5 } do
		P({
			Name = "VipGatePost",
			Size = Vector3.new(1.4, 8, 1.4),
			Position = Vector3.new(x, FLOOR + 4, maxZ),
			Material = Enum.Material.Metal,
			Color = GOLD,
			Parent = vip,
		})
	end
	local gateSign = P({
		Name = "VipSign",
		Size = Vector3.new(9, 2.2, 0.5),
		Position = Vector3.new(doorX, FLOOR + 8.5, maxZ),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(60, 20, 70),
		Parent = vip,
	})
	Build.sign(gateSign, "VIP LOUNGE", GOLD, { Enum.NormalId.Front, Enum.NormalId.Back })
	-- zlatá "brána" – průhledná záclona, kterou projdou jen VIP (hlídá RewardService)
	P({
		Name = "VipCurtain",
		Size = Vector3.new(6.4, 7, 0.2),
		Position = Vector3.new(doorX, FLOOR + 3.5, maxZ),
		Material = Enum.Material.ForceField,
		Color = GOLD,
		CanCollide = false,
		Transparency = 0.2,
		Parent = vip,
	})
	-- vybavení: pohovky, zlatá palma, VIP truhla
	for _, x in { minX + 4, maxX - 4 } do
		P({
			Name = "Sofa",
			Size = Vector3.new(3, 1.5, 8),
			Position = Vector3.new(x, FLOOR + 1, cz - 1),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(150, 30, 60),
			Parent = vip,
		})
		P({
			Name = "SofaBack",
			Size = Vector3.new(1, 2.5, 8),
			Position = Vector3.new(x + (if x < cx then -1.5 else 1.5), FLOOR + 2, cz - 1),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(130, 20, 50),
			Parent = vip,
		})
	end
	local palm = Build.palm(vip, Vector3.new(minX + 3, FLOOR, minZ + 3), 0.1, 6)
	for _, part in palm:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Leaf" then
			part.Color = GOLD
			part.Material = Enum.Material.Metal
		end
	end
	local chest, chestBase =
		simpleChest(vip, CFrame.new(cx, FLOOR + 0.3, minZ + 4), Color3.fromRGB(120, 40, 160), "VipChest")
	Build.sparkles(chestBase, GOLD, 10)
	Build.billboard(chestBase, "VIP REWARD", GOLD, Vector2.new(10, 2.4), 5)
	anchors.VipChest = chestBase
	anchors.VipZone = {
		Min = Vector3.new(minX - 1, FLOOR - 3, minZ - 1),
		Max = Vector3.new(maxX + 0.5, FLOOR + 25, maxZ - 0.3),
		Exit = CFrame.new(doorX, FLOOR + 3.5, maxZ + 6),
	}
	return chest
end

---------------------------------------------------------------------
-- Sever: denní odměna a návod
---------------------------------------------------------------------

local function buildNorth(lobby: Model, anchors)
	local north = Build.model("NorthPlaza", lobby)
	Build.cylinder({
		Name = "DailyPedestal",
		Height = 1.6,
		Diameter = 9,
		Position = Vector3.new(0, FLOOR + 0.8, 38),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(245, 235, 215),
		Parent = north,
	})
	Build.cylinder({
		Name = "DailyRing",
		Height = 0.3,
		Diameter = 9.3,
		Position = Vector3.new(0, FLOOR + 1.6, 38),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 230, 120),
		Parent = north,
	})
	local _, base = simpleChest(
		north,
		CFrame.lookAt(Vector3.new(0, FLOOR + 1.6, 38), Vector3.new(0, FLOOR + 1.6, 0)),
		Color3.fromRGB(60, 160, 80),
		"DailyChest"
	)
	Build.sparkles(base, Color3.fromRGB(150, 255, 150), 8)
	Build.billboard(base, "DAILY REWARD", Color3.fromRGB(160, 255, 160), Vector2.new(11, 2.6), 5)
	anchors.DailyChest = base

	-- Tabule "HOW TO PLAY"
	local center = Vector3.new(-24, FLOOR + 6, 50)
	local board = P({
		Name = "HowToPlay",
		Size = Vector3.new(16, 10, 0.8),
		CFrame = CFrame.lookAt(center, center + Vector3.new(0, 0, -1)),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(110, 70, 38),
		Parent = north,
	})
	for _, s in { -1, 1 } do
		P({
			Name = "HowToPlayLeg",
			Size = Vector3.new(0.8, 6, 0.8),
			Position = Vector3.new(-24 + s * 7, FLOOR + 3, 50.4),
			Material = Enum.Material.Wood,
			Color = WOOD,
			Parent = north,
		})
	end
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(800, 500)
	surface.LightInfluence = 0
	surface.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 90)
	title.BackgroundTransparency = 1
	title.Text = "HOW TO PLAY"
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 110)
	title.Parent = surface
	Build.stroke(title, 4)
	local steps = Instance.new("TextLabel")
	steps.Position = UDim2.fromOffset(30, 100)
	steps.Size = UDim2.new(1, -60, 1, -120)
	steps.BackgroundTransparency = 1
	steps.Text =
		"1. Walk out of a gate into the desert\n2. HOLD click / tap to dig sand\n3. Sell sand at the golden SELL pad\n4. Buy better tools & backpacks\n5. Dig deep to find treasure chests!"
	steps.Font = Enum.Font.FredokaOne
	steps.TextScaled = true
	steps.TextXAlignment = Enum.TextXAlignment.Left
	steps.TextColor3 = Color3.new(1, 1, 1)
	steps.Parent = surface
	Build.stroke(steps, 2)

	-- velbloud z kostiček
	local camel = Build.model("Camel", north)
	local cc = CFrame.new(28, FLOOR, 48) * CFrame.Angles(0, math.rad(200), 0)
	local tan = Color3.fromRGB(196, 150, 96)
	for _, leg in { { -1.2, -2.2 }, { 1.2, -2.2 }, { -1.2, 2.2 }, { 1.2, 2.2 } } do
		P({
			Name = "Leg",
			Size = Vector3.new(0.9, 4, 0.9),
			CFrame = cc * CFrame.new(leg[1], 2, leg[2]),
			Material = Enum.Material.Fabric,
			Color = tan,
			Parent = camel,
		})
	end
	P({
		Name = "Body",
		Size = Vector3.new(3.2, 2.6, 6.4),
		CFrame = cc * CFrame.new(0, 5, 0),
		Material = Enum.Material.Fabric,
		Color = tan,
		Parent = camel,
	})
	Build.ellipsoid({
		Name = "Hump",
		Size = Vector3.new(2.6, 2.4, 3),
		CFrame = cc * CFrame.new(0, 6.6, 0.4),
		Material = Enum.Material.Fabric,
		Color = tan,
		Parent = camel,
	})
	P({
		Name = "Neck",
		Size = Vector3.new(1.2, 3.4, 1.2),
		CFrame = cc * CFrame.new(0, 6.6, -3.6) * CFrame.Angles(math.rad(-25), 0, 0),
		Material = Enum.Material.Fabric,
		Color = tan,
		Parent = camel,
	})
	P({
		Name = "Head",
		Size = Vector3.new(1.4, 1.3, 2.4),
		CFrame = cc * CFrame.new(0, 8.4, -4.8),
		Material = Enum.Material.Fabric,
		Color = tan,
		Parent = camel,
	})
	Build.carpet(camel, (cc * CFrame.new(0, 6.32, 0.4)).Position, Vector2.new(3.4, 3.6), Color3.fromRGB(180, 40, 60))
	Build.crate(north, Vector3.new(34, FLOOR, 44), 2.6, 0.4)
	Build.barrel(north, Vector3.new(22, FLOOR, 52))
	Build.pot(north, Vector3.new(-14, FLOOR, 54), Color3.fromRGB(80, 140, 170))
end

local function buildDecor(lobby: Model)
	local decor = Build.model("Decor", lobby)
	-- lucerny kolem náměstí
	for i = 0, 7 do
		local angle = i * math.pi / 4 + math.pi / 8
		Build.lantern(decor, Vector3.new(math.cos(angle) * 22, FLOOR, math.sin(angle) * 22))
	end
	-- palmy v rozích
	for _, c in { { 1, 1 }, { -1, 1 }, { 1, -1 } } do
		Build.palm(decor, Vector3.new(c[1] * (HALF - 6), FLOOR, c[2] * (HALF - 6)), -c[1] * 0.1, 7)
	end
	Build.palm(decor, Vector3.new(-24, FLOOR, -18), 0.12, 6)
	Build.palm(decor, Vector3.new(-24, FLOOR, 20), -0.1, 6)
	Build.palm(decor, Vector3.new(26, FLOOR, 22), 0.1, 6)
	-- vlajky na hradbách
	for _, x in { -40, -20, 20, 40 } do
		Build.banner(
			decor,
			Vector3.new(x, FLOOR, HALF - 3),
			if x < 0 then Color3.fromRGB(220, 70, 50) else Color3.fromRGB(40, 110, 200),
			Vector3.new(0, 0, -1)
		)
		Build.banner(
			decor,
			Vector3.new(x, FLOOR, -HALF + 3),
			if x < 0 then Color3.fromRGB(40, 110, 200) else Color3.fromRGB(220, 70, 50),
			Vector3.new(0, 0, 1)
		)
	end
end

---------------------------------------------------------------------
-- Veřejné API
---------------------------------------------------------------------

-- Voda v oáze (Terrain). Volá se znovu po každém přegenerování pouště.
function LobbyBuilder.fillWater()
	workspace.Terrain:FillBlock(CFrame.new(0, 27, 0), Vector3.new(POOL * 2, 6, POOL * 2), Enum.Material.Water)
end

function LobbyBuilder.build(parent: Instance)
	local lobby = Build.model("OasisTown", parent)
	pcall(function()
		lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local anchors = { Model = lobby }

	buildBase(lobby)
	buildWalls(lobby)
	buildGates(lobby)
	buildOasis(lobby)
	buildMarket(lobby, anchors)
	buildTemple(lobby, anchors)
	buildLeaderboards(lobby, anchors)
	buildPassPlaza(lobby, anchors)
	buildVipLounge(lobby, anchors)
	buildNorth(lobby, anchors)
	buildDecor(lobby)

	-- Spawny kolem oázy
	anchors.Spawns = {}
	for _, d in { Vector3.new(0, 0, -20), Vector3.new(20, 0, 0), Vector3.new(-20, 0, 0), Vector3.new(0, 0, 20) } do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.Position = Vector3.new(d.X, FLOOR + 0.1, d.Z)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = lobby
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
		Build.cylinder({
			Name = "SpawnPad",
			Height = 0.25,
			Diameter = 7,
			Position = Vector3.new(d.X, FLOOR + 0.12, d.Z),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(250, 240, 220),
			Parent = lobby,
		})
		Build.cylinder({
			Name = "SpawnRing",
			Height = 0.28,
			Diameter = 5.2,
			Position = Vector3.new(d.X, FLOOR + 0.13, d.Z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 190, 70),
			Parent = lobby,
		})
		table.insert(
			anchors.Spawns,
			CFrame.lookAt(Vector3.new(d.X, FLOOR + 4, d.Z), Vector3.new(d.X * 3, FLOOR + 4, d.Z * 3))
		)
	end

	return anchors
end

return LobbyBuilder
