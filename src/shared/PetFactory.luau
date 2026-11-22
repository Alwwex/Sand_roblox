--[[
	PetFactory – modely mazlíčků a vajíček (z partů, roztomilý "chibi" styl).

	Model stojí na zemi v bodě (0,0,0) (neviditelný part "Root" = PrimaryPart),
	kouká dopředu po ose -Z. Používá server (mazlíčci ve světě, vajíčka v lobby)
	i klient (náhledy v UI a animace líhnutí).
]]

local PetFactory = {}

local BLACK = Color3.fromRGB(28, 22, 20)
local WHITE = Color3.new(1, 1, 1)
local PINK = Color3.fromRGB(255, 150, 160)
local GOLD = Color3.fromRGB(255, 200, 60)

local FLYING = { WaterSpirit = true, PalmParrot = true, SunDragon = true }

---------------------------------------------------------------------
-- Stavebnice
---------------------------------------------------------------------

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, opts)
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = o.Material or Enum.Material.SmoothPlastic
	p.Transparency = o.Transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.Ball then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif o.Cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = model
	return p
end

local function ball(model, name, size, cf, color, opts)
	local o = opts or {}
	o.Ball = true
	return part(model, name, size, cf, color, o)
end

-- "trojúhelník" = kosočtverec napůl schovaný (uši lišky, kočky)
local function diamond(model, name, size: number, cf: CFrame, color: Color3, depth: number?)
	return part(model, name, Vector3.new(size, size, depth or 0.2), cf * CFrame.Angles(0, 0, math.rad(45)), color)
end

local function eyes(model, y: number, z: number, spacing: number, size: number, glow: Color3?)
	for _, side in { -1, 1 } do
		local x = side * spacing
		ball(
			model,
			"Eye",
			Vector3.new(size * 0.8, size, size * 0.4),
			at(x, y, z),
			glow or BLACK,
			if glow then { Material = Enum.Material.Neon } else nil
		)
		ball(
			model,
			"EyeShine",
			Vector3.new(size * 0.32, size * 0.32, size * 0.2),
			at(x + size * 0.15, y + size * 0.22, z - size * 0.12),
			WHITE,
			{ Material = Enum.Material.Neon }
		)
	end
end

local function blush(model, y: number, z: number, spacing: number)
	for _, side in { -1, 1 } do
		ball(model, "Blush", Vector3.new(0.38, 0.2, 0.1), at(side * spacing, y, z), PINK, { Transparency = 0.25 })
	end
end

local function feet(model, color: Color3, spread: number, z: number?)
	for _, side in { -1, 1 } do
		ball(model, "Foot", Vector3.new(0.6, 0.35, 0.75), at(side * spread, 0.18, z or -0.35), color)
	end
end

---------------------------------------------------------------------
-- Mazlíčci
---------------------------------------------------------------------

local PETS = {}

PETS.SandBunny = function(m)
	local fur, cream = Color3.fromRGB(240, 214, 168), Color3.fromRGB(255, 242, 220)
	ball(m, "Body", Vector3.new(2, 1.9, 1.9), at(0, 1.05, 0), fur)
	ball(m, "Belly", Vector3.new(1.3, 1.2, 0.6), at(0, 0.85, -0.72), cream)
	for _, side in { -1, 1 } do
		ball(m, "Ear", Vector3.new(0.48, 1.55, 0.32), at(side * 0.42, 2.45, 0.1, -10, 0, -side * 12), fur)
		ball(m, "EarInner", Vector3.new(0.26, 1.1, 0.12), at(side * 0.43, 2.45, -0.04, -10, 0, -side * 12), PINK)
	end
	eyes(m, 1.35, -0.88, 0.42, 0.36)
	blush(m, 1.08, -0.86, 0.62)
	ball(m, "Nose", Vector3.new(0.2, 0.15, 0.1), at(0, 1.12, -0.95), PINK)
	feet(m, cream, 0.45)
	ball(m, "Tail", Vector3.new(0.6, 0.6, 0.6), at(0, 0.8, 0.95), WHITE)
end

PETS.DesertMouse = function(m)
	local fur = Color3.fromRGB(176, 146, 120)
	ball(m, "Body", Vector3.new(1.9, 1.7, 2.1), at(0, 0.95, 0), fur)
	ball(m, "Belly", Vector3.new(1.2, 1.0, 0.6), at(0, 0.8, -0.78), Color3.fromRGB(230, 210, 190))
	for _, side in { -1, 1 } do
		part(m, "Ear", Vector3.new(0.16, 1.15, 1.15), at(side * 0.62, 1.95, 0.05, 0, 90, 0), fur, { Cylinder = true })
		part(
			m,
			"EarInner",
			Vector3.new(0.17, 0.8, 0.8),
			at(side * 0.62, 1.95, -0.02, 0, 90, 0),
			PINK,
			{ Cylinder = true }
		)
		for k = -1, 1, 2 do
			part(
				m,
				"Whisker",
				Vector3.new(0.75, 0.03, 0.03),
				at(side * 0.55, 0.98 + k * 0.08, -1.0, 0, 0, side * k * 8),
				BLACK
			)
		end
	end
	eyes(m, 1.2, -0.97, 0.36, 0.32)
	blush(m, 0.96, -0.92, 0.58)
	ball(m, "Nose", Vector3.new(0.24, 0.2, 0.16), at(0, 1.0, -1.08), PINK)
	feet(m, Color3.fromRGB(230, 200, 190), 0.42)
	local tailPoints = {
		Vector3.new(0, 0.4, 1.0),
		Vector3.new(0, 0.55, 1.6),
		Vector3.new(0.25, 0.95, 1.95),
		Vector3.new(0.45, 1.35, 1.8),
	}
	for i = 1, #tailPoints - 1 do
		local a, b = tailPoints[i], tailPoints[i + 1]
		part(
			m,
			"Tail",
			Vector3.new((b - a).Magnitude + 0.06, 0.12, 0.12),
			CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			PINK,
			{ Cylinder = true }
		)
	end
end

local function scarab(m, shell: Color3, material: Enum.Material, gem: boolean)
	local dark = shell:Lerp(BLACK, 0.55)
	ball(m, "Body", Vector3.new(2, 1.3, 2.4), at(0, 0.95, 0.2), shell, { Material = material })
	part(m, "ShellLine", Vector3.new(0.07, 0.06, 2.0), at(0, 1.6, 0.25), dark)
	ball(m, "Head", Vector3.new(1.05, 0.85, 0.85), at(0, 0.85, -1.05), dark)
	part(m, "Horn", Vector3.new(0.16, 0.7, 0.16), at(0, 1.35, -1.3, -30, 0, 0), dark)
	eyes(m, 0.98, -1.44, 0.28, 0.26)
	for _, side in { -1, 1 } do
		for k = -1, 1 do
			part(m, "Leg", Vector3.new(0.85, 0.12, 0.12), at(side * 1.05, 0.32, k * 0.6, 0, 0, side * 32), dark)
		end
	end
	if gem then
		local g = part(
			m,
			"Gem",
			Vector3.new(0.5, 0.5, 0.25),
			at(0, 1.62, 0.25, 90, 0, 45),
			Color3.fromRGB(70, 200, 255),
			{ Material = Enum.Material.Neon }
		)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GOLD
		sparkles.Parent = g
	end
end

PETS.ScarabBug = function(m)
	scarab(m, Color3.fromRGB(40, 140, 128), Enum.Material.Metal, false)
end

PETS.GoldenScarab = function(m)
	scarab(m, GOLD, Enum.Material.Metal, true)
end

PETS.FennecFox = function(m)
	local fur, white = Color3.fromRGB(242, 162, 82), Color3.fromRGB(255, 246, 232)
	ball(m, "Body", Vector3.new(1.9, 1.8, 1.9), at(0, 1.0, 0), fur)
	ball(m, "Belly", Vector3.new(1.2, 1.1, 0.5), at(0, 0.8, -0.72), white)
	for _, side in { -1, 1 } do
		diamond(m, "Ear", 1.0, at(side * 0.55, 2.05, 0.1, 0, 0, -side * 12), fur, 0.22)
		diamond(m, "EarInner", 0.62, at(side * 0.55, 2.0, -0.02, 0, 0, -side * 12), PINK, 0.1)
		ball(m, "Cheek", Vector3.new(0.62, 0.45, 0.3), at(side * 0.42, 0.95, -0.78), white)
	end
	ball(m, "Snout", Vector3.new(0.55, 0.42, 0.5), at(0, 0.98, -0.92), white)
	ball(m, "Nose", Vector3.new(0.2, 0.16, 0.14), at(0, 1.1, -1.18), BLACK)
	eyes(m, 1.35, -0.85, 0.4, 0.34)
	feet(m, Color3.fromRGB(200, 120, 60), 0.45)
	ball(m, "Tail", Vector3.new(0.95, 0.95, 1.7), at(0, 1.0, 1.15, 30, 0, 0), fur)
	ball(m, "TailTip", Vector3.new(0.65, 0.65, 0.65), at(0, 1.45, 1.8), white)
end

PETS.LilyFrog = function(m)
	local green, light = Color3.fromRGB(110, 200, 90), Color3.fromRGB(196, 238, 150)
	ball(m, "Body", Vector3.new(2.1, 1.55, 1.9), at(0, 0.85, 0), green)
	ball(m, "Belly", Vector3.new(1.4, 0.95, 0.5), at(0, 0.7, -0.72), light)
	for _, side in { -1, 1 } do
		ball(m, "EyeBump", Vector3.new(0.78, 0.78, 0.78), at(side * 0.5, 1.6, -0.4), green)
	end
	eyes(m, 1.66, -0.76, 0.5, 0.36)
	part(m, "Smile", Vector3.new(0.95, 0.08, 0.06), at(0, 0.95, -0.97), Color3.fromRGB(60, 110, 50))
	blush(m, 0.98, -0.88, 0.7)
	feet(m, light, 0.55, -0.55)
	part(
		m,
		"LilyPad",
		Vector3.new(0.08, 1.25, 1.25),
		at(0, 1.75, 0.25, 0, 0, 90),
		Color3.fromRGB(60, 150, 70),
		{ Cylinder = true }
	)
	ball(m, "Flower", Vector3.new(0.4, 0.32, 0.4), at(0.25, 1.86, 0.25), Color3.fromRGB(255, 130, 190))
	ball(m, "FlowerCore", Vector3.new(0.15, 0.12, 0.15), at(0.25, 1.98, 0.25), Color3.fromRGB(255, 230, 90))
end

PETS.OasisTurtle = function(m)
	local skin, shell = Color3.fromRGB(150, 205, 95), Color3.fromRGB(40, 152, 140)
	ball(m, "Body", Vector3.new(2.2, 1.45, 2.4), at(0, 1.0, 0.15), shell)
	ball(m, "ShellRim", Vector3.new(2.45, 0.42, 2.65), at(0, 0.6, 0.15), shell:Lerp(BLACK, 0.3))
	for _, p in
		{
			Vector3.new(0, 1.7, 0.2),
			Vector3.new(0.6, 1.5, -0.3),
			Vector3.new(-0.6, 1.5, -0.3),
			Vector3.new(0.6, 1.5, 0.7),
			Vector3.new(-0.6, 1.5, 0.7),
		}
	do
		ball(
			m,
			"ShellSpot",
			Vector3.new(0.55, 0.12, 0.55),
			CFrame.lookAt(p, p * 2) * CFrame.Angles(math.rad(90), 0, 0),
			Color3.fromRGB(120, 220, 200)
		)
	end
	ball(m, "Head", Vector3.new(0.95, 0.9, 0.95), at(0, 1.0, -1.25), skin)
	eyes(m, 1.12, -1.66, 0.25, 0.26)
	blush(m, 0.92, -1.62, 0.36)
	for _, x in { -0.8, 0.8 } do
		for _, z in { -0.6, 0.9 } do
			ball(m, "Leg", Vector3.new(0.6, 0.5, 0.6), at(x, 0.28, z), skin)
		end
	end
end

PETS.PalmParrot = function(m)
	local red, yellow, blue = Color3.fromRGB(232, 62, 52), Color3.fromRGB(255, 214, 70), Color3.fromRGB(52, 112, 224)
	ball(m, "Body", Vector3.new(1.55, 1.9, 1.55), at(0, 1.1, 0.05), red)
	ball(m, "Belly", Vector3.new(1.0, 1.15, 0.45), at(0, 0.95, -0.62), yellow)
	ball(m, "Head", Vector3.new(1.3, 1.2, 1.2), at(0, 2.15, -0.1), red)
	part(m, "Beak", Vector3.new(0.45, 0.45, 0.45), at(0, 2.0, -0.78, 45, 0, 0), Color3.fromRGB(255, 170, 40))
	for _, side in { -1, 1 } do
		ball(m, "EyePatch", Vector3.new(0.45, 0.5, 0.15), at(side * 0.32, 2.3, -0.62), WHITE)
		ball(m, "Wing", Vector3.new(0.38, 1.35, 1.0), at(side * 0.82, 1.25, 0.1, 0, 0, side * 15), blue)
		ball(
			m,
			"WingTip",
			Vector3.new(0.3, 0.6, 0.7),
			at(side * 0.9, 0.62, 0.25, 0, 0, side * 15),
			Color3.fromRGB(60, 190, 90)
		)
	end
	eyes(m, 2.3, -0.7, 0.32, 0.24)
	for i, color in { blue, Color3.fromRGB(60, 190, 90), yellow } do
		part(m, "TailFeather", Vector3.new(0.26, 0.08, 1.3), at((i - 2) * 0.22, 0.55, 0.95, 25, (i - 2) * 12, 0), color)
	end
	for k = -1, 1 do
		part(
			m,
			"Leaf",
			Vector3.new(0.18, 0.06, 0.8),
			at(k * 0.18, 2.85, 0.05, -40, k * 30, 0),
			Color3.fromRGB(70, 170, 70)
		)
	end
	feet(m, Color3.fromRGB(255, 170, 40), 0.3)
end

PETS.WaterSpirit = function(m)
	local water = Color3.fromRGB(90, 200, 255)
	ball(
		m,
		"Body",
		Vector3.new(2, 2.2, 2),
		at(0, 1.3, 0),
		water,
		{ Material = Enum.Material.Glass, Transparency = 0.35 }
	)
	local core = ball(
		m,
		"Core",
		Vector3.new(0.95, 0.95, 0.95),
		at(0, 1.25, 0.1),
		Color3.fromRGB(170, 245, 255),
		{ Material = Enum.Material.Neon }
	)
	eyes(m, 1.5, -0.95, 0.38, 0.36)
	blush(m, 1.18, -0.93, 0.6)
	for i, p in
		{
			Vector3.new(1.3, 1.9, 0.3),
			Vector3.new(-1.25, 1.6, 0.4),
			Vector3.new(0, 2.75, 0.4),
			Vector3.new(0.5, 2.55, -0.2),
		}
	do
		ball(
			m,
			"Droplet",
			Vector3.new(0.35, 0.45, 0.35) * (1 - i * 0.08),
			CFrame.new(p),
			water,
			{ Material = Enum.Material.Glass, Transparency = 0.3 }
		)
	end
	local light = Instance.new("PointLight")
	light.Color = water
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = core
end

PETS.MummyCat = function(m)
	local wrap, band = Color3.fromRGB(238, 228, 204), Color3.fromRGB(205, 192, 165)
	ball(m, "Body", Vector3.new(1.9, 1.8, 1.9), at(0, 1.0, 0), wrap)
	for i, y in { 0.55, 1.0, 1.45 } do
		ball(
			m,
			"Bandage",
			Vector3.new(1.97 - math.abs(y - 1) * 0.5, 0.16, 1.97 - math.abs(y - 1) * 0.5),
			at(0, y, 0, 0, 0, (i - 2) * 9),
			band
		)
	end
	for _, side in { -1, 1 } do
		diamond(m, "Ear", 0.7, at(side * 0.5, 1.85, 0.1, 0, 0, -side * 10), wrap)
	end
	ball(
		m,
		"EyeGlow",
		Vector3.new(0.3, 0.38, 0.14),
		at(-0.35, 1.3, -0.9),
		Color3.fromRGB(110, 255, 120),
		{ Material = Enum.Material.Neon }
	)
	part(m, "EyeWrap", Vector3.new(0.6, 0.16, 0.12), at(0.35, 1.32, -0.9, 0, 0, 15), band)
	ball(m, "Nose", Vector3.new(0.16, 0.12, 0.1), at(0, 1.12, -0.96), PINK)
	feet(m, band, 0.45)
	part(m, "Tail", Vector3.new(1.2, 0.16, 0.16), at(0.3, 0.75, 1.0, 0, 60, 30), band, { Cylinder = true })
end

PETS.SphinxCat = function(m)
	local fur, blue = Color3.fromRGB(226, 182, 112), Color3.fromRGB(40, 90, 200)
	ball(m, "Body", Vector3.new(1.9, 1.8, 1.9), at(0, 1.0, 0), fur)
	ball(m, "Headdress", Vector3.new(2.05, 1.05, 1.95), at(0, 1.75, 0.08), GOLD, { Material = Enum.Material.Metal })
	-- modré pruhy kopírují zaoblení čelenky (jinak by byly schované uvnitř)
	for _, dy in { -0.28, -0.04, 0.2 } do
		local k = math.sqrt(1 - (dy / 0.525) ^ 2)
		ball(m, "Stripe", Vector3.new(2.05 * k + 0.06, 0.12, 1.95 * k + 0.06), at(0, 1.75 + dy, 0.08), blue)
	end
	for _, side in { -1, 1 } do
		part(
			m,
			"Flap",
			Vector3.new(0.32, 1.0, 0.55),
			at(side * 0.92, 1.2, -0.35),
			GOLD,
			{ Material = Enum.Material.Metal }
		)
		part(m, "FlapStripe", Vector3.new(0.34, 0.14, 0.57), at(side * 0.92, 1.1, -0.35), blue)
		diamond(m, "Ear", 0.72, at(side * 0.55, 2.25, 0.15, 0, 0, -side * 10), fur)
		part(m, "Liner", Vector3.new(0.5, 0.06, 0.06), at(side * 0.42, 1.2, -0.95, 0, 0, side * -12), BLACK)
	end
	eyes(m, 1.3, -0.88, 0.4, 0.34)
	ball(m, "Nose", Vector3.new(0.18, 0.13, 0.1), at(0, 1.08, -0.96), PINK)
	ball(m, "Collar", Vector3.new(1.65, 0.28, 1.65), at(0, 0.72, 0), GOLD, { Material = Enum.Material.Metal })
	part(
		m,
		"CollarGem",
		Vector3.new(0.28, 0.28, 0.12),
		at(0, 0.72, -0.84, 0, 0, 45),
		Color3.fromRGB(255, 60, 90),
		{ Material = Enum.Material.Neon }
	)
	feet(m, fur, 0.45)
	part(m, "Tail", Vector3.new(1.3, 0.2, 0.2), at(0.35, 0.8, 1.0, 0, 55, 35), fur, { Cylinder = true })
end

PETS.SunDragon = function(m)
	local scale = Color3.fromRGB(255, 138, 30)
	local belly = Color3.fromRGB(255, 226, 130)
	local membrane = Color3.fromRGB(232, 62, 42)
	local bone = Color3.fromRGB(190, 70, 24)
	local horn = Color3.fromRGB(255, 246, 220)
	ball(m, "Body", Vector3.new(1.85, 1.9, 2.0), at(0, 1.05, 0), scale)
	ball(m, "Belly", Vector3.new(1.15, 1.2, 0.5), at(0, 0.82, -0.76), belly)
	-- šupinky na bříšku
	for i, y in { 0.62, 0.84, 1.06 } do
		ball(
			m,
			"BellyPlate",
			Vector3.new(0.95 - i * 0.1, 0.07, 0.3),
			at(0, y, -0.96 + i * 0.02),
			Color3.fromRGB(240, 190, 90)
		)
	end
	-- čumák s nozdrami
	ball(m, "Snout", Vector3.new(1.0, 0.62, 0.7), at(0, 1.08, -0.92), belly)
	for _, side in { -1, 1 } do
		ball(m, "Nostril", Vector3.new(0.1, 0.07, 0.06), at(side * 0.17, 1.2, -1.26), bone)
	end
	ball(m, "Smile", Vector3.new(0.36, 0.06, 0.06), at(0, 0.94, -1.24), bone)
	eyes(m, 1.55, -0.8, 0.42, 0.38)
	for _, side in { -1, 1 } do
		-- rohy zahnuté dozadu (dva díly)
		ball(m, "Horn", Vector3.new(0.26, 0.62, 0.26), at(side * 0.45, 2.12, 0.18, 35, 0, -side * 12), horn)
		ball(m, "HornTip", Vector3.new(0.17, 0.5, 0.17), at(side * 0.5, 2.42, 0.48, 70, 0, -side * 12), horn)
		-- ploutvičky po stranách hlavy
		diamond(m, "Frill", 0.42, at(side * 0.95, 1.55, 0.15, 0, side * 70, 0), membrane, 0.08)
		-- netopýří křídla: kost + 3 blány do vějíře
		local shoulder = Vector3.new(side * 0.55, 1.75, 0.62)
		for _, f in { { 18, 1.45 }, { 42, 1.7 }, { 66, 1.5 } } do
			local angle, length = math.rad(f[1]), f[2]
			local center = shoulder + Vector3.new(side * math.cos(angle) * length / 2, math.sin(angle) * length / 2, 0)
			ball(
				m,
				"Wing",
				Vector3.new(length, 0.58, 0.08),
				CFrame.new(center) * CFrame.Angles(0, 0, side * angle),
				membrane
			)
		end
		local armAngle = math.rad(72)
		local armCenter = shoulder + Vector3.new(side * math.cos(armAngle) * 0.85, math.sin(armAngle) * 0.85, -0.02)
		ball(
			m,
			"WingBone",
			Vector3.new(1.75, 0.16, 0.16),
			CFrame.new(armCenter) * CFrame.Angles(0, 0, side * armAngle),
			bone
		)
		ball(
			m,
			"Claw",
			Vector3.new(0.16, 0.22, 0.16),
			CFrame.new(shoulder + Vector3.new(side * 0.55, 1.72, -0.02)),
			horn
		)
	end
	-- trny na zádech
	for i, z in { 0.3, 0.68, 1.02 } do
		part(m, "Spike", Vector3.new(0.34, 0.34, 0.12), at(0, 2.0 - i * 0.2, z, 0, 90, 45), membrane)
	end
	blush(m, 1.28, -0.92, 0.66)
	feet(m, belly, 0.45)
	local tail = {
		{ Vector3.new(0.8, 0.7, 0.9), Vector3.new(0, 0.7, 1.15) },
		{ Vector3.new(0.6, 0.5, 0.75), Vector3.new(0, 0.78, 1.75) },
		{ Vector3.new(0.42, 0.36, 0.55), Vector3.new(0, 0.98, 2.2) },
	}
	for _, t in tail do
		ball(m, "Tail", t[1], CFrame.new(t[2]), scale)
	end
	local flame = ball(
		m,
		"TailFlame",
		Vector3.new(0.55, 0.8, 0.55),
		at(0, 1.32, 2.45),
		Color3.fromRGB(255, 120, 30),
		{ Material = Enum.Material.Neon }
	)
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 60)
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = flame
	-- jiskřičky (mýtický mazlíček)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
	sparkle.Size = NumberSequence.new(0.25)
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.5, 1.2)
	sparkle.LightEmission = 1
	sparkle.Parent = m:FindFirstChild("Body")
end

function PetFactory.build(petId: string): Model
	local model = newModel(petId)
	local builder = PETS[petId] or PETS.SandBunny
	builder(model)
	model:SetAttribute("PetId", petId)
	model:SetAttribute("Flying", FLYING[petId] == true)
	return model
end

function PetFactory.isFlying(petId: string): boolean
	return FLYING[petId] == true
end

---------------------------------------------------------------------
-- Vajíčka
---------------------------------------------------------------------

local EGGS = {
	SandEgg = {
		Base = Color3.fromRGB(242, 208, 145),
		Spot = Color3.fromRGB(184, 122, 62),
		Band = Color3.fromRGB(214, 160, 92),
	},
	OasisEgg = {
		Base = Color3.fromRGB(72, 192, 204),
		Spot = Color3.fromRGB(120, 220, 120),
		Band = Color3.fromRGB(240, 250, 255),
	},
	PharaohEgg = {
		Base = GOLD,
		Spot = Color3.fromRGB(40, 90, 200),
		Band = Color3.fromRGB(40, 90, 200),
		Metal = true,
		Gem = true,
	},
}

function PetFactory.egg(eggId: string, scale: number?): Model
	local s = scale or 1
	local style = EGGS[eggId] or EGGS.SandEgg
	local model = newModel(eggId)
	local material = if style.Metal then Enum.Material.Metal else Enum.Material.SmoothPlastic
	local center = Vector3.new(0, 1.5 * s, 0)
	local radius = Vector3.new(1.2, 1.5, 1.2) * s
	ball(model, "Shell", radius * 2, CFrame.new(center), style.Base, { Material = material })
	ball(
		model,
		"Band",
		Vector3.new(2.46, 0.3, 2.46) * s,
		CFrame.new(center + Vector3.new(0, -0.1 * s, 0)),
		style.Band,
		{ Material = material }
	)
	-- skvrny po povrchu vajíčka
	local spots = { { 30, 50 }, { 150, 60 }, { 260, 40 }, { 80, -30 }, { 210, -35 }, { 330, -20 }, { 0, 75 } }
	for _, sp in spots do
		local yaw, pitch = math.rad(sp[1]), math.rad(sp[2])
		local dir = Vector3.new(math.cos(pitch) * math.sin(yaw), math.sin(pitch), math.cos(pitch) * math.cos(yaw))
		local surface = center + Vector3.new(dir.X * radius.X, dir.Y * radius.Y, dir.Z * radius.Z) * 0.97
		ball(
			model,
			"Spot",
			Vector3.new(0.55, 0.55, 0.16) * s,
			CFrame.lookAt(surface, surface + dir),
			style.Spot,
			{ Material = material }
		)
	end
	if style.Gem then
		local gem = part(
			model,
			"Gem",
			Vector3.new(0.45, 0.45, 0.2) * s,
			CFrame.lookAt(center + Vector3.new(0, 0.2, -1.2) * s, center + Vector3.new(0, 0.2, -3) * s)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color3.fromRGB(255, 60, 90),
			{ Material = Enum.Material.Neon }
		)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GOLD
		sparkles.Parent = gem
	end
	return model
end

return PetFactory
