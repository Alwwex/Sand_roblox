--[[
	ToolFactory – staví modely nástrojů z Partů (žádné externí modely nejsou potřeba).

	Konvence: nástroj míří dopředu po ose -Z, "nahoru" je +Y.
	Grip = místo, kde ho postava drží (+ lehký náklon špičkou dolů).
	Chceš vlastní model? Viz docs/NAVOD.md – sekce "Vlastní modely nástrojů".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ToolFactory = {}

local WOOD = Color3.fromRGB(150, 100, 58)
local METAL = Color3.fromRGB(175, 180, 190)
local DARK = Color3.fromRGB(55, 55, 60)
local GOLD = Color3.fromRGB(255, 200, 60)

local function piece(
	tool: Tool,
	handle: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	mesh: Enum.MeshType?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = handle.CFrame * offset
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if mesh then
		local specialMesh = Instance.new("SpecialMesh")
		specialMesh.MeshType = mesh
		specialMesh.Parent = part
	end
	-- Klasický Weld s pevným offsetem – spolehlivý i když se nástroj staví mimo Workspace
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = tool
	return part
end

local function newHandle(tool: Tool, size: Vector3, color: Color3, material: Enum.Material, transparency: number?): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = material
	handle.Transparency = transparency or 0
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool
	return handle
end

local function grip(z: number, tiltDegrees: number): CFrame
	return CFrame.new(0, 0, z) * CFrame.Angles(math.rad(tiltDegrees), 0, 0)
end

local BUILDERS = {}

BUILDERS.Hands = function(tool: Tool)
	newHandle(tool, Vector3.new(0.4, 0.4, 0.4), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	tool.Grip = CFrame.new()
end

BUILDERS.Spoon = function(tool: Tool)
	local handle = newHandle(tool, Vector3.new(0.22, 0.1, 1.8), METAL, Enum.Material.Metal)
	piece(
		tool,
		handle,
		"Bowl",
		Vector3.new(0.75, 0.22, 0.95),
		CFrame.new(0, 0.02, -1.25),
		METAL,
		Enum.Material.Metal,
		Enum.MeshType.Sphere
	)
	tool.Grip = grip(0.55, 15)
end

BUILDERS.Trowel = function(tool: Tool)
	local handle =
		newHandle(tool, Vector3.new(0.32, 0.32, 1.2), Color3.fromRGB(200, 70, 50), Enum.Material.SmoothPlastic)
	piece(tool, handle, "Ferrule", Vector3.new(0.36, 0.36, 0.25), CFrame.new(0, 0, -0.7), METAL, Enum.Material.Metal)
	piece(tool, handle, "Neck", Vector3.new(0.12, 0.12, 0.5), CFrame.new(0, -0.1, -1), METAL, Enum.Material.Metal)
	piece(tool, handle, "Blade", Vector3.new(0.95, 0.08, 1.4), CFrame.new(0, -0.18, -1.9), METAL, Enum.Material.Metal)
	tool.Grip = grip(0.15, 20)
end

BUILDERS.Shovel = function(tool: Tool)
	local handle = newHandle(tool, Vector3.new(0.25, 0.25, 4.4), WOOD, Enum.Material.Wood)
	piece(tool, handle, "Grip", Vector3.new(0.9, 0.22, 0.22), CFrame.new(0, 0, 2.25), DARK, Enum.Material.SmoothPlastic)
	piece(tool, handle, "Collar", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0, -2.3), DARK, Enum.Material.Metal)
	piece(
		tool,
		handle,
		"Blade",
		Vector3.new(1.4, 0.12, 1.6),
		CFrame.new(0, 0, -3.25),
		Color3.fromRGB(90, 95, 105),
		Enum.Material.Metal
	)
	tool.Grip = grip(1.3, 25)
end

BUILDERS.GoldenShovel = function(tool: Tool)
	local handle = newHandle(tool, Vector3.new(0.27, 0.27, 4.4), Color3.fromRGB(60, 35, 20), Enum.Material.Wood)
	piece(tool, handle, "Grip", Vector3.new(0.95, 0.25, 0.25), CFrame.new(0, 0, 2.25), GOLD, Enum.Material.Metal)
	piece(tool, handle, "Collar", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 0, -2.3), GOLD, Enum.Material.Metal)
	local blade =
		piece(tool, handle, "Blade", Vector3.new(1.6, 0.14, 1.8), CFrame.new(0, 0, -3.35), GOLD, Enum.Material.Metal)
	blade.Reflectance = 0.25
	piece(
		tool,
		handle,
		"Gem",
		Vector3.new(0.4, 0.3, 0.4),
		CFrame.new(0, 0.1, -2.75),
		Color3.fromRGB(90, 230, 255),
		Enum.Material.Neon
	)
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = GOLD
	sparkle.Parent = blade
	tool.Grip = grip(1.3, 25)
end

BUILDERS.Vacuum = function(tool: Tool)
	local handle = newHandle(tool, Vector3.new(0.9, 1.1, 1.5), Color3.fromRGB(230, 80, 50), Enum.Material.SmoothPlastic)
	piece(
		tool,
		handle,
		"Tank",
		Vector3.new(0.8, 0.8, 1.2),
		CFrame.new(0, 0.6, 0.4),
		Color3.fromRGB(200, 220, 230),
		Enum.Material.Glass
	)
	piece(
		tool,
		handle,
		"Tube",
		Vector3.new(0.38, 0.38, 3.2),
		CFrame.new(0, -0.15, -2.3),
		DARK,
		Enum.Material.SmoothPlastic
	)
	piece(
		tool,
		handle,
		"Nozzle",
		Vector3.new(1.3, 0.3, 0.5),
		CFrame.new(0, -0.15, -4.05),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.SmoothPlastic
	)
	piece(
		tool,
		handle,
		"Glow",
		Vector3.new(0.45, 0.45, 0.12),
		CFrame.new(0, -0.15, -3.7),
		Color3.fromRGB(90, 230, 255),
		Enum.Material.Neon
	)
	tool.Grip = grip(0.3, 12)
end

BUILDERS.Blaster = function(tool: Tool)
	local handle = newHandle(tool, Vector3.new(1.2, 1.3, 2), Color3.fromRGB(255, 190, 40), Enum.Material.SmoothPlastic)
	piece(
		tool,
		handle,
		"Stripe",
		Vector3.new(1.25, 0.25, 2.05),
		CFrame.new(0, 0.2, 0),
		DARK,
		Enum.Material.SmoothPlastic
	)
	piece(tool, handle, "Barrel", Vector3.new(0.8, 0.8, 2.6), CFrame.new(0, 0, -2.2), DARK, Enum.Material.Metal)
	piece(
		tool,
		handle,
		"Muzzle",
		Vector3.new(1.3, 1.3, 0.6),
		CFrame.new(0, 0, -3.6),
		Color3.fromRGB(255, 190, 40),
		Enum.Material.SmoothPlastic
	)
	piece(
		tool,
		handle,
		"Core",
		Vector3.new(0.9, 0.9, 0.15),
		CFrame.new(0, 0, -3.95),
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon
	)
	tool.Grip = grip(0.4, 8)
end

BUILDERS.Excavator = function(tool: Tool)
	local yellow = Color3.fromRGB(255, 196, 30)
	local handle = newHandle(tool, Vector3.new(0.7, 0.7, 5.5), yellow, Enum.Material.Metal)
	piece(tool, handle, "Piston", Vector3.new(0.35, 0.35, 3.5), CFrame.new(0, 0.6, -0.5), METAL, Enum.Material.Metal)
	piece(tool, handle, "Joint", Vector3.new(1, 1, 1), CFrame.new(0, 0, -2.9), DARK, Enum.Material.Metal)
	piece(
		tool,
		handle,
		"BucketBack",
		Vector3.new(3.2, 1.8, 0.3),
		CFrame.new(0, -0.6, -3.5),
		yellow,
		Enum.Material.Metal
	)
	piece(
		tool,
		handle,
		"BucketBottom",
		Vector3.new(3.2, 0.3, 1.8),
		CFrame.new(0, -1.5, -4.3),
		yellow,
		Enum.Material.Metal
	)
	piece(tool, handle, "SideL", Vector3.new(0.25, 1.8, 1.8), CFrame.new(-1.5, -0.6, -4.3), yellow, Enum.Material.Metal)
	piece(tool, handle, "SideR", Vector3.new(0.25, 1.8, 1.8), CFrame.new(1.5, -0.6, -4.3), yellow, Enum.Material.Metal)
	for i = -2, 2 do
		piece(
			tool,
			handle,
			"Tooth",
			Vector3.new(0.35, 0.3, 0.7),
			CFrame.new(i * 0.65, -1.5, -5.4),
			DARK,
			Enum.Material.Metal
		)
	end
	tool.Grip = grip(2.2, 18)
end

function ToolFactory.create(toolId: string): Tool
	local config = Config.ToolsById[toolId] or Config.Tools[1]

	-- Vlastní model: ServerStorage > CustomTools > Tool pojmenovaný podle Id (např. "Spoon")
	local customFolder = ServerStorage:FindFirstChild("CustomTools")
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

return ToolFactory
