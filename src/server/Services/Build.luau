--[[
	Build – pomocné funkce pro stavění mapy z Partů (používá WorldService a LobbyBuilder).
]]

local Players = game:GetService("Players")

local Build = {}

-- Výchozí animace Robloxu (veřejné, fungují v každé hře)
local IDLE_ANIMATION = "rbxassetid://507766666"
local WAVE_ANIMATION = "rbxassetid://507770239"

local DARK = Color3.fromRGB(60, 35, 15)

function Build.part(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

-- Svislý válec (Roblox válce mají osu X, proto otočení)
function Build.cylinder(props): Part
	local height = props.Height
	local diameter = props.Diameter
	local position = props.Position
	props.Height = nil
	props.Diameter = nil
	props.Position = nil
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return Build.part(props)
end

-- Koule / elipsoid (SpecialMesh Sphere se natáhne podle velikosti partu)
function Build.ellipsoid(props): Part
	local part = Build.part(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

function Build.wedge(props): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(wedge :: any)[key] = value
		end
	end
	wedge.Parent = props.Parent
	return wedge
end

function Build.model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.stroke(parent: Instance, thickness: number, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color or DARK
	stroke.Parent = parent
	return stroke
end

-- Nápis nad objektem (velikost ve studs)
function Build.billboard(
	part: BasePart,
	text: string,
	color: Color3,
	studsSize: Vector2,
	offset: number,
	font: Enum.Font?
)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromScale(studsSize.X, studsSize.Y)
	billboard.StudsOffset = Vector3.new(0, offset, 0)
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextColor3 = color
	label.Parent = billboard
	Build.stroke(label, 3)
	return billboard, label
end

-- Cedule s nápisem na obou stranách (SurfaceGui)
function Build.sign(part: BasePart, text: string, color: Color3, faces: { Enum.NormalId }?, canvas: Vector2?)
	for _, face in faces or { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.CanvasSize = canvas or Vector2.new(600, 180)
		surface.LightInfluence = 0
		surface.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.LuckiestGuy
		label.TextColor3 = color
		label.Parent = surface
		Build.stroke(label, 4)
	end
end

function Build.light(parent: Instance, color: Color3, range: number, brightness: number?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1
	light.Parent = parent
	return light
end

function Build.sparkles(parent: Instance, color: Color3, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = rate or 6
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(1.5, 3.5)
	emitter.Size = NumberSequence.new(0.5)
	emitter.LightEmission = 1
	emitter.Parent = parent
	return emitter
end

-- Palma
function Build.palm(parent: Instance, base: Vector3, lean: number, height: number?)
	local palm = Build.model("Palm", parent)
	local trunkColor = Color3.fromRGB(140, 98, 60)
	local position = base
	local direction = Vector3.new(lean, 1, lean * 0.4).Unit
	local segments = height or 6
	for i = 1, segments do
		local segment = 2.6
		local center = position + direction * segment / 2
		Build.part({
			Name = "Trunk",
			Size = Vector3.new(1.4 - i * 0.07, segment + 0.3, 1.4 - i * 0.07),
			CFrame = CFrame.lookAt(center, center + direction) * CFrame.Angles(math.rad(90), 0, 0),
			Material = Enum.Material.Wood,
			Color = trunkColor:Lerp(Color3.fromRGB(105, 70, 40), (i % 2) * 0.5),
			CanCollide = i <= 2,
			Parent = palm,
		})
		position += direction * segment
		direction = (direction + Vector3.new(lean * 0.12, 0, 0)).Unit
	end
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local leafDir = Vector3.new(math.cos(angle), -0.3, math.sin(angle)).Unit
		local center = position + leafDir * 3.2
		Build.part({
			Name = "Leaf",
			Size = Vector3.new(1.8, 0.2, 7),
			CFrame = CFrame.lookAt(center, center + leafDir),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(62, 150, 58):Lerp(Color3.fromRGB(120, 185, 70), (i % 3) / 3),
			CanCollide = false,
			Parent = palm,
		})
	end
	for i = 1, 3 do
		Build.ellipsoid({
			Name = "Coconut",
			Size = Vector3.new(0.9, 0.9, 0.9),
			Position = position + Vector3.new(math.cos(i * 2.1) * 0.7, -0.6, math.sin(i * 2.1) * 0.7),
			Color = Color3.fromRGB(110, 75, 40),
			CanCollide = false,
			Parent = palm,
		})
	end
	return palm
end

-- Kostičková postavička (NPC obchodník / socha)
function Build.npc(parent: Instance, cframe: CFrame, colors, name: string?): Model
	local npc = Build.model(name or "NPC", parent)
	local c = colors or {}
	local skin = c.Skin or Color3.fromRGB(247, 197, 142)
	local shirt = c.Shirt or Color3.fromRGB(230, 210, 170)
	local pants = c.Pants or Color3.fromRGB(110, 74, 44)
	local hat = c.Hat or Color3.fromRGB(255, 122, 26)
	local material = c.Material or Enum.Material.SmoothPlastic

	local function piece(pieceName, size, offset, color, shape)
		local props = {
			Name = pieceName,
			Size = size,
			CFrame = cframe * offset,
			Color = color,
			Material = material,
			CanCollide = false,
			Parent = npc,
		}
		if shape == "ball" then
			return Build.ellipsoid(props)
		end
		return Build.part(props)
	end

	piece("LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), pants)
	piece("RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), pants)
	local torso = piece("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt)
	torso.CanCollide = true
	piece("Belt", Vector3.new(2.05, 0.3, 1.05), CFrame.new(0, 2.15, 0), Color3.fromRGB(80, 50, 22))
	piece("LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), shirt)
	piece("RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, -0.3) * CFrame.Angles(math.rad(25), 0, 0), shirt)
	piece("LeftHand", Vector3.new(0.9, 0.5, 0.9), CFrame.new(-1.5, 1.85, 0), skin)
	local head = piece("Head", Vector3.new(1.3, 1.25, 1.25), CFrame.new(0, 4.65, 0), skin)
	-- obličej
	for _, x in { -0.28, 0.28 } do
		piece("Eye", Vector3.new(0.2, 0.3, 0.05), CFrame.new(x, 4.75, -0.64), Color3.fromRGB(30, 20, 15))
	end
	piece("Smile", Vector3.new(0.5, 0.08, 0.05), CFrame.new(0, 4.4, -0.64), Color3.fromRGB(60, 25, 15))
	-- klobouk
	Build.cylinder({
		Name = "HatBrim",
		Height = 0.15,
		Diameter = 2.2,
		Position = (cframe * CFrame.new(0, 5.3, 0)).Position,
		Color = hat,
		Material = material,
		CanCollide = false,
		Parent = npc,
	})
	piece("HatTop", Vector3.new(1.4, 0.7, 1.4), CFrame.new(0, 5.65, 0), hat, "ball")
	if c.Beard then
		piece("Beard", Vector3.new(1.1, 0.6, 0.3), CFrame.new(0, 4.15, -0.62), c.Beard)
	end
	npc.PrimaryPart = torso
	if name then
		Build.billboard(head, name, Color3.fromRGB(255, 236, 170), Vector2.new(8, 1.6), 2.2, Enum.Font.FredokaOne)
	end
	return npc
end

-- Skutečný Roblox avatar jako NPC (R15, výchozí obličej, barvy oblečení, klobouk,
-- animace idle + občas zamává). Když to nejde (např. v testech), použije Build.npc.
function Build.avatarNpc(parent: Instance, cframe: CFrame, colors, name: string?, statue: boolean?): Model
	local c = colors or {}
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = c.Skin or Color3.fromRGB(247, 197, 142)
		description.LeftArmColor = c.Shirt or Color3.fromRGB(230, 210, 170)
		description.RightArmColor = c.Shirt or Color3.fromRGB(230, 210, 170)
		description.TorsoColor = c.Shirt or Color3.fromRGB(230, 210, 170)
		description.LeftLegColor = c.Pants or Color3.fromRGB(110, 74, 44)
		description.RightLegColor = c.Pants or Color3.fromRGB(110, 74, 44)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return Build.npc(parent, cframe, colors, name)
	end
	model.Name = name or "NPC"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = model:FindFirstChild("Head") :: BasePart?
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false -- hráči NPC projdou, nepřekáží
			if statue then
				part.Anchored = true
				part.Material = c.Material or Enum.Material.Metal
			end
		elseif statue and part:IsA("Decal") then
			part.Transparency = 0.6 -- obličej sochy jen naznačený
		end
	end
	if root then
		root.Anchored = true
	end
	local lift = 3
	if humanoid and root then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		lift = humanoid.HipHeight + root.Size.Y / 2
	end
	model:PivotTo(cframe * CFrame.new(0, lift, 0))
	-- klobouk z partů přivařený k hlavě
	if head then
		local hat = c.Hat or Color3.fromRGB(255, 122, 26)
		local brim = Instance.new("Part")
		brim.Name = "HatBrim"
		brim.Shape = Enum.PartType.Cylinder
		brim.Size = Vector3.new(0.14, 2.1, 2.1)
		brim.Color = hat
		brim.CanCollide = false
		brim.Massless = true
		brim.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		brim.Parent = model
		local top = Instance.new("Part")
		top.Name = "HatTop"
		top.Size = Vector3.new(1.3, 0.75, 1.3)
		top.Color = hat
		top.CanCollide = false
		top.Massless = true
		top.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.38, 0)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = top
		top.Parent = model
		local band = Instance.new("Part")
		band.Name = "HatBand"
		band.Shape = Enum.PartType.Cylinder
		band.Size = Vector3.new(0.2, 1.34, 1.34)
		band.Color = Color3.fromRGB(80, 50, 22)
		band.CanCollide = false
		band.Massless = true
		band.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.18, 0) * CFrame.Angles(0, 0, math.rad(90))
		band.Parent = model
		for _, piece in { brim, top, band } do
			if statue then
				piece.Anchored = true
				piece.Material = c.Material or Enum.Material.Metal
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = piece
			weld.Parent = piece
		end
		if name then
			Build.billboard(head, name, Color3.fromRGB(255, 236, 170), Vector2.new(8, 1.6), 2.6, Enum.Font.FredokaOne)
		end
	end
	model.Parent = parent
	-- animace (idle stále, zamávání občas) – socha se nehýbe
	if humanoid and not statue then
		task.spawn(function()
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local idleAnim = Instance.new("Animation")
			idleAnim.AnimationId = IDLE_ANIMATION
			local waveAnim = Instance.new("Animation")
			waveAnim.AnimationId = WAVE_ANIMATION
			local okIdle, idle = pcall(function()
				return animator:LoadAnimation(idleAnim)
			end)
			if okIdle and idle then
				idle.Looped = true
				idle:Play()
			end
			local okWave, wave = pcall(function()
				return animator:LoadAnimation(waveAnim)
			end)
			while okWave and wave and model.Parent do
				task.wait(math.random(7, 14))
				wave:Play()
			end
		end)
	end
	return model
end

-- Bedna / sud / dekorace
function Build.crate(parent: Instance, position: Vector3, size: number?, rotation: number?)
	local s = size or 3
	local crate = Build.part({
		Name = "Crate",
		Size = Vector3.new(s, s, s),
		CFrame = CFrame.new(position + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, rotation or 0, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(176, 124, 70),
		Parent = parent,
	})
	return crate
end

function Build.barrel(parent: Instance, position: Vector3)
	local barrel = Build.cylinder({
		Name = "Barrel",
		Height = 3.2,
		Diameter = 2.4,
		Position = position + Vector3.new(0, 1.6, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(130, 85, 45),
		Parent = parent,
	})
	for _, y in { 0.7, 2.5 } do
		Build.cylinder({
			Name = "Hoop",
			Height = 0.25,
			Diameter = 2.5,
			Position = position + Vector3.new(0, y, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 70, 75),
			CanCollide = false,
			Parent = parent,
		})
	end
	return barrel
end

function Build.pot(parent: Instance, position: Vector3, color: Color3?)
	Build.ellipsoid({
		Name = "Pot",
		Size = Vector3.new(2.2, 2.6, 2.2),
		Position = position + Vector3.new(0, 1.3, 0),
		Material = Enum.Material.Slate,
		Color = color or Color3.fromRGB(196, 108, 62),
		Parent = parent,
	})
	Build.cylinder({
		Name = "PotNeck",
		Height = 0.6,
		Diameter = 1.2,
		Position = position + Vector3.new(0, 2.75, 0),
		Material = Enum.Material.Slate,
		Color = (color or Color3.fromRGB(196, 108, 62)):Lerp(Color3.new(0, 0, 0), 0.15),
		Parent = parent,
	})
end

function Build.lantern(parent: Instance, position: Vector3, color: Color3?)
	Build.cylinder({
		Name = "LanternPost",
		Height = 7,
		Diameter = 0.5,
		Position = position + Vector3.new(0, 3.5, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 45, 35),
		Parent = parent,
	})
	local lamp = Build.part({
		Name = "Lamp",
		Size = Vector3.new(1.1, 1.4, 1.1),
		Position = position + Vector3.new(0, 7.4, 0),
		Material = Enum.Material.Neon,
		Color = color or Color3.fromRGB(255, 176, 80),
		CanCollide = false,
		Parent = parent,
	})
	Build.part({
		Name = "LampCap",
		Size = Vector3.new(1.5, 0.3, 1.5),
		Position = position + Vector3.new(0, 8.25, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 45, 35),
		CanCollide = false,
		Parent = parent,
	})
	Build.light(lamp, color or Color3.fromRGB(255, 176, 80), 16, 1.3)
	return lamp
end

function Build.banner(parent: Instance, position: Vector3, color: Color3, facing: Vector3)
	Build.cylinder({
		Name = "BannerPole",
		Height = 12,
		Diameter = 0.45,
		Position = position + Vector3.new(0, 6, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(110, 72, 40),
		Parent = parent,
	})
	local center = position + Vector3.new(0, 9, 0) + facing.Unit * 0.3
	Build.part({
		Name = "Banner",
		Size = Vector3.new(2.6, 5, 0.15),
		CFrame = CFrame.lookAt(center, center + facing),
		Material = Enum.Material.Fabric,
		Color = color,
		CanCollide = false,
		Parent = parent,
	})
	Build.part({
		Name = "BannerStripe",
		Size = Vector3.new(2.7, 0.5, 0.2),
		CFrame = CFrame.lookAt(center + Vector3.new(0, -1.6, 0), center + Vector3.new(0, -1.6, 0) + facing),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(255, 205, 60),
		CanCollide = false,
		Parent = parent,
	})
end

-- Koberec se vzorem
function Build.carpet(parent: Instance, center: Vector3, size: Vector2, color: Color3, rotation: number?)
	local base = CFrame.new(center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rotation or 0, 0)
	Build.part({
		Name = "Carpet",
		Size = Vector3.new(size.X, 0.15, size.Y),
		CFrame = base,
		Material = Enum.Material.Fabric,
		Color = color,
		CanCollide = false,
		Parent = parent,
	})
	Build.part({
		Name = "CarpetBorder",
		Size = Vector3.new(size.X - 1.2, 0.17, size.Y - 1.2),
		CFrame = base,
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(255, 205, 90),
		CanCollide = false,
		Parent = parent,
	})
	Build.part({
		Name = "CarpetInner",
		Size = Vector3.new(size.X - 2, 0.19, size.Y - 2),
		CFrame = base,
		Material = Enum.Material.Fabric,
		Color = color:Lerp(Color3.new(0, 0, 0), 0.15),
		CanCollide = false,
		Parent = parent,
	})
end

return Build
