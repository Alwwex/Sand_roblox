--[[
	ToolFactory – staví modely nástrojů z Partů (žádné externí modely nejsou potřeba).

	Konvence: ruka drží nástroj v bodě (0,0,0), nástroj míří dopředu po ose -Z, "nahoru" je +Y.
	Každý nástroj je složený z 15–30 dílů (válce, koule, klíny, neon), aby vypadal "hotově".
	Chceš vlastní model? Viz docs/NAVOD.md – sekce "Vlastní modely nástrojů".
	Sdílený modul: server z něj dělá nástroje do ruky, klient náhledy v obchodě a v liště
	a lobby z něj staví dekorace (createModel).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ToolFactory = {}

local WOOD = Color3.fromRGB(156, 104, 60)
local STEEL = Color3.fromRGB(150, 158, 170)
local STEEL_DARK = Color3.fromRGB(88, 94, 104)
local CHROME = Color3.fromRGB(215, 220, 228)
local RUBBER = Color3.fromRGB(38, 38, 42)
local GOLD = Color3.fromRGB(255, 196, 50)
local SAND = Color3.fromRGB(232, 190, 120)
local CYAN = Color3.fromRGB(80, 230, 255)

---------------------------------------------------------------------
-- Stavebnice dílů (vše přivařené k neviditelnému Handle v místě úchopu)
---------------------------------------------------------------------

local function newBuilder(tool: Tool)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local B = {}

	local function attach(part: BasePart, name: string, offset: CFrame, color: Color3, material: Enum.Material?)
		part.Name = name
		part.CFrame = offset
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		-- klasický Weld s pevným offsetem – spolehlivý i mimo Workspace
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		part.Parent = tool
		return part
	end

	function B.box(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Size = size
		return attach(part, name, offset, color, material)
	end

	-- Válec s osou podél lokální Z osy daného offsetu
	function B.cyl(
		name: string,
		length: number,
		diameter: number,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(length, diameter, diameter)
		return attach(part, name, offset * CFrame.Angles(0, math.rad(90), 0), color, material)
	end

	-- Elipsoid (SpecialMesh Sphere se natáhne podle velikosti)
	function B.ball(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return attach(part, name, offset, color, material)
	end

	function B.neon(name: string, size: Vector3, offset: CFrame, color: Color3)
		return B.box(name, size, offset, color, Enum.Material.Neon)
	end

	B.handle = handle
	return B
end

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function grip(tiltDegrees: number): CFrame
	return CFrame.Angles(math.rad(tiltDegrees), 0, 0)
end

-- Kovový list lopaty: obdélník + "kosočtverec" vpředu = špička
local function spadeBlade(B, z: number, width: number, length: number, color: Color3, material: Enum.Material?)
	B.box("Blade", Vector3.new(width, 0.1, length), at(0, 0, z), color, material)
	local tip = width * 0.71
	B.box("BladeTip", Vector3.new(tip, 0.1, tip), at(0, 0, z - length / 2, 0, 45, 0), color, material)
	B.box(
		"BladeRidge",
		Vector3.new(width * 0.12, 0.13, length * 0.8),
		at(0, 0.02, z + length * 0.05),
		color:Lerp(Color3.new(1, 1, 1), 0.15),
		material
	)
end

---------------------------------------------------------------------
-- Nástroje
---------------------------------------------------------------------

local BUILDERS = {}

BUILDERS.Hands = function(tool: Tool)
	newBuilder(tool)
	tool.Grip = CFrame.new()
end

BUILDERS.Spoon = function(tool: Tool)
	local B = newBuilder(tool)
	local m = Enum.Material.Metal
	B.box("Stem", Vector3.new(0.28, 0.1, 1.9), at(0, 0, 0.05), CHROME, m)
	B.ball("StemEnd", Vector3.new(0.48, 0.13, 0.55), at(0, 0, 1.05), CHROME, m)
	B.box("Neck", Vector3.new(0.17, 0.08, 0.55), at(0, -0.03, -1.15, -8, 0, 0), CHROME, m)
	B.ball("Bowl", Vector3.new(0.9, 0.26, 1.2), at(0, -0.08, -1.9), CHROME, m)
	B.ball("BowlInside", Vector3.new(0.72, 0.12, 1.0), at(0, 0.03, -1.9), STEEL_DARK, m)
	B.ball("SandScoop", Vector3.new(0.6, 0.14, 0.8), at(0, 0.08, -1.88), SAND, Enum.Material.Sand)
	-- rez ("Rusty" Spoon)
	for i, z in { 0.6, -0.2, -0.7 } do
		B.ball(
			"Rust",
			Vector3.new(0.16 + i * 0.03, 0.06, 0.2),
			at((i % 2 - 0.5) * 0.12, 0.04, z),
			Color3.fromRGB(170, 92, 48),
			Enum.Material.CorrodedMetal
		)
	end
	tool.Grip = grip(15)
end

BUILDERS.Trowel = function(tool: Tool)
	local B = newBuilder(tool)
	local red = Color3.fromRGB(205, 55, 45)
	B.cyl("Grip", 1.35, 0.44, at(0, 0, 0.25), red, Enum.Material.SmoothPlastic)
	for _, z in { 0.55, 0.25, -0.05 } do
		B.cyl("GripRing", 0.09, 0.48, at(0, 0, z), Color3.fromRGB(150, 30, 25))
	end
	B.ball("GripEnd", Vector3.new(0.5, 0.5, 0.5), at(0, 0, 0.95), Color3.fromRGB(150, 30, 25))
	B.cyl("Ferrule", 0.32, 0.38, at(0, 0, -0.55), Color3.fromRGB(210, 165, 70), Enum.Material.Metal)
	B.box("Neck", Vector3.new(0.12, 0.12, 0.62), at(0, -0.15, -0.9, -32, 0, 0), STEEL, Enum.Material.Metal)
	spadeBlade(B, -1.75, 0.95, 1.0, STEEL, Enum.Material.Metal)
	B.box("BladeEdge", Vector3.new(0.97, 0.04, 0.12), at(0, 0.05, -1.25), CHROME, Enum.Material.Metal)
	tool.Grip = grip(20)
end

local function buildShovel(B, golden: boolean)
	local shaftColor = if golden then Color3.fromRGB(70, 40, 22) else WOOD
	local metal = if golden then GOLD else STEEL
	local metalMat = Enum.Material.Metal
	local accent = if golden then GOLD else RUBBER
	B.cyl("Shaft", 3.7, 0.27, at(0, 0, -0.85), shaftColor, Enum.Material.Wood)
	-- D-rukojeť
	B.cyl(
		"GripBar",
		0.95,
		0.24,
		at(0, 0, 1.75, 0, 90, 0),
		accent,
		if golden then metalMat else Enum.Material.SmoothPlastic
	)
	B.cyl(
		"GripArmL",
		0.7,
		0.16,
		at(-0.3, 0, 1.4, 0, -40, 0),
		accent,
		if golden then metalMat else Enum.Material.SmoothPlastic
	)
	B.cyl(
		"GripArmR",
		0.7,
		0.16,
		at(0.3, 0, 1.4, 0, 40, 0),
		accent,
		if golden then metalMat else Enum.Material.SmoothPlastic
	)
	-- omotávka na násadě
	for _, z in { 0.55, 0.05 } do
		B.cyl(
			"Wrap",
			0.3,
			0.31,
			at(0, 0, z),
			if golden then GOLD else RUBBER,
			if golden then metalMat else Enum.Material.Fabric
		)
	end
	B.cyl("Collar", 0.55, 0.36, at(0, 0, -2.85), if golden then GOLD else STEEL_DARK, metalMat)
	for _, x in { -0.19, 0.19 } do
		B.ball("Rivet", Vector3.new(0.1, 0.1, 0.1), at(x, 0, -2.85), CHROME, metalMat)
	end
	B.box("StepLip", Vector3.new(1.45, 0.18, 0.17), at(0, 0.07, -3.15), if golden then GOLD else STEEL_DARK, metalMat)
	spadeBlade(B, -3.8, 1.35, 1.25, metal, metalMat)
	B.ball("Dirt", Vector3.new(0.55, 0.12, 0.35), at(0.2, 0.07, -4.2), SAND, Enum.Material.Sand)
end

BUILDERS.Shovel = function(tool: Tool)
	local B = newBuilder(tool)
	buildShovel(B, false)
	tool.Grip = grip(25)
end

BUILDERS.GoldenShovel = function(tool: Tool)
	local B = newBuilder(tool)
	buildShovel(B, true)
	local gem = B.box("Gem", Vector3.new(0.38, 0.22, 0.38), at(0, 0.1, -3.55, 0, 45, 0), CYAN, Enum.Material.Neon)
	B.neon("GemGlowL", Vector3.new(0.06, 0.12, 0.6), at(-0.45, 0.06, -3.8), CYAN)
	B.neon("GemGlowR", Vector3.new(0.06, 0.12, 0.6), at(0.45, 0.06, -3.8), CYAN)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = GOLD
	sparkles.Parent = gem
	tool.Grip = grip(25)
end

BUILDERS.Vacuum = function(tool: Tool)
	local B = newBuilder(tool)
	local orange = Color3.fromRGB(242, 96, 44)
	-- tělo (kapsle)
	B.cyl("Body", 1.5, 1.05, at(0, 0.45, 0.35), orange)
	B.ball("BodyBack", Vector3.new(1.05, 1.05, 0.9), at(0, 0.45, 1.1), orange)
	B.ball("BodyFront", Vector3.new(1.05, 1.05, 0.7), at(0, 0.45, -0.4), orange)
	for _, z in { 0.85, -0.15 } do
		B.cyl("Band", 0.12, 1.1, at(0, 0.45, z), CHROME, Enum.Material.Metal)
	end
	-- nádoba s pískem
	local tank = B.cyl("Tank", 0.95, 0.7, at(0, 1.15, 0.35), Color3.fromRGB(200, 235, 255), Enum.Material.Glass)
	tank.Transparency = 0.45
	B.cyl("TankSand", 0.85, 0.5, at(0, 1.08, 0.35), SAND, Enum.Material.Sand)
	B.cyl("TankCapFront", 0.08, 0.74, at(0, 1.15, -0.13), RUBBER)
	B.cyl("TankCapBack", 0.08, 0.74, at(0, 1.15, 0.83), RUBBER)
	-- kontrolky
	B.neon("LightA", Vector3.new(0.05, 0.14, 0.14), at(0.54, 0.6, 0.55), Color3.fromRGB(90, 255, 120))
	B.neon("LightB", Vector3.new(0.05, 0.14, 0.14), at(0.54, 0.6, 0.25), Color3.fromRGB(255, 200, 60))
	-- hadice z článků (oblouk dolů)
	local p0, p1, p2 = Vector3.new(0, 0.3, -0.75), Vector3.new(0, 0.15, -2.1), Vector3.new(0, -0.55, -3.0)
	local segments = 7
	local last = p0
	for i = 1, segments do
		local t = i / segments
		local point = p0 * (1 - t) ^ 2 + p1 * 2 * (1 - t) * t + p2 * t ^ 2
		local mid = (last + point) / 2
		local length = (point - last).Magnitude
		B.cyl(
			"Hose",
			length + 0.05,
			if i % 2 == 0 then 0.36 else 0.32,
			CFrame.lookAt(mid, point),
			if i % 2 == 0 then Color3.fromRGB(70, 72, 78) else RUBBER
		)
		last = point
	end
	-- hubice
	B.box("Nozzle", Vector3.new(1.35, 0.34, 0.6), at(0, -0.62, -3.3), RUBBER)
	B.box("NozzleTop", Vector3.new(1.0, 0.16, 0.45), at(0, -0.42, -3.2), Color3.fromRGB(60, 62, 68))
	B.neon("NozzleGlow", Vector3.new(1.2, 0.07, 0.06), at(0, -0.66, -3.62), CYAN)
	tool.Grip = grip(12)
end

BUILDERS.Blaster = function(tool: Tool)
	local B = newBuilder(tool)
	local yellow = Color3.fromRGB(255, 192, 36)
	B.ball("Body", Vector3.new(1.45, 1.35, 2.0), at(0, 0.35, 0.25), yellow)
	B.box("StripeL", Vector3.new(0.06, 0.3, 1.5), at(-0.7, 0.35, 0.25), RUBBER)
	B.box("StripeR", Vector3.new(0.06, 0.3, 1.5), at(0.7, 0.35, 0.25), RUBBER)
	-- zadní ventilátor
	B.cyl("FanHousing", 0.5, 1.55, at(0, 0.35, 1.2), Color3.fromRGB(60, 62, 70))
	B.cyl("FanHub", 0.56, 0.35, at(0, 0.35, 1.22), CHROME, Enum.Material.Metal)
	for k = 0, 5 do
		B.box("FanBlade", Vector3.new(0.12, 1.25, 0.05), at(0, 0.35, 1.48, 0, 0, k * 30), Color3.fromRGB(40, 40, 46))
	end
	-- hlaveň
	B.cyl("Barrel1", 1.0, 0.82, at(0, 0.3, -1.05), Color3.fromRGB(70, 72, 80), Enum.Material.Metal)
	B.cyl("Barrel2", 0.9, 0.66, at(0, 0.3, -1.95), STEEL, Enum.Material.Metal)
	B.cyl("Muzzle", 0.36, 1.02, at(0, 0.3, -2.5), yellow)
	B.cyl("MuzzleCore", 0.08, 0.78, at(0, 0.3, -2.7), Color3.fromRGB(255, 130, 40), Enum.Material.Neon)
	-- rukojeť a spoušť
	B.box("GripHandle", Vector3.new(0.32, 0.85, 0.45), at(0, -0.45, 0.4, -15, 0, 0), RUBBER)
	B.box("Trigger", Vector3.new(0.12, 0.25, 0.12), at(0, -0.3, 0.05), Color3.fromRGB(230, 60, 50))
	for _, x in { -0.62, 0.62 } do
		B.box("Vent", Vector3.new(0.05, 0.08, 0.5), at(x, 0.65, -0.2), RUBBER)
		B.box("Vent", Vector3.new(0.05, 0.08, 0.5), at(x, 0.5, -0.2), RUBBER)
	end
	tool.Grip = grip(8)
end

BUILDERS.Excavator = function(tool: Tool)
	local B = newBuilder(tool)
	local yellow = Color3.fromRGB(255, 196, 30)
	local m = Enum.Material.Metal
	B.cyl("GripHandle", 1.05, 0.46, at(0, 0, 0.75), RUBBER)
	B.ball("GripEnd", Vector3.new(0.52, 0.52, 0.52), at(0, 0, 1.3), RUBBER)
	B.box("Arm", Vector3.new(0.72, 0.72, 4.2), at(0, 0, -1.9), yellow, m)
	-- výstražné pruhy
	for i = 0, 3 do
		B.box(
			"Hazard",
			Vector3.new(0.75, 0.75, 0.22),
			at(0, 0, -0.4 - i * 0.45),
			if i % 2 == 0 then RUBBER else yellow,
			m
		)
	end
	-- hydraulika
	B.box("PistonMountA", Vector3.new(0.3, 0.35, 0.3), at(0, 0.5, -0.7), STEEL_DARK, m)
	B.box("PistonMountB", Vector3.new(0.3, 0.35, 0.3), at(0, 0.5, -3.3), STEEL_DARK, m)
	B.cyl("PistonBody", 1.4, 0.32, at(0, 0.6, -1.4), STEEL_DARK, m)
	B.cyl("PistonRod", 1.4, 0.18, at(0, 0.6, -2.7), CHROME, m)
	-- kloub
	B.cyl("Joint", 1.25, 0.95, at(0, 0, -4.05, 0, 90, 0), Color3.fromRGB(60, 62, 68), m)
	B.cyl("JointPin", 1.4, 0.3, at(0, 0, -4.05, 0, 90, 0), CHROME, m)
	-- lžíce
	B.box("BucketBack", Vector3.new(3.0, 1.8, 0.28), at(0, -0.55, -4.45, -12, 0, 0), yellow, m)
	B.box("BucketBottom", Vector3.new(3.0, 0.28, 1.9), at(0, -1.45, -5.3), yellow, m)
	for _, x in { -1.4, 1.4 } do
		B.box("BucketSide", Vector3.new(0.26, 1.7, 1.9), at(x, -0.6, -5.2), yellow, m)
		B.box("SideTrim", Vector3.new(0.3, 0.22, 1.95), at(x, 0.25, -5.2), STEEL_DARK, m)
	end
	for i = -2, 2 do
		B.box(
			"Tooth",
			Vector3.new(0.38, 0.26, 0.38),
			at(i * 0.62, -1.45, -6.25, 0, 45, 0),
			Color3.fromRGB(70, 72, 78),
			m
		)
	end
	B.ball("SandLoad", Vector3.new(2.6, 1.1, 1.7), at(0, -0.85, -5.25), SAND, Enum.Material.Sand)
	tool.Grip = grip(18)
end

function ToolFactory.create(toolId: string): Tool
	local config = Config.ToolsById[toolId] or Config.Tools[1]

	-- Vlastní model: ReplicatedStorage > CustomTools > Tool pojmenovaný podle Id (např. "Spoon")
	local customFolder = ReplicatedStorage:FindFirstChild("CustomTools")
	local custom = customFolder and customFolder:FindFirstChild(config.Id)
	if custom and custom:IsA("Tool") then
		local clone = custom:Clone()
		clone.Name = config.Name
		clone.CanBeDropped = false
		clone:SetAttribute("DigToolId", config.Id)
		return clone
	end

	local tool = Instance.new("Tool")
	tool.Name = config.Name
	tool.ToolTip = config.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("DigToolId", config.Id)
	local builder = BUILDERS[config.Id] or BUILDERS.Shovel
	builder(tool)
	return tool
end

-- Ukotvený model nástroje (dekorace v lobby, náhled ve ViewportFrame)
function ToolFactory.createModel(toolId: string): Model
	local tool = ToolFactory.create(toolId)
	local model = Instance.new("Model")
	model.Name = tool.Name
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.Parent = model
		end
	end
	model.PrimaryPart = model:FindFirstChild("Handle") :: BasePart?
	tool:Destroy()
	return model
end

return ToolFactory
